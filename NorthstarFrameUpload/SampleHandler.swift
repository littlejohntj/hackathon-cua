import CoreImage
import CoreMedia
import ImageIO
import Network
import OSLog
import ReplayKit

final class SampleHandler: RPBroadcastSampleHandler, @unchecked Sendable {
    private let queue = DispatchQueue(label: "NorthstarFrameUpload")
    private let logger = Logger(subsystem: "NorthstarTalk.FrameUpload", category: "replaykit")
    private let imageContext = CIContext()
    private let port: NWEndpoint.Port = 17771
    private var connection: NWConnection?
    private var connectionReady = false
    private var active = false
    private var stopping = false
    private var connectFailures = 0
    private var lastFrameSentAt = Date.distantPast

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        queue.async {
            self.active = true
            self.stopping = false
            self.connectFailures = 0
            self.lastFrameSentAt = .distantPast
            self.logLocal("broadcastStarted setupKeys=\(setupInfo?.keys.sorted().joined(separator: ",") ?? "none")")
            self.connectLocked()
        }
    }

    override func broadcastPaused() {
        sendText(.log, "broadcastPaused")
    }

    override func broadcastResumed() {
        sendText(.log, "broadcastResumed")
    }

    override func broadcastFinished() {
        queue.async {
            self.sendTextLocked(.broadcastStopped, "broadcastFinished")
            self.teardownLocked()
            self.logLocal("broadcastFinished")
        }
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        processVideo(sampleBuffer)
    }

    private func processVideo(_ sampleBuffer: CMSampleBuffer) {
        let now = Date()
        guard now.timeIntervalSince(lastFrameSentAt) >= 1.0 else { return }
        lastFrameSentAt = now

        guard
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
            let jpeg = jpegData(from: imageBuffer)
        else {
            sendText(.error, "jpeg encode failed")
            return
        }

        sendPacket(FrameStreamProtocol.packet(.jpegFrame, payload: jpeg), description: "frame bytes=\(jpeg.count)")
    }

    private func jpegData(from imageBuffer: CVImageBuffer) -> Data? {
        let image = CIImage(cvPixelBuffer: imageBuffer)
        let extent = image.extent
        let longestEdge = max(extent.width, extent.height)
        let scale = min(1.0, 768.0 / longestEdge)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return imageContext.jpegRepresentation(
            of: scaled,
            colorSpace: colorSpace,
            options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.45]
        )
    }

    private func connectLocked() {
        guard active, !stopping else { return }
        connection?.cancel()
        connectionReady = false

        let connection = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            self.queue.async {
                guard self.connection === connection else { return }
                self.handleConnectionStateLocked(state)
            }
        }
        connection.start(queue: queue)
        self.connection = connection
        logLocal("connecting to app port=\(port.rawValue)")
    }

    private func handleConnectionStateLocked(_ state: NWConnection.State) {
        switch state {
        case .ready:
            connectionReady = true
            connectFailures = 0
            sendTextLocked(.broadcastStarted, "ReplayKit broadcast connected")
            sendTextLocked(.log, "connection ready")
            receiveControlLocked()
        case .failed(let error):
            connectionReady = false
            logLocal("connection failed error=\(error.localizedDescription)")
            reconnectOrFinishLocked("connection failed: \(error.localizedDescription)")
        case .waiting(let error):
            connectionReady = false
            logLocal("connection waiting error=\(error.localizedDescription)")
        case .cancelled:
            connectionReady = false
        default:
            break
        }
    }

    private func reconnectOrFinishLocked(_ reason: String) {
        guard active, !stopping else { return }
        connectFailures += 1
        if connectFailures >= 8 {
            finishLocked("Northstar app is not listening (\(reason))")
            return
        }
        queue.asyncAfter(deadline: .now() + 0.5) {
            self.connectLocked()
        }
    }

    private func receiveControlLocked() {
        guard let connection else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 32) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }
            self.queue.async {
                guard self.connection === connection, self.active, !self.stopping else { return }
                if let data, data.contains(FrameStreamProtocol.Control.stopBroadcast.rawValue) {
                    self.finishLocked("Northstar guide stopped")
                    return
                }
                if let error {
                    self.connectionReady = false
                    self.logLocal("control receive failed error=\(error.localizedDescription)")
                    self.reconnectOrFinishLocked("control receive failed: \(error.localizedDescription)")
                    return
                }
                if isComplete {
                    self.connectionReady = false
                    self.reconnectOrFinishLocked("control stream ended")
                    return
                }
                self.receiveControlLocked()
            }
        }
    }

    private func sendText(_ type: FrameStreamProtocol.MessageType, _ text: String) {
        sendPacket(FrameStreamProtocol.packet(type, string: text), description: text)
    }

    private func sendTextLocked(_ type: FrameStreamProtocol.MessageType, _ text: String) {
        sendPacketLocked(FrameStreamProtocol.packet(type, string: text), description: text)
    }

    private func sendPacket(_ packet: Data, description: String) {
        queue.async {
            self.sendPacketLocked(packet, description: description)
        }
    }

    private func sendPacketLocked(_ packet: Data, description: String) {
        guard active, !stopping else { return }
        guard connectionReady, let connection else {
            logLocal("drop packet until connected description=\(description)")
            return
        }

        connection.send(content: packet, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            self.queue.async {
                if let error {
                    self.connectionReady = false
                    self.logLocal("send failed description=\(description) error=\(error.localizedDescription)")
                    self.reconnectOrFinishLocked("send failed: \(error.localizedDescription)")
                }
            }
        })
    }

    private func finishLocked(_ message: String) {
        guard active, !stopping else { return }
        sendTextLocked(.broadcastStopped, message)
        stopping = true
        logLocal("finishBroadcastWithError message=\(message)")
        let error = NSError(
            domain: "NorthstarFrameUpload",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        finishBroadcastWithError(error)
        teardownLocked()
    }

    private func teardownLocked() {
        active = false
        connectionReady = false
        connection?.cancel()
        connection = nil
    }

    private func logLocal(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }
}

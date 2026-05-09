import Foundation
import UIKit

@MainActor
final class ScreenGuideController: ObservableObject {
    @Published var prompt = "How do I disable Slack notifications?"
    @Published private(set) var status = "Idle"
    @Published private(set) var liveActivityStatus = "Live Activity ready"
    @Published private(set) var isRunning = false
    @Published private(set) var replayKitLive = false
    @Published private(set) var isAnalyzing = false
    @Published private(set) var latestImage: UIImage?
    @Published private(set) var instruction = ""
    @Published private(set) var framesReceived = 0
    @Published private(set) var framesAccepted = 0
    @Published private(set) var framesSkipped = 0
    @Published private(set) var debugLines: [String] = []

    private let server = FrameStreamServer(port: AppConfiguration.frameServerPort)
    private let activity = GuideActivityController()
    private let audioKeeper = BackgroundAudioKeeper()
    private weak var engine: NorthstarEngine?
    private var lastSignature: FrameSignature?
    private var pendingFrame: Data?
    private var startTimeoutTask: Task<Void, Never>?
    private var stoppingFromApp = false
    private let similarityCutoff = 0.90
    private let debugLimit = 80

    init() {
        server.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }
    }

    deinit {
        startTimeoutTask?.cancel()
        server.stop(sendBroadcastStop: true)
    }

    @discardableResult
    func start(engine: NorthstarEngine) -> Bool {
        let task = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !task.isEmpty else {
            status = "Enter a task first"
            log("start blocked: empty task", error: true)
            return false
        }
        guard engine.isReady else {
            status = "Load the model first"
            log("start blocked: model not ready", error: true)
            return false
        }
        guard !isRunning else {
            log("start ignored: already running")
            return false
        }

        self.engine = engine
        framesReceived = 0
        framesAccepted = 0
        framesSkipped = 0
        replayKitLive = false
        stoppingFromApp = false
        lastSignature = nil
        pendingFrame = nil
        latestImage = nil
        instruction = "Waiting for ReplayKit…"
        debugLines.removeAll(keepingCapacity: true)

        do {
            try server.start()
        } catch {
            let message = "Frame server failed: \(error.localizedDescription)"
            status = message
            log(message, error: true)
            return false
        }

        activity.start(task: task)
        liveActivityStatus = activity.status
        audioKeeper.start()
        isRunning = true
        status = "Opening ReplayKit picker…"
        log("guide start taskChars=\(task.count) extension=\(AppConfiguration.frameUploadExtensionBundleID)")
        startReplayKitTimeout()
        return true
    }

    func stop() {
        guard isRunning else { return }
        stoppingFromApp = true
        finish(
            status: "Stopped",
            finalInstruction: instruction.isEmpty ? "Stopped" : instruction,
            stopReplayKit: true,
            error: false
        )
    }

    private func handle(_ event: FrameStreamEvent) {
        switch event {
        case .serverReady:
            log("frame server ready")
            if isRunning, !replayKitLive {
                status = "Confirm the Northstar broadcast in the ReplayKit picker."
            }

        case .serverStopped:
            log("frame server stopped")

        case .serverFailed(let message):
            log("frame server failed: \(message)", error: true)
            if isRunning {
                finish(
                    status: "Frame server failed",
                    finalInstruction: message,
                    stopReplayKit: true,
                    error: true
                )
            }

        case .broadcastConnected:
            log("ReplayKit socket connected")
            if isRunning {
                status = "ReplayKit connected. Waiting for first frame…"
            }

        case .broadcastDisconnected(let reason):
            log("ReplayKit socket disconnected: \(reason)")
            if isRunning, replayKitLive, !stoppingFromApp {
                finish(
                    status: "ReplayKit stopped",
                    finalInstruction: "ReplayKit stopped: \(reason)",
                    stopReplayKit: false,
                    error: true
                )
            }

        case .broadcastStarted(let message):
            replayKitLive = true
            startTimeoutTask?.cancel()
            status = "ReplayKit live. Watching for changed frames…"
            instruction = framesAccepted == 0 ? "Waiting for a changed screen…" : instruction
            log("ReplayKit started: \(message)")
            Task {
                await activity.update(
                    instruction: instruction,
                    status: "Watching",
                    framesSeen: framesAccepted
                )
                liveActivityStatus = activity.status
            }

        case .broadcastStopped(let message):
            log("ReplayKit stopped event: \(message)")
            if isRunning, !stoppingFromApp {
                finish(
                    status: "ReplayKit stopped",
                    finalInstruction: message.isEmpty ? "ReplayKit stopped." : "ReplayKit stopped: \(message)",
                    stopReplayKit: false,
                    error: true
                )
            }

        case .extensionLog(let message):
            log("ext: \(message)")

        case .extensionError(let message):
            log("ext error: \(message)", error: true)
            if isRunning {
                status = "ReplayKit error: \(message)"
            }

        case .frame(let data):
            receiveFrame(data)
        }
    }

    private func startReplayKitTimeout() {
        startTimeoutTask?.cancel()
        startTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            await MainActor.run {
                guard let self, self.isRunning, !self.replayKitLive else { return }
                self.finish(
                    status: "ReplayKit did not start",
                    finalInstruction: "ReplayKit did not start. Tap Start guide again and choose Northstar in the broadcast picker.",
                    stopReplayKit: true,
                    error: true
                )
            }
        }
    }

    private func finish(status: String, finalInstruction: String, stopReplayKit: Bool, error: Bool) {
        let accepted = framesAccepted
        let received = framesReceived
        let skipped = framesSkipped
        isRunning = false
        replayKitLive = false
        isAnalyzing = false
        pendingFrame = nil
        startTimeoutTask?.cancel()
        self.status = status
        instruction = finalInstruction

        if stopReplayKit {
            server.stop(sendBroadcastStop: true)
        } else {
            server.stop()
        }
        audioKeeper.stop()
        activity.end(finalInstruction: finalInstruction, framesSeen: accepted)
        liveActivityStatus = activity.status
        log("guide finish status=\(status) error=\(error) stopReplayKit=\(stopReplayKit) received=\(received) accepted=\(accepted) skipped=\(skipped)", error: error)
    }

    private func receiveFrame(_ data: Data) {
        framesReceived += 1
        guard let image = UIImage(data: data) else {
            log("frame decode failed bytes=\(data.count)", error: true)
            return
        }
        latestImage = image

        guard isRunning else { return }
        if !replayKitLive {
            log("frame received before broadcastStarted bytes=\(data.count)")
            replayKitLive = true
            startTimeoutTask?.cancel()
        }
        guard let signature = FrameSignature(image) else {
            log("frame signature failed", error: true)
            return
        }

        let pixels = "\(Int(image.size.width * image.scale))x\(Int(image.size.height * image.scale))"
        if let lastSignature {
            let similarity = signature.similarity(to: lastSignature)
            if similarity >= similarityCutoff {
                framesSkipped += 1
                status = "Skipped similar frame (\(Int(similarity * 100))%)"
                log("frame skipped similarity=\(format(similarity)) bytes=\(data.count) pixels=\(pixels)")
                return
            }
            log("frame accepted similarity=\(format(similarity)) bytes=\(data.count) pixels=\(pixels)")
        } else {
            log("frame accepted initial bytes=\(data.count) pixels=\(pixels)")
        }

        lastSignature = signature
        framesAccepted += 1
        scheduleAnalysis(data)
    }

    private func scheduleAnalysis(_ data: Data) {
        guard !isAnalyzing else {
            pendingFrame = data
            status = "Queued latest changed frame"
            log("analysis busy; queued latest frame bytes=\(data.count)")
            return
        }

        Task {
            await analyze(data)
        }
    }

    private func analyze(_ data: Data) async {
        guard isRunning, let engine else { return }
        isAnalyzing = true
        status = "Analyzing changed frame…"
        log("analysis begin frameBytes=\(data.count) accepted=\(framesAccepted)")
        await activity.update(
            instruction: instruction,
            status: "Thinking",
            framesSeen: framesAccepted
        )
        liveActivityStatus = activity.status

        do {
            let result = try await engine.instruction(for: prompt, imageData: data)
            guard isRunning else { return }
            instruction = result
            status = "Instruction updated"
            log("analysis result chars=\(result.count) text=\(preview(result))")
            await activity.update(
                instruction: result,
                status: "Updated",
                framesSeen: framesAccepted
            )
            liveActivityStatus = activity.status
            engine.speak(result)
        } catch GuideError.alreadyGenerating {
            pendingFrame = data
            status = "Queued latest changed frame"
            log("analysis collided with engine generation; queued frame")
        } catch {
            let message = error.localizedDescription
            instruction = message
            status = message
            await activity.update(
                instruction: message,
                status: "Error",
                framesSeen: framesAccepted
            )
            liveActivityStatus = activity.status
            log("analysis failed error=\(message)", error: true)
        }

        isAnalyzing = false
        guard isRunning, let next = pendingFrame else { return }
        pendingFrame = nil
        await analyze(next)
    }

    private func log(_ message: String, error: Bool = false) {
        let line = "\(Self.shortTimestamp()) \(message)"
        debugLines.append(line)
        if debugLines.count > debugLimit {
            debugLines.removeFirst(debugLines.count - debugLimit)
        }
        if error {
            AppLog.error("guide \(message)")
        } else {
            AppLog.info("guide \(message)")
        }
    }

    private func preview(_ text: String) -> String {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
        if singleLine.count <= 180 { return singleLine }
        return String(singleLine.prefix(180)) + "…"
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private static func shortTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

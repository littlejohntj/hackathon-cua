import Foundation
import Network

enum FrameStreamEvent: Sendable {
    case serverReady
    case serverStopped
    case serverFailed(String)
    case broadcastConnected
    case broadcastDisconnected(String)
    case broadcastStarted(String)
    case broadcastStopped(String)
    case extensionLog(String)
    case extensionError(String)
    case frame(Data)
}

final class FrameStreamServer: @unchecked Sendable {
    private let port: NWEndpoint.Port
    private let queue = DispatchQueue(label: "NorthstarFrameServer")
    private let queueKey = DispatchSpecificKey<Void>()
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: FrameConnection] = [:]

    var onEvent: (@Sendable (FrameStreamEvent) -> Void)?

    init(port: UInt16) {
        self.port = NWEndpoint.Port(rawValue: port)!
        queue.setSpecific(key: queueKey, value: ())
    }

    func start() throws {
        stopImmediately()

        let listener = try NWListener(using: .tcp, on: port)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            self?.handleListenerState(state)
        }

        self.listener = listener
        listener.start(queue: queue)
        emit(.extensionLog("frame server starting port=\(port.rawValue)"))
    }

    func requestBroadcastStop() {
        queue.async {
            self.emit(.extensionLog("sending ReplayKit stop to \(self.connections.count) connection(s)"))
            for connection in self.connections.values {
                connection.sendStopBroadcast()
            }
        }
    }

    func stop(sendBroadcastStop: Bool = false) {
        if sendBroadcastStop {
            requestBroadcastStop()
            queue.asyncAfter(deadline: .now() + .milliseconds(700)) {
                self.stopLocked()
            }
        } else {
            stopImmediately()
        }
    }

    private func stopImmediately() {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            stopLocked()
        } else {
            queue.sync {
                stopLocked()
            }
        }
    }

    private func stopLocked() {
        listener?.cancel()
        listener = nil
        for connection in connections.values {
            connection.cancel()
        }
        connections.removeAll()
    }

    private func accept(_ nwConnection: NWConnection) {
        let id = ObjectIdentifier(nwConnection)
        let connection = FrameConnection(
            id: id,
            connection: nwConnection,
            onEvent: { [weak self] event in
                self?.emit(event)
            },
            onClose: { [weak self] id in
                self?.queue.async {
                    self?.connections.removeValue(forKey: id)
                }
            }
        )
        connections[id] = connection
        connection.start(queue: queue)
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            emit(.serverReady)
        case .failed(let error):
            emit(.serverFailed(error.localizedDescription))
            stop()
        case .cancelled:
            emit(.serverStopped)
        default:
            break
        }
    }

    private func emit(_ event: FrameStreamEvent) {
        onEvent?(event)
    }
}

private final class FrameConnection: @unchecked Sendable {
    private let id: ObjectIdentifier
    private let connection: NWConnection
    private let onEvent: @Sendable (FrameStreamEvent) -> Void
    private let onClose: @Sendable (ObjectIdentifier) -> Void
    private var buffer = Data()
    private var didClose = false

    init(
        id: ObjectIdentifier,
        connection: NWConnection,
        onEvent: @escaping @Sendable (FrameStreamEvent) -> Void,
        onClose: @escaping @Sendable (ObjectIdentifier) -> Void
    ) {
        self.id = id
        self.connection = connection
        self.onEvent = onEvent
        self.onClose = onClose
    }

    func start(queue: DispatchQueue) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.onEvent(.broadcastConnected)
            case .failed(let error):
                self?.close("connection failed: \(error.localizedDescription)")
            case .cancelled:
                self?.close("connection cancelled")
            default:
                break
            }
        }
        connection.start(queue: queue)
        receive()
    }

    func sendStopBroadcast() {
        connection.send(
            content: FrameStreamProtocol.stopBroadcastCommand,
            completion: .contentProcessed { [weak self] error in
                if let error {
                    self?.onEvent(.extensionError("stop command send failed: \(error.localizedDescription)"))
                }
            }
        )
    }

    func cancel() {
        connection.cancel()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.buffer.append(data)
                self.drainMessages()
            }
            if let error {
                self.close("receive failed: \(error.localizedDescription)")
                return
            }
            if isComplete {
                self.close("stream ended")
                return
            }
            self.receive()
        }
    }

    private func drainMessages() {
        while buffer.count >= FrameStreamProtocol.headerSize {
            let header = Array(buffer.prefix(FrameStreamProtocol.headerSize))
            guard let type = FrameStreamProtocol.MessageType(rawValue: header[0]) else {
                onEvent(.extensionError("invalid message type=\(header[0])"))
                buffer.removeAll(keepingCapacity: true)
                cancel()
                return
            }

            let length = (Int(header[1]) << 24)
                | (Int(header[2]) << 16)
                | (Int(header[3]) << 8)
                | Int(header[4])
            guard length >= 0 && length <= FrameStreamProtocol.maxPayloadSize else {
                onEvent(.extensionError("invalid payload length=\(length) type=\(type)"))
                buffer.removeAll(keepingCapacity: true)
                cancel()
                return
            }
            guard buffer.count >= FrameStreamProtocol.headerSize + length else { return }

            let payloadStart = FrameStreamProtocol.headerSize
            let payloadEnd = payloadStart + length
            let payload = buffer.subdata(in: payloadStart ..< payloadEnd)
            buffer.removeSubrange(0 ..< payloadEnd)
            emit(type, payload: payload)
        }
    }

    private func emit(_ type: FrameStreamProtocol.MessageType, payload: Data) {
        switch type {
        case .jpegFrame:
            onEvent(.frame(payload))
        case .broadcastStarted:
            onEvent(.broadcastStarted(payload.text))
        case .broadcastStopped:
            onEvent(.broadcastStopped(payload.text))
        case .log:
            onEvent(.extensionLog(payload.text))
        case .error:
            onEvent(.extensionError(payload.text))
        }
    }

    private func close(_ reason: String) {
        guard !didClose else { return }
        didClose = true
        onEvent(.broadcastDisconnected(reason))
        onClose(id)
    }
}

private extension Data {
    var text: String {
        String(decoding: self, as: UTF8.self)
    }
}

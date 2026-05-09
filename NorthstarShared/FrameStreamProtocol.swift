import Foundation

enum FrameStreamProtocol {
    enum MessageType: UInt8 {
        case jpegFrame = 1
        case broadcastStarted = 2
        case broadcastStopped = 3
        case log = 4
        case error = 5
    }

    enum Control: UInt8 {
        case stopBroadcast = 83
    }

    static let headerSize = 5
    static let maxPayloadSize = 16 * 1024 * 1024

    static var stopBroadcastCommand: Data {
        Data([Control.stopBroadcast.rawValue])
    }

    static func packet(_ type: MessageType, payload: Data = Data()) -> Data {
        var packet = Data([type.rawValue])
        var length = UInt32(payload.count).bigEndian
        packet.append(Data(bytes: &length, count: MemoryLayout<UInt32>.size))
        packet.append(payload)
        return packet
    }

    static func packet(_ type: MessageType, string: String) -> Data {
        packet(type, payload: Data(string.utf8))
    }
}

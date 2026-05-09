import Darwin
import Foundation
import OSLog

private final class AppLogSink: @unchecked Sendable {
    private let lock = NSLock()
    private let logger = Logger(subsystem: "NorthstarTalk", category: "debug")
    private var bootstrapped = false

    var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("northstar-debug.log")
    }

    func bootstrap() {
        lock.lock()
        defer { lock.unlock() }
        guard !bootstrapped else { return }
        bootstrapped = true

        let url = fileURL
        let fileManager = FileManager.default
        try? fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? NSNumber,
           size.intValue > 1_000_000 {
            let old = url.deletingPathExtension().appendingPathExtension("old.log")
            try? fileManager.removeItem(at: old)
            try? fileManager.moveItem(at: url, to: old)
        }

        appendLocked("\n--- launch \(Self.timestamp()) pid=\(getpid()) \(Self.memorySummary()) ---")
    }

    func write(_ level: String, _ message: String) {
        bootstrap()
        let line = "\(Self.timestamp()) [\(level)] \(Self.threadName()) \(Self.memorySummary()) \(message)"
        print(line)
        switch level {
        case "ERROR":
            logger.error("\(line, privacy: .public)")
        default:
            logger.info("\(line, privacy: .public)")
        }

        lock.lock()
        defer { lock.unlock() }
        appendLocked(line)
    }

    private func appendLocked(_ line: String) {
        let data = Data((line + "\n").utf8)
        let url = fileURL
        if FileManager.default.fileExists(atPath: url.path) {
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func threadName() -> String {
        Thread.isMainThread ? "main" : "bg"
    }

    private static func memorySummary() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.stride / MemoryLayout<natural_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return "mem=?"
        }
        let resident = Double(info.resident_size) / 1_048_576.0
        return String(format: "rss=%.1fMB", resident)
    }
}

enum AppLog {
    private static let sink = AppLogSink()

    static var fileURL: URL { sink.fileURL }

    static func bootstrap() {
        sink.bootstrap()
    }

    static func info(_ message: String) {
        sink.write("INFO", message)
    }

    static func error(_ message: String) {
        sink.write("ERROR", message)
    }
}

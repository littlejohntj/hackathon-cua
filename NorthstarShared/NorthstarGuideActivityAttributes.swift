import ActivityKit
import Foundation

public struct NorthstarGuideActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var instruction: String
        public var status: String
        public var framesSeen: Int
        public var updatedAt: Date
        public var isActive: Bool

        public init(
            instruction: String,
            status: String,
            framesSeen: Int,
            updatedAt: Date = Date(),
            isActive: Bool
        ) {
            self.instruction = instruction
            self.status = status
            self.framesSeen = framesSeen
            self.updatedAt = updatedAt
            self.isActive = isActive
        }
    }

    public var task: String
    public var startedAt: Date

    public init(task: String, startedAt: Date = Date()) {
        self.task = task
        self.startedAt = startedAt
    }
}

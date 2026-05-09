@preconcurrency import ActivityKit
import Foundation

@MainActor
final class GuideActivityController: ObservableObject {
    @Published private(set) var status = "Live Activity ready"
    @Published private(set) var isLive = false

    private var activity: Activity<NorthstarGuideActivityAttributes>?

    func start(task: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = "Live Activities disabled"
            AppLog.error("live activity start blocked: activities disabled")
            return
        }

        let trimmed = task.trimmingCharacters(in: .whitespacesAndNewlines)
        let attributes = NorthstarGuideActivityAttributes(task: trimmed.isEmpty ? "Screen guidance" : trimmed)
        let state = NorthstarGuideActivityAttributes.ContentState(
            instruction: "Waiting for a changed screen…",
            status: "Watching",
            framesSeen: 0,
            isActive: true
        )
        do {
            activity = try Activity<NorthstarGuideActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(
                    state: state,
                    staleDate: Date().addingTimeInterval(15 * 60),
                    relevanceScore: 1.0
                ),
                pushType: nil
            )
            isLive = true
            status = "Live Activity active"
            AppLog.info("live activity started id=\(activity?.id ?? "?")")
        } catch {
            status = error.localizedDescription
            AppLog.error("live activity start failed error=\(error.localizedDescription)")
        }
    }

    func update(instruction: String, status: String, framesSeen: Int, isActive: Bool = true) async {
        guard let activity else {
            AppLog.error("live activity update skipped: no active activity status=\(status) frames=\(framesSeen)")
            return
        }
        let state = NorthstarGuideActivityAttributes.ContentState(
            instruction: instruction,
            status: status,
            framesSeen: framesSeen,
            updatedAt: Date(),
            isActive: isActive
        )
        await activity.update(
            ActivityContent(
                state: state,
                staleDate: Date().addingTimeInterval(15 * 60),
                relevanceScore: isActive ? 1.0 : 0.1
            )
        )
        self.status = status
        self.isLive = isActive
        AppLog.info("live activity update status=\(status) active=\(isActive) frames=\(framesSeen) instructionChars=\(instruction.count)")
    }

    func end(finalInstruction: String, framesSeen: Int) {
        guard activity != nil else {
            status = "Live Activity stopped"
            isLive = false
            AppLog.error("live activity end skipped: no active activity")
            return
        }
        Task {
            await update(
                instruction: finalInstruction,
                status: "Stopped",
                framesSeen: framesSeen,
                isActive: false
            )
            await activity?.end(
                ActivityContent(
                    state: .init(
                        instruction: finalInstruction,
                        status: "Stopped",
                        framesSeen: framesSeen,
                        isActive: false
                    ),
                    staleDate: nil
                ),
                dismissalPolicy: .default
            )
            activity = nil
            isLive = false
            status = "Live Activity stopped"
            AppLog.info("live activity stopped")
        }
    }
}

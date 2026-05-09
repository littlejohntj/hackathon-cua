import ActivityKit
import Combine
import Foundation
import OneSignalLiveActivities

@MainActor
final class LiveActivityDemoModel: ObservableObject {
    @Published var activityID = "safari-stream-demo"
    @Published var apiKey = ""
    @Published var status = "Ready"
    @Published var viewerCount = 3
    @Published var elapsedSeconds = 0
    @Published var quality = "720p"
    @Published var isLive = false
    @Published var iconName = "emoji:👋"
    @Published var headline = "Screen share is live"
    @Published var detailLine1 = "Waiting for a web control update"
    @Published var detailLine2 = "Use safari-stream-demo as the Activity ID"
    @Published var lastOneSignalRequestID: String?

    private var activity: Activity<SafariStreamActivityAttributes>?

    var currentState: SafariStreamActivityAttributes.ContentState {
        .init(
            status: status,
            viewerCount: viewerCount,
            elapsedSeconds: elapsedSeconds,
            quality: quality,
            isLive: isLive,
            iconName: iconName,
            headline: headline,
            detailLine1: detailLine1,
            detailLine2: detailLine2
        )
    }

    func startButtonTapped() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = "Live Activities disabled"
            return
        }

        do {
            let oneSignalData = OneSignalLiveActivityAttributeData.create(activityId: activityID)
            let attributes = SafariStreamActivityAttributes(
                title: "Safari stream",
                hostName: "Hackathon Safari",
                startedAt: Date(),
                onesignal: oneSignalData
            )
            isLive = true
            status = "Live"
            let content = ActivityContent(
                state: currentState,
                staleDate: Date().addingTimeInterval(15 * 60),
                relevanceScore: 0.9
            )
            activity = try Activity<SafariStreamActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: .token
            )
        } catch {
            status = error.localizedDescription
        }
    }

    func localTickButtonTapped() {
        Task {
            elapsedSeconds += 15
            viewerCount += Int.random(in: -1...3)
            viewerCount = max(viewerCount, 0)
            status = isLive ? "Live" : "Paused"
            headline = isLive ? "Screen share is live" : "Screen share paused"
            detailLine1 = "\(viewerCount) viewers watching at \(quality)"
            detailLine2 = "Elapsed \(elapsedSeconds) seconds"
            await updateLocalActivity()
        }
    }

    func sendOneSignalUpdateButtonTapped() {
        Task {
            do {
                elapsedSeconds += 30
                viewerCount += Int.random(in: 1...5)
                status = "Live"
                isLive = true
                headline = "Screen share is live"
                detailLine1 = "\(viewerCount) viewers watching at \(quality)"
                detailLine2 = "Updated from the iOS app"
                let requestID = try await api.sendUpdate(activityID: activityID, state: currentState)
                lastOneSignalRequestID = requestID
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func endButtonTapped() {
        Task {
            do {
                isLive = false
                status = "Ended"
                iconName = "stop.circle.fill"
                headline = "Screen share ended"
                detailLine1 = "\(viewerCount) viewers joined"
                detailLine2 = "The Live Activity is closing"
                await updateLocalActivity()
                if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    lastOneSignalRequestID = try await api.end(activityID: activityID, state: currentState)
                }
                await activity?.end(
                    ActivityContent(state: currentState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
                activity = nil
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private var api: OneSignalLiveActivityAPI {
        OneSignalLiveActivityAPI(appID: AppConfiguration.oneSignalAppID, apiKey: apiKey)
    }

    private func updateLocalActivity() async {
        await activity?.update(
            ActivityContent(
                state: currentState,
                staleDate: Date().addingTimeInterval(15 * 60),
                relevanceScore: isLive ? 0.9 : 0.1
            )
        )
    }
}

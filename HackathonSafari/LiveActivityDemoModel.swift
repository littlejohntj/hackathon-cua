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
    @Published var lastOneSignalRequestID: String?

    private var activity: Activity<SafariStreamActivityAttributes>?

    var currentState: SafariStreamActivityAttributes.ContentState {
        .init(
            status: status,
            viewerCount: viewerCount,
            elapsedSeconds: elapsedSeconds,
            quality: quality,
            isLive: isLive
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

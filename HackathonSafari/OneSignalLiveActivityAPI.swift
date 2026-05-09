import Foundation

struct OneSignalLiveActivityAPI {
    var appID: String
    var apiKey: String

    func sendUpdate(
        activityID: String,
        state: SafariStreamActivityAttributes.ContentState
    ) async throws -> String {
        let payload = LiveActivityPayload(
            event: "update",
            eventUpdates: .init(state: state),
            name: "Safari stream update",
            contents: ["en": "Stream status updated"],
            staleDate: Int(Date().addingTimeInterval(15 * 60).timeIntervalSince1970),
            dismissalDate: nil,
            priority: 10,
            iosRelevanceScore: 0.9
        )
        return try await send(payload, activityID: activityID)
    }

    func end(activityID: String, state: SafariStreamActivityAttributes.ContentState) async throws -> String {
        let payload = LiveActivityPayload(
            event: "end",
            eventUpdates: .init(state: state),
            name: "Safari stream ended",
            contents: ["en": "Stream ended"],
            staleDate: nil,
            dismissalDate: Int(Date().addingTimeInterval(-60).timeIntervalSince1970),
            priority: 10,
            iosRelevanceScore: 0
        )
        return try await send(payload, activityID: activityID)
    }

    private func send(_ payload: LiveActivityPayload, activityID: String) async throws -> String {
        let url = URL(string: "https://api.onesignal.com/apps/\(appID)/live_activities/\(activityID)/notifications")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OneSignalLiveActivityError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw OneSignalLiveActivityError.requestFailed(message)
        }

        return (try? JSONDecoder().decode(OneSignalResponse.self, from: data).id) ?? "sent"
    }

    private var authorizationHeader: String {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("key ") {
            return trimmed
        }
        return "Key \(trimmed)"
    }
}

private struct LiveActivityPayload: Encodable {
    var event: String
    var eventUpdates: LiveActivityEventUpdates
    var name: String
    var contents: [String: String]
    var staleDate: Int?
    var dismissalDate: Int?
    var priority: Int
    var iosRelevanceScore: Double

    enum CodingKeys: String, CodingKey {
        case event
        case eventUpdates = "event_updates"
        case name
        case contents
        case staleDate = "stale_date"
        case dismissalDate = "dismissal_date"
        case priority
        case iosRelevanceScore = "ios_relevance_score"
    }
}

private struct LiveActivityEventUpdates: Encodable {
    var status: String
    var viewerCount: Int
    var elapsedSeconds: Int
    var quality: String
    var isLive: Bool
    var iconName: String
    var headline: String
    var detailLine1: String
    var detailLine2: String

    init(state: SafariStreamActivityAttributes.ContentState) {
        status = state.status
        viewerCount = state.viewerCount
        elapsedSeconds = state.elapsedSeconds
        quality = state.quality
        isLive = state.isLive
        iconName = state.iconName
        headline = state.headline
        detailLine1 = state.detailLine1
        detailLine2 = state.detailLine2
    }
}

private struct OneSignalResponse: Decodable {
    var id: String
}

enum OneSignalLiveActivityError: LocalizedError {
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "OneSignal returned an invalid response."
        case let .requestFailed(message):
            return message
        }
    }
}

import ActivityKit
import Foundation
import OneSignalLiveActivities

public struct SafariStreamActivityAttributes: OneSignalLiveActivityAttributes {
    public struct ContentState: OneSignalLiveActivityContentState {
        public var status: String
        public var viewerCount: Int
        public var elapsedSeconds: Int
        public var quality: String
        public var isLive: Bool
        public var iconName: String
        public var headline: String
        public var detailLine1: String
        public var detailLine2: String
        public var onesignal: OneSignalLiveActivityContentStateData?

        public init(
            status: String,
            viewerCount: Int,
            elapsedSeconds: Int,
            quality: String,
            isLive: Bool,
            iconName: String,
            headline: String,
            detailLine1: String,
            detailLine2: String,
            onesignal: OneSignalLiveActivityContentStateData? = nil
        ) {
            self.status = status
            self.viewerCount = viewerCount
            self.elapsedSeconds = elapsedSeconds
            self.quality = quality
            self.isLive = isLive
            self.iconName = iconName
            self.headline = headline
            self.detailLine1 = detailLine1
            self.detailLine2 = detailLine2
            self.onesignal = onesignal
        }
    }

    public var title: String
    public var hostName: String
    public var startedAt: Date
    public var onesignal: OneSignalLiveActivityAttributeData

    public init(
        title: String,
        hostName: String,
        startedAt: Date,
        onesignal: OneSignalLiveActivityAttributeData
    ) {
        self.title = title
        self.hostName = hostName
        self.startedAt = startedAt
        self.onesignal = onesignal
    }
}

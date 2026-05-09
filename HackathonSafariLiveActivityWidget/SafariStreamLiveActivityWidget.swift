import ActivityKit
import OneSignalLiveActivities
import SwiftUI
import WidgetKit

struct SafariStreamLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SafariStreamActivityAttributes.self) { context in
            VStack(spacing: 12) {
                liveActivityIcon(context.state.iconName, size: iconSize(for: context.state.iconName, base: 42))
                    .frame(width: 66, height: 66)
                    .foregroundStyle(.white)
                    .background(context.state.isLive ? Color.red : Color.secondary, in: RoundedRectangle(cornerRadius: 8))

                Text(context.state.headline)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text(context.state.detailLine1)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)
            .onesignalWidgetURL(URL(string: "hackathonsafari://stream/\(context.attributes.onesignal.activityId)"), context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    liveActivityIcon(context.state.iconName, size: iconSize(for: context.state.iconName, base: 26))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        Text(context.state.headline)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(context.state.detailLine1)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            } compactLeading: {
                liveActivityIcon(context.state.iconName, size: iconSize(for: context.state.iconName, base: 16))
                    .foregroundStyle(.white)
            } compactTrailing: {
                EmptyView()
            } minimal: {
                liveActivityIcon(context.state.iconName, size: iconSize(for: context.state.iconName, base: 14))
                    .foregroundStyle(.white)
            }
            .keylineTint(.red)
            .onesignalWidgetURL(URL(string: "hackathonsafari://stream/\(context.attributes.onesignal.activityId)"), context: context)
        }
    }

    @ViewBuilder
    private func liveActivityIcon(_ iconName: String, size: CGFloat) -> some View {
        if let emoji = emojiValue(from: iconName) {
            Text(emoji)
                .font(.system(size: size))
        } else {
            Image(systemName: iconName)
                .font(.system(size: size, weight: .semibold))
        }
    }

    private func emojiValue(from iconName: String) -> String? {
        let prefix = "emoji:"
        guard iconName.hasPrefix(prefix) else { return nil }
        return String(iconName.dropFirst(prefix.count))
    }

    private func iconSize(for iconName: String, base: CGFloat) -> CGFloat {
        emojiValue(from: iconName) == nil ? base : base + 8
    }
}

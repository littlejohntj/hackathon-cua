import ActivityKit
import OneSignalLiveActivities
import SwiftUI
import WidgetKit

struct SafariStreamLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SafariStreamActivityAttributes.self) { context in
            VStack(spacing: 12) {
                Image(systemName: context.state.iconName)
                    .font(.system(size: 42, weight: .semibold))
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
                    Image(systemName: context.state.iconName)
                        .font(.title2.weight(.semibold))
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
                Image(systemName: context.state.iconName)
                    .foregroundStyle(.white)
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Image(systemName: context.state.iconName)
                    .foregroundStyle(.white)
            }
            .keylineTint(.red)
            .onesignalWidgetURL(URL(string: "hackathonsafari://stream/\(context.attributes.onesignal.activityId)"), context: context)
        }
    }
}

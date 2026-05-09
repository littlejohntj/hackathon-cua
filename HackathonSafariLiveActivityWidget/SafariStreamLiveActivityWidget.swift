import ActivityKit
import OneSignalLiveActivities
import SwiftUI
import WidgetKit

struct SafariStreamLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SafariStreamActivityAttributes.self) { context in
            VStack(spacing: 14) {
                HStack {
                    Label(context.state.isLive ? "LIVE" : "OFFLINE", systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption.weight(.black))
                        .foregroundStyle(context.state.isLive ? .red : .secondary)
                    Spacer()
                    Text(context.state.quality)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    Image(systemName: context.state.iconName)
                        .font(.system(size: 38, weight: .semibold))
                        .frame(width: 62, height: 62)
                        .foregroundStyle(.white)
                        .background(context.state.isLive ? Color.red : Color.secondary, in: RoundedRectangle(cornerRadius: 8))

                    Text(context.state.headline)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 20) {
                    Spacer()
                    metric("\(context.state.viewerCount)", "viewers")
                    metric(elapsedTime(context.state.elapsedSeconds), "elapsed")
                    metric(context.state.status, "status")
                    Spacer()
                }

                VStack(spacing: 4) {
                    Text(context.state.detailLine1)
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)
                    Text(context.state.detailLine2)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
            }
            .padding()
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(.primary)
            .onesignalWidgetURL(URL(string: "hackathonsafari://stream/\(context.attributes.onesignal.activityId)"), context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: context.state.iconName)
                            .font(.title3.weight(.semibold))
                        VStack(alignment: .leading) {
                            Text(context.attributes.hostName)
                                .font(.caption)
                            Text(context.state.quality)
                                .font(.headline)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("\(context.state.viewerCount)")
                            .font(.headline)
                        Text("viewers")
                            .font(.caption2)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        Text(context.state.headline)
                            .font(.headline.weight(.bold))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(context.state.detailLine1)
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                        Text(context.state.detailLine2)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            } compactLeading: {
                Image(systemName: context.state.iconName)
            } compactTrailing: {
                Text("\(context.state.viewerCount)")
            } minimal: {
                Image(systemName: context.state.iconName)
            }
            .keylineTint(.red)
            .onesignalWidgetURL(URL(string: "hackathonsafari://stream/\(context.attributes.onesignal.activityId)"), context: context)
        }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func elapsedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }
}

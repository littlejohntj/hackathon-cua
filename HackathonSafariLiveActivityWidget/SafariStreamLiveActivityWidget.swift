import ActivityKit
import OneSignalLiveActivities
import SwiftUI
import WidgetKit

struct SafariStreamLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SafariStreamActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(context.state.isLive ? "Live" : "Offline", systemImage: "dot.radiowaves.left.and.right")
                        .font(.headline)
                    Spacer()
                    Text(context.state.quality)
                        .font(.subheadline.weight(.semibold))
                }

                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: context.state.iconName)
                        .font(.system(size: 42, weight: .semibold))
                        .frame(width: 58, height: 58)
                        .foregroundStyle(.white)
                        .background(context.state.isLive ? Color.red : Color.secondary, in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.headline)
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                        Text(context.attributes.hostName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 16) {
                    metric("\(context.state.viewerCount)", "viewers")
                    metric(elapsedTime(context.state.elapsedSeconds), "elapsed")
                    Spacer()
                    Text(context.state.status)
                        .font(.caption.weight(.semibold))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(context.state.detailLine1)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(context.state.detailLine2)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
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
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.state.headline)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        HStack {
                            Text(context.state.detailLine1)
                                .lineLimit(1)
                            Spacer()
                            Text(elapsedTime(context.state.elapsedSeconds))
                        }
                        .font(.caption2)
                    }
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
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
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

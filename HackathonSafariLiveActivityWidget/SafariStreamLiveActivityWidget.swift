import ActivityKit
import OneSignalLiveActivities
import SwiftUI
import WidgetKit

struct SafariStreamLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SafariStreamActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(context.state.isLive ? "Live" : "Offline", systemImage: "dot.radiowaves.left.and.right")
                        .font(.headline)
                    Spacer()
                    Text(context.state.quality)
                        .font(.subheadline.weight(.semibold))
                }

                Text(context.attributes.title)
                    .font(.title3.weight(.semibold))

                HStack(spacing: 16) {
                    metric("\(context.state.viewerCount)", "viewers")
                    metric(elapsedTime(context.state.elapsedSeconds), "elapsed")
                    Spacer()
                    Text(context.state.status)
                        .font(.caption.weight(.semibold))
                }
            }
            .padding()
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(.primary)
            .onesignalWidgetURL(URL(string: "hackathonsafari://stream/\(context.attributes.onesignal.activityId)"), context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text(context.attributes.hostName)
                            .font(.caption)
                        Text(context.state.quality)
                            .font(.headline)
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
                    HStack {
                        Text(context.state.status)
                        Spacer()
                        Text(elapsedTime(context.state.elapsedSeconds))
                    }
                    .font(.caption)
                }
            } compactLeading: {
                Image(systemName: context.state.isLive ? "dot.radiowaves.left.and.right" : "pause.fill")
            } compactTrailing: {
                Text("\(context.state.viewerCount)")
            } minimal: {
                Image(systemName: "livephoto")
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

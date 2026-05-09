import ActivityKit
import SwiftUI
import WidgetKit

struct NorthstarGuideActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NorthstarGuideActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(context.state.isActive ? "Northstar" : "Paused", systemImage: context.state.isActive ? "sparkles" : "pause.fill")
                        .font(.headline)
                    Spacer()
                    Text("\(context.state.framesSeen) frames")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(context.state.instruction.isEmpty ? "Waiting for a changed screen…" : context.state.instruction)
                    .font(.title3.weight(.semibold))
                    .lineLimit(3)

                Text(context.attributes.task)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding()
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Northstar")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.instruction.isEmpty ? "Waiting for screen change…" : context.state.instruction)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                }
            } compactLeading: {
                Image(systemName: "sparkles")
            } compactTrailing: {
                Text("\(context.state.framesSeen)")
            } minimal: {
                Image(systemName: "sparkles")
            }
            .keylineTint(.blue)
        }
    }
}

import SwiftUI

struct ContentView: View {
    @StateObject private var screenShare = ScreenShareController()
    @StateObject private var liveActivity = LiveActivityDemoModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    screenSharePanel
                    liveActivityPanel
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Hackathon Safari")
        }
    }

    private var screenSharePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Screen stream", systemImage: "rectangle.on.rectangle")
                .font(.headline)

            preview

            TextField("WebSocket relay URL", text: $screenShare.endpoint)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Button {
                    screenShare.startButtonTapped()
                } label: {
                    Label("In-app", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(screenShare.isSharing)

                Button {
                    screenShare.stopButtonTapped()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!screenShare.isSharing)

                BroadcastPickerView(preferredExtension: AppConfiguration.broadcastUploadExtensionBundleID)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                statusPill(screenShare.status, systemImage: screenShare.isSharing ? "dot.radiowaves.left.and.right" : "circle")
                Spacer()
                Text("\(screenShare.framesCaptured) frames")
                Text("\(screenShare.framesSent) sent")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .panelStyle()
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .aspectRatio(16 / 9, contentMode: .fit)

            if let previewImage = screenShare.previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "display")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var liveActivityPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("OneSignal Live Activity", systemImage: "livephoto")
                .font(.headline)

            TextField("Activity ID", text: $liveActivity.activityID)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)

            SecureField("OneSignal API key", text: $liveActivity.apiKey)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Button {
                    liveActivity.startButtonTapped()
                } label: {
                    Label("Start", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    liveActivity.localTickButtonTapped()
                } label: {
                    Label("Local", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)

                Button {
                    liveActivity.sendOneSignalUpdateButtonTapped()
                } label: {
                    Label("OneSignal", systemImage: "paperplane.fill")
                }
                .buttonStyle(.bordered)
                .disabled(liveActivity.apiKey.isEmpty)

                Button(role: .destructive) {
                    liveActivity.endButtonTapped()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("End Live Activity")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    statusPill(liveActivity.status, systemImage: liveActivity.isLive ? "bolt.fill" : "circle")
                    Spacer()
                    Text("\(liveActivity.viewerCount) viewers")
                    Text(liveActivity.quality)
                }
                if let requestID = liveActivity.lastOneSignalRequestID {
                    Text("OneSignal request \(requestID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .panelStyle()
    }

    private func statusPill(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
    }
}

private extension View {
    func panelStyle() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ContentView()
}

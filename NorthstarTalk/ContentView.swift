import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var engine = NorthstarEngine()
    @StateObject private var guide = ScreenGuideController()
    @State private var importingModel = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    modelControls
                    guideControls
                    preview
                    instructionPanel
                    debugPanel
                }
                .padding()
            }
            .navigationTitle("Northstar")
        }
        .fileImporter(
            isPresented: $importingModel,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await engine.installModel(from: url) }
            case .failure(let error):
                engine.report(error)
            }
        }
        .task {
            AppLog.info("ContentView task begin")
            engine.refreshModelState()
            if engine.modelInstalled && !engine.isReady {
                await engine.load()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            AppLog.info("scene phase=\(String(describing: phase))")
        }
    }

    private var modelControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(engine.status)
                .font(.callout)
            Text(engine.modelPath)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack {
                Button("Manual import…") { importingModel = true }
                    .disabled(engine.isLoading || engine.isGenerating)
                Button(engine.isReady ? "Loaded" : "Load model") { Task { await engine.load() } }
                    .disabled(engine.isReady || !engine.modelInstalled || engine.isLoading || engine.isGenerating)
                if engine.isLoading {
                    ProgressView()
                }
            }
        }
        .panelStyle()
    }

    private var guideControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Screen guidance", systemImage: "rectangle.on.rectangle")
                .font(.headline)

            TextField("Task, e.g. how do I disable Slack notifications", text: $guide.prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
                .disabled(guide.isRunning)

            HStack(spacing: 12) {
                BroadcastStartButton(
                    preferredExtension: AppConfiguration.frameUploadExtensionBundleID,
                    isDisabled: !engine.isReady || guide.isRunning || guide.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    _ = guide.start(engine: engine)
                }

                Button(role: .destructive) {
                    guide.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!guide.isRunning)
            }

            Text("Tap Start guide, choose Northstar in the iOS broadcast picker, then switch to the target app. Stopping the guide also asks the broadcast extension to stop.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                statusPill(guide.status, systemImage: guide.replayKitLive ? "dot.radiowaves.left.and.right" : "circle")
                if guide.isAnalyzing {
                    ProgressView()
                }
            }
            .font(.caption)

            HStack(spacing: 12) {
                Text("\(guide.framesReceived) received")
                Text("\(guide.framesAccepted) changed")
                Text("\(guide.framesSkipped) skipped")
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
                .aspectRatio(9 / 16, contentMode: .fit)

            if let image = guide.latestImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "iphone")
                        .font(.system(size: 44, weight: .semibold))
                    Text("No ReplayKit frame yet")
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var instructionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Next instruction", systemImage: "sparkles")
                .font(.headline)
            Text(guide.instruction.isEmpty ? "Waiting for a changed screen…" : guide.instruction)
                .font(.title3.weight(.semibold))
                .textSelection(.enabled)
            Text(guide.liveActivityStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .panelStyle()
    }

    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Debug", systemImage: "ladybug")
                .font(.headline)
            if guide.debugLines.isEmpty {
                Text("No guide events yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(guide.debugLines.suffix(16).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
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
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ContentView()
}

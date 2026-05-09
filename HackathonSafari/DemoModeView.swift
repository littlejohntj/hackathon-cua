import SwiftUI

struct DemoModeView: View {
    @State private var prompt = ""
    @State private var isReady = false
    @FocusState private var isPromptFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isReady {
                    readyView
                } else {
                    promptView
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Demo Mode")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var promptView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("👋")
                .font(.system(size: 72))
                .frame(maxWidth: .infinity)

            Text("Prompt")
                .font(.headline)

            TextEditor(text: $prompt)
                .focused($isPromptFocused)
                .frame(minHeight: 150)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    if prompt.isEmpty {
                        Text("Type the prompt you want to demo...")
                            .foregroundStyle(.secondary)
                            .padding(18)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                    }
                }

            Button {
                isPromptFocused = false
                isReady = true
            } label: {
                Label("Prepare Demo", systemImage: "hand.wave.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .panelStyle()
    }

    private var readyView: some View {
        VStack(spacing: 20) {
            Text("👋")
                .font(.system(size: 108))

            Text("Leave the app and tap on the hand!")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)

            if !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(prompt)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                isReady = false
            } label: {
                Label("Edit Prompt", systemImage: "pencil")
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationStack {
        DemoModeView()
    }
}

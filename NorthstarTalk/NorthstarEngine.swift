import AVFoundation
import CoreImage
import Foundation
import MLX
import MLXLMCommon
import MLXVLM
import UIKit

private struct GuideRequest: Encodable, Sendable {
    let task: String
    let imageBase64: String
}

private struct GuideResponse: Decodable, Sendable {
    let instruction: String?
    let error: String?
}

private struct GuideInferenceResult: Sendable {
    let text: String
    let chunks: Int
}

struct ChatTurn: Identifiable, Equatable {
    enum Role: String {
        case user = "You"
        case assistant = "Northstar"
    }

    let id = UUID()
    let role: Role
    var text: String
}

enum ModelFiles {
    static let folderName = "Northstar-CUA-Fast-4bit"
    static let requiredFiles = [
        "config.json",
        "tokenizer.json",
        "tokenizer_config.json",
        "chat_template.json",
        "preprocessor_config.json",
    ]

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var preferredURL: URL {
        documentsURL.appendingPathComponent(folderName, isDirectory: true)
    }

    static var modelURL: URL {
        findModelURL() ?? preferredURL
    }

    static var exists: Bool {
        findModelURL() != nil
    }

    static func findModelURL() -> URL? {
        let fileManager = FileManager.default
        let candidates = [preferredURL, documentsURL]
        for candidate in candidates where isModelDirectory(candidate, fileManager: fileManager) {
            return candidate
        }

        guard let enumerator = fileManager.enumerator(
            at: documentsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let url as URL in enumerator {
            let depth = url.pathComponents.count - documentsURL.pathComponents.count
            if depth > 3 {
                enumerator.skipDescendants()
                continue
            }
            if isModelDirectory(url, fileManager: fileManager) {
                return url
            }
        }
        return nil
    }

    static func install(from source: URL) throws {
        let source = source.standardizedFileURL
        let target = preferredURL.standardizedFileURL
        let fileManager = FileManager.default
        let modelSource = try findModelURL(in: source, fileManager: fileManager)

        if modelSource != target {
            if fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: target)
            }
            try fileManager.createDirectory(
                at: target.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try fileManager.copyItem(at: modelSource, to: target)
        }

        try validate(at: target)
    }

    static func validate(at url: URL? = nil) throws {
        let resolved = url ?? modelURL
        guard isModelDirectory(resolved, fileManager: .default) else {
            throw ModelFileError.invalidDirectory(resolved.path)
        }
    }

    private static func findModelURL(in source: URL, fileManager: FileManager) throws -> URL {
        if isModelDirectory(source, fileManager: fileManager) {
            return source
        }

        guard let enumerator = fileManager.enumerator(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw ModelFileError.invalidDirectory(source.path)
        }

        for case let url as URL in enumerator {
            let depth = url.pathComponents.count - source.pathComponents.count
            if depth > 3 {
                enumerator.skipDescendants()
                continue
            }
            if isModelDirectory(url, fileManager: fileManager) {
                return url
            }
        }
        throw ModelFileError.invalidDirectory(source.path)
    }

    private static func isModelDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }

        for name in requiredFiles where !fileManager.fileExists(atPath: url.appendingPathComponent(name).path) {
            return false
        }

        guard let files = try? fileManager.contentsOfDirectory(atPath: url.path) else {
            return false
        }
        return files.contains(where: { $0.hasSuffix(".safetensors") })
    }
}

enum ModelFileError: LocalizedError {
    case invalidDirectory(String)

    var errorDescription: String? {
        switch self {
        case .invalidDirectory(let path):
            "No MLX model found at \(path). Expected config.json, tokenizer.json, chat_template.json, preprocessor_config.json, and a .safetensors file."
        }
    }
}

@MainActor
final class VoiceOutput {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        AppLog.info("tts start chars=\(trimmed.count)")
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }
}

@MainActor
final class NorthstarEngine: ObservableObject {
    @Published private(set) var status = "Laptop guide server: \(AppConfiguration.guideServerURL.absoluteString)"
    @Published private(set) var modelInstalled = true
    @Published private(set) var isLoading = false
    @Published private(set) var isGenerating = false

    private let speaker = VoiceOutput()
    private var modelContainer: ModelContainer?

    init() {
        AppLog.info("NorthstarEngine init installed=\(modelInstalled) path=\(ModelFiles.modelURL.path)")
    }

    var modelPath: String { AppConfiguration.guideServerURL.absoluteString }
    var isReady: Bool { true }

    private var generateParameters: GenerateParameters {
        GenerateParameters(
            maxTokens: 96,
            kvBits: 4,
            temperature: 0.2,
            topP: 0.85,
            prefillStepSize: 64
        )
    }

    private var guideGenerateParameters: GenerateParameters {
        GenerateParameters(
            maxTokens: 48,
            kvBits: 4,
            temperature: 0.1,
            topP: 0.8,
            prefillStepSize: 32
        )
    }

    private var guideInstructions: String {
        """
        You are Northstar, an on-device screen guidance assistant. The user is trying to complete a task on an iPhone. You see exactly one current screenshot.

        Output exactly one short next-step instruction in natural language. Do not output JSON. Do not mention that you are looking at a screenshot. Do not give multiple steps. Prefer visible labels and locations.

        If the user should tap something, say what and where: “Tap the lower-right blue button labeled ‘Next’.”
        If the user should type, say exactly what field to use: “Type the email address into the field labeled ‘Email’.”
        If the needed UI is not visible, tell the user the one app or screen to open next.
        If the task appears complete, start with “Done —”.

        Examples:
        User task: Disable Slack notifications.
        Screen: iPhone Settings list.
        Assistant: Tap “Notifications” in the Settings list.

        User task: Disable Slack notifications.
        Screen: Notifications settings list with Slack visible.
        Assistant: Tap “Slack” in the notifications app list.

        User task: Sign in.
        Screen: Login page with a blue Continue button.
        Assistant: Tap the blue “Continue” button at the bottom.
        """
    }

    private func makeGuideSession(_ modelContainer: ModelContainer) -> ChatSession {
        ChatSession(
            modelContainer,
            instructions: guideInstructions,
            generateParameters: guideGenerateParameters,
            processing: .init(resize: CGSize(width: 224, height: 224))
        )
    }

    func refreshModelState() {
        modelInstalled = true
        status = "Laptop guide server: \(AppConfiguration.guideServerURL.absoluteString)"
        AppLog.info("refreshModelState server=\(AppConfiguration.guideServerURL.absoluteString)")
    }

    func report(_ error: Error) {
        AppLog.error("reported error=\(error.localizedDescription)")
        status = error.localizedDescription
    }

    func installModel(from source: URL) async {
        AppLog.info("installModel source=\(source.path)")
        status = "Copying model into the app sandbox…"
        isLoading = true
        defer { isLoading = false }

        do {
            try await Task.detached(priority: .userInitiated) {
                let scoped = source.startAccessingSecurityScopedResource()
                defer {
                    if scoped {
                        source.stopAccessingSecurityScopedResource()
                    }
                }
                try ModelFiles.install(from: source)
            }.value
            modelInstalled = true
            AppLog.info("installModel complete target=\(ModelFiles.modelURL.path)")
            status = "Model installed. Loading…"
            isLoading = false
            await load()
        } catch {
            modelInstalled = ModelFiles.exists
            AppLog.error("installModel failed error=\(error.localizedDescription)")
            status = error.localizedDescription
        }
    }

    func load() async {
        AppLog.info("server mode ready url=\(AppConfiguration.guideServerURL.absoluteString)")
        modelInstalled = true
        status = "Ready. Start `make guide-server` on the Mac, then start guidance."
    }

    func instruction(for task: String, imageData: Data) async throws -> String {
        let callID = String(UUID().uuidString.prefix(8))
        let task = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !task.isEmpty else { throw GuideError.emptyTask }
        guard CIImage(data: imageData) != nil else { throw GuideError.invalidImage }
        guard !isGenerating else { throw GuideError.alreadyGenerating }

        isGenerating = true
        status = "Sending screen to laptop…"
        AppLog.info("guide \(callID) laptop begin taskChars=\(task.count) imageBytes=\(imageData.count) url=\(AppConfiguration.guideServerURL.absoluteString)")
        defer {
            isGenerating = false
            AppLog.info("guide \(callID) laptop finished")
        }

        var request = URLRequest(url: AppConfiguration.guideServerURL.appendingPathComponent("guide"))
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(GuideRequest(
            task: task,
            imageBase64: imageData.base64EncodedString()
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let decoded = try JSONDecoder().decode(GuideResponse.self, from: data)
        if statusCode != 200 {
            throw GuideError.server(decoded.error ?? "HTTP \(statusCode)")
        }
        let cleaned = (decoded.instruction ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let singleLine = cleaned.replacingOccurrences(of: "\n", with: " ")
        let preview = singleLine.count <= 180 ? singleLine : String(singleLine.prefix(180)) + "…"
        AppLog.info("guide \(callID) laptop ended responseChars=\(cleaned.count) response=\(preview)")
        status = "Ready."
        return cleaned.isEmpty ? "I don't see the next step yet — try opening the relevant app or settings screen." : cleaned
    }

    func speak(_ text: String) {
        speaker.speak(text)
    }
}

enum GuideError: LocalizedError {
    case emptyTask
    case modelNotLoaded
    case invalidImage
    case alreadyGenerating
    case server(String)

    var errorDescription: String? {
        switch self {
        case .emptyTask:
            "Enter a task first."
        case .modelNotLoaded:
            "Load the model first."
        case .invalidImage:
            "ReplayKit sent an unreadable image."
        case .alreadyGenerating:
            "Northstar is already analyzing a frame."
        case .server(let message):
            "Laptop guide server error: \(message)"
        }
    }
}

import AVFoundation
import Combine
import Speech

private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
    await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
            continuation.resume(returning: status)
        }
    }
}

private func requestMicrophoneAuthorization() async -> Bool {
    await withCheckedContinuation { continuation in
        AVAudioApplication.requestRecordPermission { allowed in
            continuation.resume(returning: allowed)
        }
    }
}

private func installSpeechTap(on inputNode: AVAudioInputNode, request: SFSpeechAudioBufferRecognitionRequest) {
    AppLog.info("speech install tap format=\(inputNode.outputFormat(forBus: 0))")
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { [weak request] buffer, _ in
        request?.append(buffer)
    }
}

@MainActor
final class SpeechIO: NSObject, ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isRecording = false
    @Published private(set) var permissionStatus = "Speech permission not requested."

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func requestPermissions() async {
        AppLog.info("speech permissions begin")
        let speechStatus = await requestSpeechAuthorization()
        let microphoneAllowed = await requestMicrophoneAuthorization()
        AppLog.info("speech permissions result speech=\(speechStatus.rawValue) mic=\(microphoneAllowed)")

        switch (speechStatus, microphoneAllowed) {
        case (.authorized, true):
            permissionStatus = "Speech ready."
        case (.denied, _):
            permissionStatus = "Speech recognition denied in Settings."
        case (.restricted, _):
            permissionStatus = "Speech recognition is restricted on this device."
        case (.notDetermined, _):
            permissionStatus = "Speech recognition permission is not decided."
        case (_, false):
            permissionStatus = "Microphone denied in Settings."
        default:
            permissionStatus = "Speech permission is unavailable."
        }
    }

    func start() async throws {
        AppLog.info("speech start requested recording=\(isRecording)")
        if SFSpeechRecognizer.authorizationStatus() != .authorized {
            await requestPermissions()
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            AppLog.error("speech start rejected speech authorization=\(SFSpeechRecognizer.authorizationStatus().rawValue)")
            throw SpeechIOError.speechNotAuthorized
        }
        guard AVAudioApplication.shared.recordPermission == .granted else {
            AppLog.error("speech start microphone permission=\(AVAudioApplication.shared.recordPermission.rawValue)")
            await requestPermissions()
            guard AVAudioApplication.shared.recordPermission == .granted else {
                throw SpeechIOError.microphoneNotAuthorized
            }
            return try await start()
        }
        guard let recognizer, recognizer.isAvailable else {
            AppLog.error("speech start recognizer unavailable")
            throw SpeechIOError.recognizerUnavailable
        }
        guard !isRecording else {
            AppLog.info("speech start ignored already recording")
            return
        }

        transcript = ""
        task?.cancel()
        task = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        installSpeechTap(on: inputNode, request: request)

        audioEngine.prepare()
        try audioEngine.start()
        AppLog.info("speech audioEngine started")
        isRecording = true
        permissionStatus = "Listening…"

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                if let result {
                    self?.transcript = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self?.finishRecording()
                }
            }
        }
    }

    func stop() -> String {
        AppLog.info("speech stop requested transcriptChars=\(transcript.count)")
        finishRecording()
        return transcript
    }

    private func finishRecording() {
        guard isRecording || request != nil || task != nil else { return }

        AppLog.info("speech finish recording transcriptChars=\(transcript.count)")
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        permissionStatus = "Speech ready."
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

enum SpeechIOError: LocalizedError {
    case speechNotAuthorized
    case microphoneNotAuthorized
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .speechNotAuthorized:
            "Speech recognition is not authorized."
        case .microphoneNotAuthorized:
            "Microphone access is not authorized."
        case .recognizerUnavailable:
            "Speech recognizer is not available."
        }
    }
}

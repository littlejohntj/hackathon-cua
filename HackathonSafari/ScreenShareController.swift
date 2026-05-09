import Combine
import CoreImage
import ReplayKit
import SwiftUI
import UIKit

@MainActor
final class ScreenShareController: ObservableObject {
    @Published var endpoint: String {
        didSet {
            UserDefaults(suiteName: AppConfiguration.appGroupID)?.set(endpoint, forKey: "broadcastRelayURL")
        }
    }
    @Published var status = "Ready"
    @Published var isSharing = false
    @Published var framesCaptured = 0
    @Published var framesSent = 0
    @Published var previewImage: UIImage?

    private let recorder = RPScreenRecorder.shared()
    private let imageContext = CIContext()
    private var webSocket: URLSessionWebSocketTask?
    private var lastFrameSentAt = Date.distantPast

    init() {
        let defaults = UserDefaults(suiteName: AppConfiguration.appGroupID)
        let savedEndpoint = defaults?.string(forKey: "broadcastRelayURL")
        endpoint = Self.isDeviceLocalRelayURL(savedEndpoint) ? AppConfiguration.defaultRelayURL : savedEndpoint ?? AppConfiguration.defaultRelayURL
        defaults?.set(endpoint, forKey: "broadcastRelayURL")
    }

    func startButtonTapped() {
        guard !isSharing else { return }

        framesCaptured = 0
        framesSent = 0
        previewImage = nil
        status = "Starting capture"
        openRelayIfNeeded()

        recorder.isMicrophoneEnabled = true
        recorder.startCapture { [weak self] sampleBuffer, sampleBufferType, error in
            guard let self else { return }
            if let error {
                Task { @MainActor in
                    self.status = error.localizedDescription
                }
                return
            }
            guard sampleBufferType == .video else { return }
            self.processVideoSample(sampleBuffer)
        } completionHandler: { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.status = error.localizedDescription
                    self?.isSharing = false
                } else {
                    self?.status = "Streaming screen"
                    self?.isSharing = true
                }
            }
        }
    }

    func stopButtonTapped() {
        guard isSharing else { return }
        recorder.stopCapture { [weak self] error in
            Task { @MainActor in
                self?.webSocket?.cancel(with: .goingAway, reason: nil)
                self?.webSocket = nil
                self?.isSharing = false
                self?.status = error?.localizedDescription ?? "Stopped"
            }
        }
    }

    private func openRelayIfNeeded() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil

        guard let url = URL(string: endpoint), ["ws", "wss"].contains(url.scheme?.lowercased()) else {
            status = "Capturing locally"
            return
        }

        let task = URLSession.shared.webSocketTask(with: url)
        task.resume()
        webSocket = task
    }

    private func processVideoSample(_ sampleBuffer: CMSampleBuffer) {
        let now = Date()
        guard now.timeIntervalSince(lastFrameSentAt) >= 1.0 / 12.0 else { return }
        lastFrameSentAt = now

        guard
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
            let jpegData = jpegData(from: imageBuffer),
            let image = UIImage(data: jpegData)
        else { return }

        Task { @MainActor in
            self.framesCaptured += 1
            self.previewImage = image
            self.sendFrame(jpegData)
        }
    }

    private func jpegData(from imageBuffer: CVImageBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = imageContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.52)
    }

    private func sendFrame(_ data: Data) {
        guard let webSocket else { return }
        webSocket.send(.data(data)) { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.status = "Relay error: \(error.localizedDescription)"
                } else {
                    self?.framesSent += 1
                }
            }
        }
    }

    private static func isDeviceLocalRelayURL(_ endpoint: String?) -> Bool {
        guard
            let endpoint,
            let url = URL(string: endpoint),
            let host = url.host(percentEncoded: false)?.lowercased()
        else { return false }

        return ["localhost", "127.0.0.1", "::1"].contains(host)
    }
}

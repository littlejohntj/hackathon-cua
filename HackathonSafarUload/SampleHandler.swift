//
//  SampleHandler.swift
//  HackathonSafarUload
//
//  Created by Todd Littlejohn on 5/9/26.
//

import ReplayKit
import CoreImage
import UIKit

class SampleHandler: RPBroadcastSampleHandler {
    private let imageContext = CIContext()
    private var webSocket: URLSessionWebSocketTask?
    private var lastFrameSentAt = Date.distantPast
    private var framesSent = 0

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        let endpoint = setupInfo?["endpoint"] as? String
            ?? UserDefaults(suiteName: "group.com.jootsing.HackathonSafari")?.string(forKey: "broadcastRelayURL")
            ?? "ws://localhost:8080/broadcast"

        guard let url = URL(string: endpoint), ["ws", "wss"].contains(url.scheme?.lowercased()) else {
            return
        }

        let task = URLSession.shared.webSocketTask(with: url)
        task.resume()
        webSocket = task
    }
    
    override func broadcastPaused() {
        sendControlMessage("paused")
    }
    
    override func broadcastResumed() {
        sendControlMessage("resumed")
    }
    
    override func broadcastFinished() {
        sendControlMessage("finished")
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            processVideo(sampleBuffer)
        case RPSampleBufferType.audioApp:
            break
        case RPSampleBufferType.audioMic:
            break
        @unknown default:
            break
        }
    }

    private func processVideo(_ sampleBuffer: CMSampleBuffer) {
        let now = Date()
        guard now.timeIntervalSince(lastFrameSentAt) >= 1.0 / 12.0 else { return }
        lastFrameSentAt = now

        guard
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
            let data = jpegData(from: imageBuffer)
        else { return }

        webSocket?.send(.data(data)) { [weak self] error in
            guard let self, error == nil else { return }
            self.framesSent += 1
        }
    }

    private func jpegData(from imageBuffer: CVImageBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = imageContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.52)
    }

    private func sendControlMessage(_ event: String) {
        let payload = #"{"type":"broadcast","\#(event)":{"framesSent":\#(framesSent)}}"#
        webSocket?.send(.string(payload)) { _ in }
    }
}

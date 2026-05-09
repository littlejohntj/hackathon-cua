import CoreGraphics
import Foundation
import UIKit

struct FrameSignature: Equatable {
    static let width = 32
    static let height = 32

    let pixels: [UInt8]

    init?(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return nil }
        var pixels = [UInt8](repeating: 0, count: Self.width * Self.height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &pixels,
            width: Self.width,
            height: Self.height,
            bitsPerComponent: 8,
            bytesPerRow: Self.width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: Self.width, height: Self.height))
        self.pixels = pixels
    }

    func similarity(to other: FrameSignature, tolerance: UInt8 = 24) -> Double {
        guard pixels.count == other.pixels.count, !pixels.isEmpty else { return 0 }
        var similar = 0
        for index in pixels.indices {
            let delta = abs(Int(pixels[index]) - Int(other.pixels[index]))
            if delta <= Int(tolerance) {
                similar += 1
            }
        }
        return Double(similar) / Double(pixels.count)
    }
}

import Foundation

enum AppConfiguration {
    static let frameUploadExtensionBundleID: String = {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return "NorthstarTalk.FrameUpload"
        }
        return "\(bundleID).FrameUpload"
    }()

    static let frameServerPort: UInt16 = 17771
}

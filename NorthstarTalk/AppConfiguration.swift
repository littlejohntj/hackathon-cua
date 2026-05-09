import Foundation

enum AppConfiguration {
    static let frameUploadExtensionBundleID: String = {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return "NorthstarTalk.FrameUpload"
        }
        return "\(bundleID).FrameUpload"
    }()

    static let frameServerPort: UInt16 = 17771
    static let guideServerURL = URL(string: "http://192.168.2.247:17772")!
}

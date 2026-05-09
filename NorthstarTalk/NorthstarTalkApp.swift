import MLX
import SwiftUI

@main
struct NorthstarTalkApp: App {
    init() {
        Memory.cacheLimit = 20 * 1024 * 1024
        AppLog.bootstrap()
        AppLog.info("NorthstarTalkApp init MLX memoryLimit=\(Memory.memoryLimit) cacheLimit=\(Memory.cacheLimit)")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

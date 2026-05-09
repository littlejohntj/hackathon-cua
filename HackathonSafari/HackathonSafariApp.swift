//
//  HackathonSafariApp.swift
//  HackathonSafari
//
//  Created by Todd Littlejohn on 5/9/26.
//

import SwiftUI
import OneSignalFramework
import OneSignalLiveActivities

@main
struct HackathonSafariApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        OneSignal.Debug.setLogLevel(.LL_VERBOSE)
        OneSignal.initialize(AppConfiguration.oneSignalAppID, withLaunchOptions: launchOptions)

        if #available(iOS 16.1, *) {
            OneSignal.LiveActivities.setup(SafariStreamActivityAttributes.self)
        }

        OneSignal.Notifications.requestPermission({ accepted in
            print("OneSignal notification permission accepted: \(accepted)")
        }, fallbackToSettings: false)

        return true
    }
}

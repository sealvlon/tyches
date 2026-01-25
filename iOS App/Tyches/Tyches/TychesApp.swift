import SwiftUI
import UIKit
import UserNotifications

@main
struct TychesApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var deepLink = DeepLinkRouter()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Ensure phone can sleep normally - set on app launch
        UIApplication.shared.isIdleTimerDisabled = false
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(deepLink)
                .task {
                    await session.bootstrapFromSession()
                    await setupNotifications()
                }
                .onAppear {
                    // Ensure idle timer is enabled (phone can sleep)
                    UIApplication.shared.isIdleTimerDisabled = false
                    // Share deepLink with AppDelegate for notification handling
                    appDelegate.deepLinkRouter = deepLink
                }
                .onOpenURL { url in
                    deepLink.handle(url)
                }
        }
    }
    
    private func setupNotifications() async {
        let granted = await NotificationManager.shared.requestPermission()
        if granted {
            // Set the notification center delegate
            UNUserNotificationCenter.current().delegate = appDelegate
        }
    }
}

// MARK: - App Delegate for Notification Handling

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var deepLinkRouter: DeepLinkRouter?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification banner even when app is in foreground
        completionHandler([.banner, .sound])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Route through DeepLinkRouter
        if let router = deepLinkRouter {
            router.handlePushPayload(userInfo)
        } else {
            // Fallback: post notification for ActivityFeedView to handle
            NotificationCenter.default.post(
                name: NSNotification.Name("PushEventDeepLink"),
                object: nil,
                userInfo: userInfo
            )
        }
        
        completionHandler()
    }
    
    // Handle remote push notifications (if APNs configured)
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Route through DeepLinkRouter
        deepLinkRouter?.handlePushPayload(userInfo)
        completionHandler(.newData)
    }
}

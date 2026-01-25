import Foundation
import UserNotifications

/// Handles in-app notification scheduling and permissions for odds swing / closing soon / invite accept.
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}
    
    func requestPermission() async -> Bool {
        do {
            let settings = try await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                return true
            case .denied:
                return false
            case .notDetermined:
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                return granted
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }
    
    func scheduleOddsSwing(eventId: Int, title: String, delta: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Odds moved"
        content.body = "\(title): odds moved by \(delta)%"
        content.sound = .default
        content.userInfo = ["event_id": eventId]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "odds-\(eventId)-\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleClosingSoon(eventId: Int, title: String, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Closing soon"
        content.body = "\(title) closes in \(minutes)m"
        content.sound = .default
        content.userInfo = ["event_id": eventId]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "close-\(eventId)-\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleInviteAccepted(username: String) {
        let content = UNMutableNotificationContent()
        content.title = "Invite accepted"
        content.body = "\(username) joined your market"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "invite-\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}


import Foundation
import UIKit

/// Analytics manager for tracking user events to Google Analytics 4
/// Uses the GA4 Measurement Protocol to send events
final class Analytics {
    static let shared = Analytics()
    
    // Your GA4 Measurement ID
    private let measurementId = "G-0000000000"  
    
    // GA4 Measurement Protocol requires an API secret (get from GA4 Admin > Data Streams > Measurement Protocol)
    // For now, we'll track locally and you can add the API secret later
    private let apiSecret = "" // Add your API secret here
    
    private var clientId: String
    private var userId: String?
    private var sessionId: String
    private var eventQueue: [(String, [String: Any])] = []
    
    private init() {
        // Get or create a persistent client ID
        if let savedClientId = UserDefaults.standard.string(forKey: "analytics_client_id") {
            clientId = savedClientId
        } else {
            clientId = UUID().uuidString
            UserDefaults.standard.set(clientId, forKey: "analytics_client_id")
        }
        
        // Create session ID
        sessionId = String(Int(Date().timeIntervalSince1970))
    }
    
    // MARK: - Configuration
    
    /// Set the user ID after login
    func setUserId(_ id: Int?) {
        userId = id.map { String($0) }
    }
    
    /// Set user properties
    func setUserProperties(name: String?, username: String?) {
        // Store for event enrichment
        UserDefaults.standard.set(name, forKey: "analytics_user_name")
        UserDefaults.standard.set(username, forKey: "analytics_username")
    }
    
    // MARK: - Screen Tracking
    
    func trackScreenView(_ screenName: String, screenClass: String? = nil) {
        let params: [String: Any] = [
            "screen_name": screenName,
            "screen_class": screenClass ?? screenName
        ]
        trackEvent("screen_view", parameters: params)
    }
    
    // MARK: - Authentication Events
    
    func trackLogin(method: String = "email") {
        trackEvent("login", parameters: ["method": method])
    }
    
    func trackSignUp(method: String = "email") {
        trackEvent("sign_up", parameters: ["method": method])
    }
    
    func trackLogout() {
        trackEvent("logout", parameters: [:])
        userId = nil
    }
    
    // MARK: - Trading Events
    
    func trackBetPlaced(eventId: Int, side: String, amount: Int, price: Int) {
        let params: [String: Any] = [
            "event_id": eventId,
            "side": side,
            "amount": amount,
            "price": price,
            "value": Double(amount) // For revenue tracking
        ]
        trackEvent("bet_placed", parameters: params)
    }
    
    func trackBetWon(eventId: Int, payout: Int) {
        trackEvent("bet_won", parameters: [
            "event_id": eventId,
            "payout": payout
        ])
    }
    
    func trackBetLost(eventId: Int, amount: Int) {
        trackEvent("bet_lost", parameters: [
            "event_id": eventId,
            "amount": amount
        ])
    }
    
    // MARK: - Content Events
    
    func trackEventViewed(eventId: Int, eventTitle: String) {
        trackEvent("view_item", parameters: [
            "item_id": String(eventId),
            "item_name": eventTitle,
            "item_category": "event"
        ])
    }
    
    func trackMarketViewed(marketId: Int, marketName: String) {
        trackEvent("view_item", parameters: [
            "item_id": String(marketId),
            "item_name": marketName,
            "item_category": "market"
        ])
    }
    
    func trackEventCreated(eventId: Int, eventType: String) {
        trackEvent("event_created", parameters: [
            "event_id": eventId,
            "event_type": eventType
        ])
    }
    
    func trackMarketCreated(marketId: Int) {
        trackEvent("market_created", parameters: [
            "market_id": marketId
        ])
    }
    
    // MARK: - Social Events
    
    func trackGossipPosted(eventId: Int) {
        trackEvent("gossip_posted", parameters: [
            "event_id": eventId
        ])
    }
    
    func trackFriendAdded() {
        trackEvent("friend_added", parameters: [:])
    }
    
    func trackShare(contentType: String, itemId: String) {
        trackEvent("share", parameters: [
            "content_type": contentType,
            "item_id": itemId
        ])
    }
    
    // MARK: - Engagement Events
    
    func trackStreakAchieved(days: Int) {
        trackEvent("streak_achieved", parameters: [
            "streak_days": days
        ])
    }
    
    func trackAchievementUnlocked(achievementId: String, achievementName: String) {
        trackEvent("unlock_achievement", parameters: [
            "achievement_id": achievementId,
            "achievement_name": achievementName
        ])
    }
    
    func trackLevelUp(level: Int, title: String) {
        trackEvent("level_up", parameters: [
            "level": level,
            "title": title
        ])
    }
    
    func trackDailyChallengeCompleted(challengeId: String, reward: Int) {
        trackEvent("daily_challenge_completed", parameters: [
            "challenge_id": challengeId,
            "reward": reward
        ])
    }
    
    // MARK: - Core Event Tracking
    
    private func trackEvent(_ eventName: String, parameters: [String: Any]) {
        // Build the full event payload
        var enrichedParams = parameters
        enrichedParams["engagement_time_msec"] = "100"
        enrichedParams["session_id"] = sessionId
        
        // Add device info
        enrichedParams["platform"] = "ios"
        enrichedParams["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        enrichedParams["device_model"] = UIDevice.current.model
        enrichedParams["os_version"] = UIDevice.current.systemVersion
        
        // Log locally for debugging
        #if DEBUG
        print("📊 Analytics: \(eventName) - \(enrichedParams)")
        #endif
        
        // Queue for sending
        eventQueue.append((eventName, enrichedParams))
        
        // Send if we have API secret configured
        if !apiSecret.isEmpty {
            sendQueuedEvents()
        }
    }
    
    // MARK: - Network
    
    private func sendQueuedEvents() {
        guard !apiSecret.isEmpty, !eventQueue.isEmpty else { return }
        
        let eventsToSend = eventQueue
        eventQueue.removeAll()
        
        // Build payload for GA4 Measurement Protocol
        var events: [[String: Any]] = []
        for (name, params) in eventsToSend {
            events.append([
                "name": name,
                "params": params
            ])
        }
        
        let payload: [String: Any] = [
            "client_id": clientId,
            "user_id": userId as Any,
            "events": events
        ]
        
        // Send to GA4
        let urlString = "https://www.google-analytics.com/mp/collect?measurement_id=\(measurementId)&api_secret=\(apiSecret)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    print("Analytics error: \(error)")
                    // Re-queue events on failure
                    self.eventQueue.append(contentsOf: eventsToSend)
                }
            }.resume()
        } catch {
            print("Analytics JSON error: \(error)")
        }
    }
}

// MARK: - SwiftUI View Extension for Screen Tracking

import SwiftUI

extension View {
    func trackScreen(_ name: String) -> some View {
        self.onAppear {
            Analytics.shared.trackScreenView(name)
        }
    }
}


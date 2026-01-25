import Foundation

/// Central deep link router so any view can react to incoming app links.
/// Example supported links:
/// - tyches://event?id=123&side=YES
/// - https://www.tyches.us/app?event_id=123&side=YES
/// - Push notifications with event_id, side, type fields
final class DeepLinkRouter: ObservableObject {
    @Published var targetEventId: Int?
    @Published var targetSide: String?
    @Published var targetOpenChat: Bool = false
    @Published var targetMarketId: Int?
    
    // Debounce rapid changes
    private var lastClearedAt: Date?
    
    func handle(_ url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        // Accept custom scheme or universal link under /app
        guard url.scheme == "tyches" || url.host == "www.tyches.us" || url.host == "tyches.us" else { return }
        
        // If it's a universal link, ensure path hints an app route
        if url.scheme == "https", let path = url.path.lowercased().components(separatedBy: "/").last, path != "app" && path != "event.php" && path != "market.php" {
            return
        }
        
        var eventId: Int?
        var side: String?
        var openChat = false
        var marketId: Int?
        
        components?.queryItems?.forEach { item in
            switch item.name.lowercased() {
            case "id", "event_id":
                if let value = item.value, let intVal = Int(value) {
                    eventId = intVal
                }
            case "market_id":
                if let value = item.value, let intVal = Int(value) {
                    marketId = intVal
                }
            case "side", "outcome":
                if let value = item.value, !value.isEmpty {
                    side = value.uppercased()
                }
            case "chat":
                if let value = item.value {
                    openChat = value == "1" || value.lowercased() == "true"
                }
            default:
                break
            }
        }
        
        applyDeepLink(eventId: eventId, marketId: marketId, side: side, openChat: openChat)
    }
    
    /// Parse push payloads that include event id/side or mention/invite types.
    /// Supported notification types:
    /// - bet_placed: opens event card
    /// - odds_change: opens event card
    /// - mention: opens event chat
    /// - gossip: opens event chat
    /// - invite_accepted: opens event chat
    /// - resolution: opens event card
    func handlePushPayload(_ payload: [AnyHashable: Any]) {
        var eventId: Int?
        var marketId: Int?
        
        // Extract event_id from various possible keys
        if let rawId = payload["event_id"] {
            eventId = parseIntFromAny(rawId)
        } else if let aps = payload["aps"] as? [String: Any],
                  let rawId = aps["event_id"] {
            eventId = parseIntFromAny(rawId)
        } else if let data = payload["data"] as? [String: Any],
                  let rawId = data["event_id"] {
            eventId = parseIntFromAny(rawId)
        }
        
        // Extract market_id
        if let rawId = payload["market_id"] {
            marketId = parseIntFromAny(rawId)
        }
        
        // Extract side for bet actions
        let side = (payload["side"] as? String ?? payload["outcome"] as? String)?.uppercased()
        
        // Determine type to know if we should open chat
        let type = (payload["type"] as? String ?? payload["category"] as? String ?? payload["notification_type"] as? String ?? "").lowercased()
        
        // Open chat for mentions, gossip replies, and invite acceptances
        let chatTypes = ["mention", "gossip", "invite_accept", "reply", "chat"]
        let openChat = chatTypes.contains { type.contains($0) }
        
        applyDeepLink(eventId: eventId, marketId: marketId, side: side, openChat: openChat)
    }
    
    /// Route to a specific event with optional side (for bet sheet) or chat
    func routeToEvent(eventId: Int, side: String? = nil, openChat: Bool = false) {
        applyDeepLink(eventId: eventId, marketId: nil, side: side, openChat: openChat)
    }
    
    /// Route to open the bet sheet for a specific event and side
    func routeToBetSheet(eventId: Int, side: String) {
        applyDeepLink(eventId: eventId, marketId: nil, side: side, openChat: false)
    }
    
    /// Route to open chat for a specific event
    func routeToChat(eventId: Int) {
        applyDeepLink(eventId: eventId, marketId: nil, side: nil, openChat: true)
    }
    
    func clear() {
        lastClearedAt = Date()
        targetEventId = nil
        targetSide = nil
        targetOpenChat = false
        targetMarketId = nil
    }
    
    // MARK: - Private
    
    private func applyDeepLink(eventId: Int?, marketId: Int?, side: String?, openChat: Bool) {
        // Debounce: don't set values if we just cleared
        if let lastCleared = lastClearedAt, Date().timeIntervalSince(lastCleared) < 0.5 {
            return
        }
        
        guard eventId != nil || marketId != nil else { return }
        
        DispatchQueue.main.async {
            self.targetEventId = eventId
            self.targetMarketId = marketId
            self.targetSide = side
            self.targetOpenChat = openChat
        }
    }
    
    private func parseIntFromAny(_ value: Any) -> Int? {
        if let intVal = value as? Int {
            return intVal
        } else if let strVal = value as? String, let intVal = Int(strVal) {
            return intVal
        } else if let doubleVal = value as? Double {
            return Int(doubleVal)
        }
        return nil
    }
}


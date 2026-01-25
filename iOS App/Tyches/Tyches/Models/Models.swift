import Foundation

// MARK: - Core models from profile.php / markets.php / events.php / bets.php

struct User: Codable, Identifiable {
    let id: Int
    let name: String?
    let username: String?
    let email: String?
    let tokens_balance: Double?
    
    // Stats fields (may be returned by profile.php or user-stats.php)
    let bets_count: Int?
    let wins_count: Int?
    let friends_count: Int?
    let streak: Int?
    let level: Int?
    let xp: Int?
    
    // Custom decoding to handle both string and number from backend
    enum CodingKeys: String, CodingKey {
        case id, name, username, email, tokens_balance
        case bets_count, wins_count, friends_count, streak, level, xp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        
        // Handle tokens_balance as either String or Double
        if let doubleValue = try? container.decode(Double.self, forKey: .tokens_balance) {
            tokens_balance = doubleValue
        } else if let stringValue = try? container.decode(String.self, forKey: .tokens_balance),
                  let doubleValue = Double(stringValue) {
            tokens_balance = doubleValue
        } else {
            tokens_balance = nil
        }
        
        // Stats fields - handle both string and int from PHP
        bets_count = Self.decodeIntOrString(from: container, key: .bets_count)
        wins_count = Self.decodeIntOrString(from: container, key: .wins_count)
        friends_count = Self.decodeIntOrString(from: container, key: .friends_count)
        streak = Self.decodeIntOrString(from: container, key: .streak)
        level = Self.decodeIntOrString(from: container, key: .level)
        xp = Self.decodeIntOrString(from: container, key: .xp)
    }
    
    // Helper to decode int that might come as string from PHP
    private static func decodeIntOrString(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int? {
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return intValue
        } else if let stringValue = try? container.decode(String.self, forKey: key),
                  let intValue = Int(stringValue) {
            return intValue
        }
        return nil
    }
}

struct MarketSummary: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let visibility: String
    let avatar_emoji: String?
    let avatar_color: String?
    let members_count: Int?
    let events_count: Int?
    let created_at: String?
}

struct EventSummary: Codable, Identifiable {
    let id: Int
    let market_id: Int
    let market_name: String?
    let title: String
    let event_type: String
    let status: String
    let closes_at: String
    let created_at: String?
    let volume: Double
    let traders_count: Int
    let yes_percent: Int?
    let no_percent: Int?
    let yes_price: Int?
    let no_price: Int?
    let pools: PoolData?
    
    // Computed properties that use pool data when available
    // Priority: Use pool data ONLY if there are actual bets (total_pool > 0)
    // Otherwise, use the stored initial odds (yes_percent/no_percent)
    var currentYesPercent: Int {
        // Only use pool data if there are actual bets in the pool
        if let pools = pools, let totalPool = pools.total_pool, totalPool > 0 {
            if let poolPercent = pools.yes_percent { return poolPercent }
        }
        // Fall back to stored initial odds
        if let yesPercent = yes_percent { return yesPercent }
        if let yesPrice = yes_price { return yesPrice }
        // If we have no_percent, calculate yes as 100 - no
        if let noPercent = no_percent { return 100 - noPercent }
        if let noPrice = no_price { return 100 - noPrice }
        return 50
    }
    
    var currentNoPercent: Int {
        // Only use pool data if there are actual bets in the pool
        if let pools = pools, let totalPool = pools.total_pool, totalPool > 0 {
            if let poolPercent = pools.no_percent { return poolPercent }
        }
        // Fall back to stored initial odds
        if let noPercent = no_percent { return noPercent }
        if let noPrice = no_price { return noPrice }
        // If we have yes_percent, calculate no as 100 - yes
        if let yesPercent = yes_percent { return 100 - yesPercent }
        if let yesPrice = yes_price { return 100 - yesPrice }
        return 50
    }
    
    var yesOdds: Double {
        // Calculate odds from percentage if pool odds not available
        if let poolOdds = pools?.yes_odds { return poolOdds }
        let percent = currentYesPercent
        guard percent > 0 && percent < 100 else { return 2.0 }
        return 100.0 / Double(percent)
    }
    
    var noOdds: Double {
        // Calculate odds from percentage if pool odds not available
        if let poolOdds = pools?.no_odds { return poolOdds }
        let percent = currentNoPercent
        guard percent > 0 && percent < 100 else { return 2.0 }
        return 100.0 / Double(percent)
    }
    
    var totalPool: Double {
        pools?.total_pool ?? volume
    }
    
    /// Get the current percentage for a multiple-choice outcome
    /// Uses pool data if available and has bets, otherwise falls back to static probability
    func outcomePercent(for outcomeId: String) -> Int? {
        // Check if we have pool data with actual bets
        if let pools = pools, let totalPool = pools.total_pool, totalPool > 0,
           let outcomes = pools.outcomes,
           let outcome = outcomes.first(where: { $0.id == outcomeId }) {
            return outcome.percent
        }
        // No pool data - this would need outcomes from EventDetail
        return nil
    }
    
    /// Get current odds for a multiple-choice outcome
    func outcomeOdds(for outcomeId: String) -> Double? {
        if let pools = pools, let totalPool = pools.total_pool, totalPool > 0,
           let outcomes = pools.outcomes,
           let outcome = outcomes.first(where: { $0.id == outcomeId }) {
            return outcome.odds
        }
        return nil
    }
}

// Simplified bet view used on Profile screen
struct BetSummary: Codable, Identifiable {
    let id: Int
    let event_id: Int
    let event_title: String?
    let event_type: String?
    let market_name: String?
    let side: String?
    let outcome_id: String?
    let shares: Int
    let price: Int
    let notional: Double
    let created_at: String
}

// Top-level profile payload from api/profile.php
struct ProfileResponse: Codable {
    let user: User
    let friends: [FriendSummary]?
    let markets: [MarketSummary]
    let events_created: [EventSummary]
    let bets: [BetSummary]?
}

struct FriendSummary: Codable, Identifiable {
    let id: Int
    let name: String?
    let username: String?
    let status: String
    let created_at: String

    var shortStatus: String {
        switch status {
        case "accepted": return "Friend"
        case "pending":  return "Pending"
        default:         return status.capitalized
        }
    }
}

// MARK: - Market Detail (from markets.php?id=...)

struct MarketMember: Codable, Identifiable {
    let id: Int
    let name: String?
    let username: String?
    let role: String
    let created_at: String?
}

struct MarketDetailResponse: Codable {
    let market: MarketDetail
    let members: [MarketMember]
    let events: [EventSummary]
}

struct MarketDetail: Codable {
    let id: Int
    let name: String
    let description: String?
    let visibility: String
    let avatar_emoji: String?
    let avatar_color: String?
    let owner_id: Int
    let created_at: String?
    let is_owner: Bool?
    let can_invite: Bool?
    let user_role: String?
}

// MARK: - Event Detail (from events.php?id=...)

struct EventDetailResponse: Codable {
    let event: EventDetail
}

// Extended event detail with pool data
struct EventDetailWithPools: Codable {
    let event: EventDetail
    let pools: PoolData?
    let your_position: UserPosition?
}

struct EventDetail: Codable {
    let id: Int
    let market_id: Int
    let creator_id: Int
    let title: String
    let description: String?
    let event_type: String
    let status: String
    let closes_at: String
    let created_at: String?
    let yes_price: Int?
    let no_price: Int?
    let yes_percent: Int?
    let no_percent: Int?
    let outcomes: [EventOutcome]?
    let volume: Double
    let traders_count: Int
    let winning_side: String?
    let winning_outcome_id: String?
    let market_name: String?
    let market_avatar_emoji: String?
    let market_avatar_color: String?
    let creator_name: String?
    let creator_username: String?
    let is_creator: Bool?
    let is_market_owner: Bool?
    let can_invite: Bool?
    let pools: PoolData?
    let your_position: UserPosition?
    
    // Computed properties using pool data
    // Priority: Use pool data ONLY if there are actual bets (total_pool > 0)
    // Otherwise, use the stored initial odds (yes_percent/no_percent)
    var currentYesPercent: Int {
        // Only use pool data if there are actual bets in the pool
        if let pools = pools, let totalPool = pools.total_pool, totalPool > 0 {
            if let poolPercent = pools.yes_percent { return poolPercent }
        }
        // Fall back to stored initial odds
        if let yesPercent = yes_percent { return yesPercent }
        if let noPercent = no_percent { return 100 - noPercent }
        return 50
    }
    
    var currentNoPercent: Int {
        // Only use pool data if there are actual bets in the pool
        if let pools = pools, let totalPool = pools.total_pool, totalPool > 0 {
            if let poolPercent = pools.no_percent { return poolPercent }
        }
        // Fall back to stored initial odds
        if let noPercent = no_percent { return noPercent }
        if let yesPercent = yes_percent { return 100 - yesPercent }
        return 50
    }
    
    var yesOdds: Double {
        if let poolOdds = pools?.yes_odds { return poolOdds }
        let percent = currentYesPercent
        guard percent > 0 && percent < 100 else { return 2.0 }
        return 100.0 / Double(percent)
    }
    
    var noOdds: Double {
        if let poolOdds = pools?.no_odds { return poolOdds }
        let percent = currentNoPercent
        guard percent > 0 && percent < 100 else { return 2.0 }
        return 100.0 / Double(percent)
    }
    
    var totalPool: Double {
        pools?.total_pool ?? volume
    }
    
    /// Get the current percentage for a multiple-choice outcome
    /// Uses pool data if available and has bets, otherwise falls back to static probability
    func outcomePercent(for outcomeId: String) -> Int {
        // Check if we have pool data with actual bets
        if let pools = pools, let totalPool = pools.total_pool, totalPool > 0,
           let poolOutcomes = pools.outcomes,
           let poolOutcome = poolOutcomes.first(where: { $0.id == outcomeId }) {
            return poolOutcome.percent
        }
        // Fall back to static probability from outcomes
        if let outcomes = outcomes,
           let outcome = outcomes.first(where: { $0.id == outcomeId }) {
            return outcome.percent ?? outcome.probability
        }
        return 0
    }
    
    /// Get current odds for a multiple-choice outcome
    func outcomeOdds(for outcomeId: String) -> Double {
        // Check if we have pool data with actual bets
        if let pools = pools, let totalPool = pools.total_pool, totalPool > 0,
           let poolOutcomes = pools.outcomes,
           let poolOutcome = poolOutcomes.first(where: { $0.id == outcomeId }) {
            return poolOutcome.odds
        }
        // Fall back to calculated odds from probability
        if let outcomes = outcomes,
           let outcome = outcomes.first(where: { $0.id == outcomeId }) {
            if let odds = outcome.odds { return odds }
            let prob = outcome.percent ?? outcome.probability
            return prob > 0 ? 100.0 / Double(prob) : 1.0
        }
        return 1.0
    }
    
    // Custom decoding to handle type mismatches
    enum CodingKeys: String, CodingKey {
        case id, market_id, creator_id, title, description, event_type, status
        case closes_at, created_at, yes_price, no_price, yes_percent, no_percent
        case outcomes, volume, traders_count, winning_side, winning_outcome_id
        case market_name, market_avatar_emoji, market_avatar_color
        case creator_name, creator_username, is_creator, is_market_owner, can_invite
        case pools, your_position
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        market_id = try container.decode(Int.self, forKey: .market_id)
        creator_id = try container.decode(Int.self, forKey: .creator_id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        event_type = try container.decode(String.self, forKey: .event_type)
        status = try container.decode(String.self, forKey: .status)
        closes_at = try container.decode(String.self, forKey: .closes_at)
        created_at = try container.decodeIfPresent(String.self, forKey: .created_at)
        
        // Handle optional integers
        yes_price = try? container.decode(Int.self, forKey: .yes_price)
        no_price = try? container.decode(Int.self, forKey: .no_price)
        yes_percent = try? container.decode(Int.self, forKey: .yes_percent)
        no_percent = try? container.decode(Int.self, forKey: .no_percent)
        
        // Handle outcomes array
        outcomes = try? container.decodeIfPresent([EventOutcome].self, forKey: .outcomes)
        
        // Handle volume as either Double or String
        if let doubleValue = try? container.decode(Double.self, forKey: .volume) {
            volume = doubleValue
        } else if let stringValue = try? container.decode(String.self, forKey: .volume),
                  let doubleValue = Double(stringValue) {
            volume = doubleValue
        } else {
            volume = 0.0
        }
        
        // Handle traders_count as either Int or String
        if let intValue = try? container.decode(Int.self, forKey: .traders_count) {
            traders_count = intValue
        } else if let stringValue = try? container.decode(String.self, forKey: .traders_count),
                  let intValue = Int(stringValue) {
            traders_count = intValue
        } else {
            traders_count = 0
        }
        
        winning_side = try container.decodeIfPresent(String.self, forKey: .winning_side)
        winning_outcome_id = try container.decodeIfPresent(String.self, forKey: .winning_outcome_id)
        market_name = try container.decodeIfPresent(String.self, forKey: .market_name)
        market_avatar_emoji = try container.decodeIfPresent(String.self, forKey: .market_avatar_emoji)
        market_avatar_color = try container.decodeIfPresent(String.self, forKey: .market_avatar_color)
        creator_name = try container.decodeIfPresent(String.self, forKey: .creator_name)
        creator_username = try container.decodeIfPresent(String.self, forKey: .creator_username)
        is_creator = try container.decodeIfPresent(Bool.self, forKey: .is_creator)
        is_market_owner = try container.decodeIfPresent(Bool.self, forKey: .is_market_owner)
        can_invite = try container.decodeIfPresent(Bool.self, forKey: .can_invite)
        pools = try container.decodeIfPresent(PoolData.self, forKey: .pools)
        your_position = try container.decodeIfPresent(UserPosition.self, forKey: .your_position)
    }
}

struct EventOutcome: Codable, Identifiable {
    let id: String
    let label: String
    let probability: Int
    let pool: Double?
    let odds: Double?
    let percent: Int?
}

// MARK: - Pool Data (Parimutuel Betting)

struct PoolData: Codable {
    let yes_pool: Double?
    let no_pool: Double?
    let total_pool: Double?
    let yes_odds: Double?
    let no_odds: Double?
    let yes_percent: Int?
    let no_percent: Int?
    let yes_potential_return: Double?
    let no_potential_return: Double?
    let outcomes: [OutcomePool]?
    let low_liquidity: Bool?
    let liquidity_warning: String?
    
    // Custom decoder to handle type flexibility
    enum CodingKeys: String, CodingKey {
        case yes_pool, no_pool, total_pool, yes_odds, no_odds
        case yes_percent, no_percent, yes_potential_return, no_potential_return
        case outcomes, low_liquidity, liquidity_warning
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle doubles that might come as strings or ints
        yes_pool = Self.decodeFlexibleDouble(container, forKey: .yes_pool)
        no_pool = Self.decodeFlexibleDouble(container, forKey: .no_pool)
        total_pool = Self.decodeFlexibleDouble(container, forKey: .total_pool)
        yes_odds = Self.decodeFlexibleDouble(container, forKey: .yes_odds)
        no_odds = Self.decodeFlexibleDouble(container, forKey: .no_odds)
        yes_potential_return = Self.decodeFlexibleDouble(container, forKey: .yes_potential_return)
        no_potential_return = Self.decodeFlexibleDouble(container, forKey: .no_potential_return)
        
        // Handle ints that might come as strings
        yes_percent = Self.decodeFlexibleInt(container, forKey: .yes_percent)
        no_percent = Self.decodeFlexibleInt(container, forKey: .no_percent)
        
        // Standard optionals
        outcomes = try container.decodeIfPresent([OutcomePool].self, forKey: .outcomes)
        low_liquidity = try container.decodeIfPresent(Bool.self, forKey: .low_liquidity)
        liquidity_warning = try container.decodeIfPresent(String.self, forKey: .liquidity_warning)
    }
    
    private static func decodeFlexibleDouble(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Double? {
        if let value = try? container.decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return Double(value)
        }
        if let stringValue = try? container.decode(String.self, forKey: key),
           let value = Double(stringValue) {
            return value
        }
        return nil
    }
    
    private static func decodeFlexibleInt(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Int? {
        if let value = try? container.decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            return Int(value)
        }
        if let stringValue = try? container.decode(String.self, forKey: key),
           let value = Int(stringValue) {
            return value
        }
        return nil
    }
}

struct OutcomePool: Codable, Identifiable {
    let id: String
    let label: String
    let pool: Double
    let odds: Double
    let percent: Int
    let potential_return: Double
    
    // Custom decoder to handle type flexibility
    enum CodingKeys: String, CodingKey {
        case id, label, pool, odds, percent, potential_return
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // ID can be string or int
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = "unknown"
        }
        
        label = try container.decode(String.self, forKey: .label)
        
        // Handle numeric types flexibly
        if let value = try? container.decode(Double.self, forKey: .pool) {
            pool = value
        } else if let value = try? container.decode(Int.self, forKey: .pool) {
            pool = Double(value)
        } else {
            pool = 0
        }
        
        if let value = try? container.decode(Double.self, forKey: .odds) {
            odds = value
        } else if let value = try? container.decode(Int.self, forKey: .odds) {
            odds = Double(value)
        } else {
            odds = 1
        }
        
        if let value = try? container.decode(Int.self, forKey: .percent) {
            percent = value
        } else if let value = try? container.decode(Double.self, forKey: .percent) {
            percent = Int(value)
        } else {
            percent = 0
        }
        
        if let value = try? container.decode(Double.self, forKey: .potential_return) {
            potential_return = value
        } else if let value = try? container.decode(Int.self, forKey: .potential_return) {
            potential_return = Double(value)
        } else {
            potential_return = 1
        }
    }
}

struct UserPosition: Codable {
    let has_position: Bool
    let positions: [PositionDetail]?
}

struct PositionDetail: Codable {
    let side: String
    let amount: Double
    let potential_payout: Double
    let potential_profit: Double
}

// MARK: - Gossip (from gossip.php)

struct GossipResponse: Codable {
    let messages: [GossipMessage]
}

struct GossipMessage: Codable, Identifiable {
    let id: Int
    let message: String
    let created_at: String
    let user_id: Int
    let user_name: String?
    let user_username: String?
    // Client-side threaded replies (shallow)
    var reply_to_id: Int?
    var localId: String? // for optimistic send tracking
}

struct GossipPostRequest: Encodable {
    let event_id: Int
    let message: String
}

struct GossipPostResponse: Codable {
    let id: Int
    let event_id: Int
    let user_id: Int
    let message: String
    let created_at: String
}

// MARK: - Bet Placement (from bets.php - Parimutuel)

struct BetPlaceRequest: Encodable {
    let event_id: Int
    let side: String?  // "YES" or "NO" for binary
    let outcome_id: String?  // For multiple-choice
    let amount: Double  // Amount of tokens to bet
    
    // Legacy compatibility - also send as shares
    var shares: Double { amount }
}

struct BetPlaceResponse: Codable {
    let ok: Bool
    let event_id: Int
    let side: String?
    let outcome_id: String?
    let amount: Double?
    let potential_return: Double?
    let potential_profit: Double?
    let new_balance: Double?
    let odds_before: PoolData?
    let odds_after: PoolData?
    
    // Legacy fields
    let shares: Int?
    let price: Int?
    let notional: Double?
}

// MARK: - Event Activity (from event-activity.php)

struct EventActivityResponse: Codable {
    let bets: [ActivityBet]
}

struct ActivityBet: Codable, Identifiable {
    let id: Int
    let timestamp: String
    let side: String?
    let outcome_id: String?
    let shares: Int
    let price: Int
    let notional: Double
    let user_name: String?
    let user_username: String?
    let user_initial: String
}

// MARK: - Global Activity Feed (from event-activity.php without event_id)

struct GlobalActivityResponse: Codable {
    let activities: [GlobalActivityItem]
}

struct GlobalActivityItem: Codable, Identifiable {
    var id: String { "\(type)_\(event_id ?? market_id ?? 0)_\(created_at)" }
    let type: String // "bet", "event_created", "event_resolved", "member_joined"
    let user_name: String
    let description: String
    let event_id: Int?
    let market_id: Int?
    let market_name: String?
    let market_emoji: String?
    let created_at: String
}

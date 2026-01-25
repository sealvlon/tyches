import Foundation

class TychesAPI {
    static let shared = TychesAPI()
    private let baseURL = URL(string: "https://www.domain.com/api/")! // Change to your API URL
    private var csrfToken: String?
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpCookieStorage = .shared // keep PHP session cookie
        config.httpShouldSetCookies = true
        return URLSession(configuration: config)
    }()

    // Generic request helper
    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        expecting: T.Type,
        requiresCSRF: Bool = true
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add CSRF token for POST/PUT/PATCH/DELETE (except login which doesn't require it)
        if ["POST", "PUT", "PATCH", "DELETE"].contains(method) && requiresCSRF {
            if let token = csrfToken {
                request.setValue(token, forHTTPHeaderField: "X-CSRF-Token")
            } else {
                // Fetch CSRF token if we don't have it
                let tokenResponse: CSRFResponse = try await self.request("csrf.php", expecting: CSRFResponse.self, requiresCSRF: false)
                self.csrfToken = tokenResponse.csrf_token
                request.setValue(self.csrfToken, forHTTPHeaderField: "X-CSRF-Token")
            }
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if !(200...299).contains(http.statusCode) {
            // Try to decode { error: "..." } from backend
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                // If 401, it's an auth error
                if http.statusCode == 401 {
                    throw TychesError.unauthorized(apiError.error)
                }
                throw TychesError.server(apiError.error)
            }
            if http.statusCode == 401 {
                throw TychesError.unauthorized("Authentication required")
            }
            throw TychesError.httpStatus(http.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Missions / Quests
    struct MissionsResponse: Decodable {
        let missions: [Mission]
        let refreshed_at: String?
    }
    
    func fetchMissions() async throws -> MissionsResponse {
        try await request("missions.php", expecting: MissionsResponse.self)
    }
    
    struct MissionProgressResponse: Decodable {
        let mission_id: String
        let progress: Int
        let completed: Bool
    }
    
    func updateMission(id: String, increment: Int = 1) async throws -> MissionProgressResponse {
        struct MissionUpdateRequest: Encodable {
            let mission_id: String
            let increment: Int
        }
        return try await request("missions.php", method: "POST", body: MissionUpdateRequest(mission_id: id, increment: increment), expecting: MissionProgressResponse.self)
    }
    // Fetch CSRF token explicitly (call after login)
    func fetchCSRFToken() async throws {
        let response: CSRFResponse = try await request("csrf.php", expecting: CSRFResponse.self, requiresCSRF: false)
        csrfToken = response.csrf_token
    }

    // MARK: - Public API methods

    struct LoginRequest: Encodable {
        let email: String
        let password: String
    }

    struct LoginResponse: Decodable {
        let user: User
    }

    func login(email: String, password: String) async throws -> User {
        let req = LoginRequest(email: email, password: password)
        // Login doesn't require CSRF token (as per backend comments)
        let response: LoginResponse = try await request("login.php", method: "POST", body: req, expecting: LoginResponse.self, requiresCSRF: false)
        return response.user
    }
    
    // MARK: - Signup
    
    struct SignupRequest: Encodable {
        let name: String
        let username: String
        let email: String
        let password: String
        let password_confirmation: String
        let phone: String?
    }
    
    struct SignupResponse: Decodable {
        let id: Int
        let name: String
        let username: String
        let email: String
        let phone: String?
        let needs_verification: Bool
    }
    
    func signup(name: String, username: String, email: String, password: String, phone: String? = nil) async throws -> SignupResponse {
        let req = SignupRequest(
            name: name,
            username: username,
            email: email,
            password: password,
            password_confirmation: password,
            phone: phone
        )
        // Signup requires CSRF token
        return try await request("users.php", method: "POST", body: req, expecting: SignupResponse.self, requiresCSRF: true)
    }

    func fetchProfile() async throws -> ProfileResponse {
        try await request("profile.php", expecting: ProfileResponse.self)
    }
    
    // MARK: - Markets
    
    func fetchMarketDetail(id: Int) async throws -> MarketDetailResponse {
        // Construct URL with query parameter properly
        var components = URLComponents(string: baseURL.absoluteString + "markets.php")
        components?.queryItems = [URLQueryItem(name: "id", value: "\(id)")]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                if http.statusCode == 401 {
                    throw TychesError.unauthorized(apiError.error)
                }
                throw TychesError.server(apiError.error)
            }
            if http.statusCode == 401 {
                throw TychesError.unauthorized("Authentication required")
            }
            throw TychesError.httpStatus(http.statusCode)
        }
        
        return try JSONDecoder().decode(MarketDetailResponse.self, from: data)
    }

    // MARK: - Events Feed (from events.php)

    struct EventsResponse: Decodable {
        let events: [EventSummary]
    }

    func fetchEvents(filter: String? = nil) async throws -> EventsResponse {
        var components = URLComponents(string: baseURL.absoluteString + "events.php")
        if let filter = filter {
            components?.queryItems = [URLQueryItem(name: "filter", value: filter)]
        }

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if !(200...299).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                if http.statusCode == 401 {
                    throw TychesError.unauthorized(apiError.error)
                }
                throw TychesError.server(apiError.error)
            }
            if http.statusCode == 401 {
                throw TychesError.unauthorized("Authentication required")
            }
            throw TychesError.httpStatus(http.statusCode)
        }

        return try JSONDecoder().decode(EventsResponse.self, from: data)
    }

    // MARK: - Events

    func fetchEventDetail(id: Int) async throws -> EventDetailResponse {
        // Construct URL with query parameter properly
        var components = URLComponents(string: baseURL.absoluteString + "events.php")
        components?.queryItems = [URLQueryItem(name: "id", value: "\(id)")]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                if http.statusCode == 401 {
                    throw TychesError.unauthorized(apiError.error)
                }
                throw TychesError.server(apiError.error)
            }
            if http.statusCode == 401 {
                throw TychesError.unauthorized("Authentication required")
            }
            throw TychesError.httpStatus(http.statusCode)
        }
        
        return try JSONDecoder().decode(EventDetailResponse.self, from: data)
    }
    
    // MARK: - Bets
    
    func placeBet(_ bet: BetPlaceRequest) async throws -> BetPlaceResponse {
        try await request("bets.php", method: "POST", body: bet, expecting: BetPlaceResponse.self)
    }
    
    // Convenience method for placing bets with amount
    func placeBet(eventId: Int, side: String?, outcomeId: String?, amount: Double) async throws -> BetPlaceResponse {
        let bet = BetPlaceRequest(event_id: eventId, side: side, outcome_id: outcomeId, amount: amount)
        return try await placeBet(bet)
    }
    
    // MARK: - Odds
    
    struct OddsResponse: Decodable {
        let event_id: Int
        let odds: PoolData
        let your_position: UserPosition?
    }
    
    func fetchOdds(eventId: Int) async throws -> OddsResponse {
        var components = URLComponents(string: baseURL.absoluteString + "odds.php")
        components?.queryItems = [URLQueryItem(name: "event_id", value: "\(eventId)")]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw TychesError.server(apiError.error)
            }
            throw TychesError.httpStatus(http.statusCode)
        }
        
        return try JSONDecoder().decode(OddsResponse.self, from: data)
    }
    
    // MARK: - Gossip
    
    func fetchGossip(eventId: Int) async throws -> GossipResponse {
        var components = URLComponents(string: baseURL.absoluteString + "gossip.php")
        components?.queryItems = [URLQueryItem(name: "event_id", value: "\(eventId)")]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                if http.statusCode == 401 {
                    throw TychesError.unauthorized(apiError.error)
                }
                throw TychesError.server(apiError.error)
            }
            if http.statusCode == 401 {
                throw TychesError.unauthorized("Authentication required")
            }
            throw TychesError.httpStatus(http.statusCode)
        }
        
        return try JSONDecoder().decode(GossipResponse.self, from: data)
    }
    
    func postGossip(_ gossip: GossipPostRequest) async throws -> GossipPostResponse {
        try await request("gossip.php", method: "POST", body: gossip, expecting: GossipPostResponse.self)
    }
    
    // Threaded/mention variant (client-side reply_to only)
    struct GossipPostRequestThreaded: Encodable {
        let event_id: Int
        let message: String
        let reply_to_id: Int?
    }
    
    func postGossipThreaded(eventId: Int, message: String, replyTo: Int?) async throws -> GossipPostResponse {
        let body = GossipPostRequestThreaded(event_id: eventId, message: message, reply_to_id: replyTo)
        return try await request("gossip.php", method: "POST", body: body, expecting: GossipPostResponse.self)
    }
    
    // MARK: - Activity
    
    func fetchEventActivity(eventId: Int) async throws -> EventActivityResponse {
        var components = URLComponents(string: baseURL.absoluteString + "event-activity.php")
        components?.queryItems = [URLQueryItem(name: "event_id", value: "\(eventId)")]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                if http.statusCode == 401 {
                    throw TychesError.unauthorized(apiError.error)
                }
                throw TychesError.server(apiError.error)
            }
            if http.statusCode == 401 {
                throw TychesError.unauthorized("Authentication required")
            }
            throw TychesError.httpStatus(http.statusCode)
        }
        
        return try JSONDecoder().decode(EventActivityResponse.self, from: data)
    }
    
    /// Fetch global activity feed across all user's markets
    func fetchGlobalActivity(limit: Int = 30) async throws -> GlobalActivityResponse {
        var components = URLComponents(string: baseURL.absoluteString + "event-activity.php")
        components?.queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                if http.statusCode == 401 {
                    throw TychesError.unauthorized(apiError.error)
                }
                throw TychesError.server(apiError.error)
            }
            if http.statusCode == 401 {
                throw TychesError.unauthorized("Authentication required")
            }
            throw TychesError.httpStatus(http.statusCode)
        }
        
        return try JSONDecoder().decode(GlobalActivityResponse.self, from: data)
    }
    
    // MARK: - Logout
    
    struct LogoutResponse: Decodable {
        let ok: Bool
    }
    
    func logout() async throws {
        _ = try await request("logout.php", method: "POST", expecting: LogoutResponse.self)
        // Clear CSRF token on logout
        csrfToken = nil
    }
    
    // MARK: - Create Market
    
    struct CreateMarketRequest: Encodable {
        let name: String
        let description: String?
        let visibility: String
        let avatar_emoji: String?
        let avatar_color: String?
        let friend_ids: [Int]?
        let usernames: [String]?
        let invites: [String]?
    }
    
    struct CreateMarketResponse: Decodable {
        let id: Int
        let name: String
        let visibility: String
    }
    
    func createMarket(name: String, description: String? = nil, visibility: String = "private", avatarEmoji: String? = nil, avatarColor: String? = nil, friendIds: [Int]? = nil, usernames: [String]? = nil, invites: [String]? = nil) async throws -> CreateMarketResponse {
        let req = CreateMarketRequest(
            name: name,
            description: description,
            visibility: visibility,
            avatar_emoji: avatarEmoji,
            avatar_color: avatarColor,
            friend_ids: friendIds?.isEmpty == true ? nil : friendIds,
            usernames: usernames?.isEmpty == true ? nil : usernames,
            invites: invites?.isEmpty == true ? nil : invites
        )
        return try await request("markets.php", method: "POST", body: req, expecting: CreateMarketResponse.self)
    }
    
    // MARK: - Invite to Market
    
    struct InviteToMarketRequest: Encodable {
        let action: String
        let market_id: Int
        let user_ids: [Int]?
        let usernames: [String]?
        let emails: [String]?
    }
    
    struct InviteToMarketResponse: Decodable {
        let ok: Bool
        let invited: Int?
        let emails_sent: Int?
        let already_members: Int?
        let message: String?
    }
    
    func inviteToMarket(marketId: Int, friendIds: [Int]? = nil, usernames: [String]? = nil, emails: [String]? = nil) async throws -> InviteToMarketResponse {
        let req = InviteToMarketRequest(
            action: "invite",
            market_id: marketId,
            user_ids: friendIds?.isEmpty == true ? nil : friendIds,
            usernames: usernames?.isEmpty == true ? nil : usernames,
            emails: emails?.isEmpty == true ? nil : emails
        )
        return try await request("markets.php", method: "POST", body: req, expecting: InviteToMarketResponse.self)
    }
    
    // MARK: - Invite to Event
    
    struct InviteToEventRequest: Encodable {
        let action: String = "invite"
        let event_id: Int
        let user_ids: [Int]?
        let emails: [String]?
    }
    
    struct InviteToEventResponse: Decodable {
        let ok: Bool
        let invited: Int?
        let emails_sent: Int?
        let already_members: Int?
        let message: String?
    }
    
    func inviteToEvent(eventId: Int, friendIds: [Int]? = nil, emails: [String]? = nil) async throws -> InviteToEventResponse {
        let req = InviteToEventRequest(
            event_id: eventId,
            user_ids: friendIds?.isEmpty == true ? nil : friendIds,
            emails: emails?.isEmpty == true ? nil : emails
        )
        return try await request("events.php", method: "POST", body: req, expecting: InviteToEventResponse.self)
    }
    
    // MARK: - Create Event
    
    struct CreateEventRequest: Encodable {
        let market_id: Int
        let title: String
        let description: String?
        let event_type: String
        let closes_at: String
        let yes_percent: Int?  // For binary events
        let outcomes: [OutcomeData]?  // For multiple choice events
    }
    
    struct OutcomeData: Encodable {
        let label: String
        let probability: Int
    }
    
    struct CreateEventResponse: Decodable {
        let id: Int
        let title: String?
        let market_id: Int?
    }
    
    // Create binary event
    func createEvent(marketId: Int, title: String, description: String? = nil, eventType: String = "binary", closesAt: Date, initialYesPercent: Int = 50) async throws -> CreateEventResponse {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        let req = CreateEventRequest(
            market_id: marketId,
            title: title,
            description: description,
            event_type: eventType,
            closes_at: formatter.string(from: closesAt),
            yes_percent: initialYesPercent,
            outcomes: nil
        )
        return try await request("events.php", method: "POST", body: req, expecting: CreateEventResponse.self)
    }
    
    // Create multiple choice event
    func createEvent(marketId: Int, title: String, description: String? = nil, eventType: String, closesAt: Date, outcomes: [OutcomeData]) async throws -> CreateEventResponse {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        let req = CreateEventRequest(
            market_id: marketId,
            title: title,
            description: description,
            event_type: eventType,
            closes_at: formatter.string(from: closesAt),
            yes_percent: nil,
            outcomes: outcomes
        )
        return try await request("events.php", method: "POST", body: req, expecting: CreateEventResponse.self)
    }
    
    // MARK: - Streaks
    
    struct StreakResponse: Decodable {
        let current_streak: Int
        let longest_streak: Int
        let last_activity_date: String?
        let total_days_active: Int
        let weekly_activity: [Bool]
        let is_active_today: Bool
        let streak_emoji: String
        let streak_message: String
    }
    
    struct RecordActivityResponse: Decodable {
        let current_streak: Int
        let longest_streak: Int
        let is_new_day: Bool
        let xp_awarded: Int
    }
    
    func fetchStreak() async throws -> StreakResponse {
        try await request("streaks.php", expecting: StreakResponse.self)
    }
    
    func recordDailyActivity() async throws -> RecordActivityResponse {
        try await request("streaks.php", method: "POST", expecting: RecordActivityResponse.self)
    }
    
    // MARK: - Achievements
    
    struct AchievementsResponse: Decodable {
        let achievements: [AchievementData]
        let total: Int
        let unlocked: Int
        let categories: [String]
    }
    
    struct AchievementData: Decodable, Identifiable {
        let id: String
        let name: String
        let description: String
        let emoji: String
        let category: String
        let requirement: Int
        let progress: Int
        let is_unlocked: Bool
        let unlocked_at: String?
    }
    
    struct AchievementUpdateResponse: Decodable {
        let achievement_id: String
        let progress: Int
        let requirement: Int
        let is_unlocked: Bool
        let just_unlocked: Bool
    }
    
    func fetchAchievements() async throws -> AchievementsResponse {
        try await request("achievements.php", expecting: AchievementsResponse.self)
    }
    
    func updateAchievement(id: String, increment: Int = 1) async throws -> AchievementUpdateResponse {
        struct UpdateRequest: Encodable {
            let achievement_id: String
            let increment: Int
        }
        return try await request("achievements.php", method: "POST", body: UpdateRequest(achievement_id: id, increment: increment), expecting: AchievementUpdateResponse.self)
    }
    
    // MARK: - Daily Challenges
    
    struct DailyChallengesResponse: Decodable {
        let challenges: [DailyChallengeData]
        let total_challenges: Int
        let completed_count: Int
        let total_reward_earned: Int
        let resets_in: String
        let date: String
    }
    
    struct DailyChallengeData: Decodable, Identifiable {
        let id: String
        let title: String
        let description: String
        let emoji: String
        let reward: Int
        let target: Int
        let progress: Int
        let is_completed: Bool
        let completed_at: String?
    }
    
    func fetchDailyChallenges() async throws -> DailyChallengesResponse {
        try await request("daily-challenges.php", expecting: DailyChallengesResponse.self)
    }
    
    // MARK: - Leaderboard
    
    struct LeaderboardResponse: Decodable {
        let leaderboard: [LeaderboardEntryData]
        let type: String
        let scope: String
        let user_position: Int?
        let total_entries: Int
    }
    
    struct LeaderboardEntryData: Decodable, Identifiable {
        var id: Int { user_id }
        let rank: Int
        let user_id: Int
        let name: String?
        let username: String?
        let tokens_balance: Double?
        let accuracy: Double?
        let total_bets: Int?
        let wins: Int?
        let total_resolved: Int?
        
        // Computed properties for display
        var displayName: String {
            name ?? username ?? "User"
        }
        
        var score: Double {
            tokens_balance ?? 0
        }
    }
    
    func fetchLeaderboard(type: String = "tokens", scope: String = "global", marketId: Int? = nil, limit: Int = 20) async throws -> LeaderboardResponse {
        var components = URLComponents(string: baseURL.absoluteString + "leaderboard.php")
        var queryItems = [
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let marketId = marketId {
            queryItems.append(URLQueryItem(name: "market_id", value: "\(marketId)"))
        }
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw TychesError.server(apiError.error)
            }
            throw TychesError.httpStatus(http.statusCode)
        }
        
        return try JSONDecoder().decode(LeaderboardResponse.self, from: data)
    }
    
    // MARK: - Notifications
    
    struct NotificationsResponse: Decodable {
        let notifications: [NotificationData]
        let unread_count: Int
        let total_count: Int
        let page: Int
        let has_more: Bool
    }
    
    struct NotificationData: Decodable, Identifiable {
        let id: Int
        let type: String
        let title: String
        let body: String?
        let data: NotificationDataPayload?
        let is_read: Bool
        let read_at: String?
        let created_at: String
        let time_ago: String
        
        enum CodingKeys: String, CodingKey {
            case id, type, title, body, data, is_read, read_at, created_at, time_ago
            case message // API returns "message" but we want "body"
            case url // API returns "url" which we can use in data
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(Int.self, forKey: .id)
            type = try container.decode(String.self, forKey: .type)
            title = try container.decode(String.self, forKey: .title)
            
            // Handle both "body" and "message" from API (API uses "message")
            if let bodyValue = try? container.decode(String.self, forKey: .body) {
                body = bodyValue.isEmpty ? nil : bodyValue
            } else if let messageValue = try? container.decode(String.self, forKey: .message) {
                body = messageValue.isEmpty ? nil : messageValue
            } else {
                body = nil
            }
            
            // Try to decode data, or extract from URL if available
            if let decodedData = try? container.decodeIfPresent(NotificationDataPayload.self, forKey: .data) {
                data = decodedData
            } else if let url = try? container.decodeIfPresent(String.self, forKey: .url), !url.isEmpty {
                // Extract IDs from URL pattern like "market.php?id=10" or "event.php?id=5"
                var eventId: Int? = nil
                var marketId: Int? = nil
                
                if url.contains("market.php") {
                    if let range = url.range(of: "id=(\\d+)", options: .regularExpression) {
                        let idStr = String(url[range]).replacingOccurrences(of: "id=", with: "")
                        marketId = Int(idStr)
                    }
                } else if url.contains("event.php") {
                    if let range = url.range(of: "id=(\\d+)", options: .regularExpression) {
                        let idStr = String(url[range]).replacingOccurrences(of: "id=", with: "")
                        eventId = Int(idStr)
                    }
                }
                
                if eventId != nil || marketId != nil {
                    data = NotificationDataPayload(event_id: eventId, market_id: marketId, user_id: nil)
                } else {
                    data = nil
                }
            } else {
                data = nil
            }
            
            is_read = try container.decode(Bool.self, forKey: .is_read)
            read_at = try? container.decodeIfPresent(String.self, forKey: .read_at)
            created_at = try container.decode(String.self, forKey: .created_at)
            time_ago = try container.decode(String.self, forKey: .time_ago)
        }
        
        // Regular initializer for creating instances manually
        init(id: Int, type: String, title: String, body: String?, data: NotificationDataPayload?, is_read: Bool, read_at: String?, created_at: String, time_ago: String) {
            self.id = id
            self.type = type
            self.title = title
            self.body = body
            self.data = data
            self.is_read = is_read
            self.read_at = read_at
            self.created_at = created_at
            self.time_ago = time_ago
        }
    }
    
    struct NotificationDataPayload: Decodable {
        let event_id: Int?
        let market_id: Int?
        let user_id: Int?
    }
    
    struct MarkNotificationsResponse: Decodable {
        let ok: Bool
        let marked_read: Int?
        let deleted: Int?
    }
    
    func fetchNotifications(page: Int = 1, limit: Int = 20, unreadOnly: Bool = false) async throws -> NotificationsResponse {
        var components = URLComponents(string: baseURL.absoluteString + "notifications.php")
        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if unreadOnly {
            queryItems.append(URLQueryItem(name: "unread", value: "1"))
        }
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw TychesError.server(apiError.error)
            }
            throw TychesError.httpStatus(http.statusCode)
        }
        
        return try JSONDecoder().decode(NotificationsResponse.self, from: data)
    }
    
    func markNotificationsRead(ids: [Int]? = nil) async throws -> MarkNotificationsResponse {
        struct MarkRequest: Encodable {
            let action: String
            let ids: [Int]?
        }
        return try await request("notifications.php", method: "POST", body: MarkRequest(action: "mark_read", ids: ids), expecting: MarkNotificationsResponse.self)
    }
    
    // MARK: - User Stats
    
    struct UserStatsResponse: Decodable {
        let user: UserStatsUser
        let level: UserLevel
        let streak: UserStreakStats
        let trading: TradingStats
        let social: SocialStats
    }
    
    struct UserStatsUser: Decodable {
        let id: Int
        let name: String?
        let username: String?
        let tokens_balance: Double
        let created_at: String
    }
    
    struct UserLevel: Decodable {
        let current: Int
        let title: String
        let xp: Int
        let xp_for_next: Int
        let progress: Double
    }
    
    struct UserStreakStats: Decodable {
        let current: Int
        let longest: Int
        let total_days: Int
        let weekly_activity: [Bool]
    }
    
    struct TradingStats: Decodable {
        let total_bets: Int
        let total_volume: Double
        let events_bet_on: Int
        let wins: Int
        let losses: Int
        let accuracy: Double
        let realized_pnl: Double
    }
    
    struct SocialStats: Decodable {
        let markets_joined: Int
        let events_created: Int
        let friends_count: Int
        let gossip_count: Int
    }
    
    func fetchUserStats(userId: Int? = nil) async throws -> UserStatsResponse {
        var components = URLComponents(string: baseURL.absoluteString + "user-stats.php")
        if let userId = userId {
            components?.queryItems = [URLQueryItem(name: "user_id", value: "\(userId)")]
        }
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw TychesError.server(apiError.error)
            }
            throw TychesError.httpStatus(http.statusCode)
        }
        
        return try JSONDecoder().decode(UserStatsResponse.self, from: data)
    }
    
    // MARK: - Friends
    
    struct FriendsResponse: Decodable {
        let friends: [FriendData]
        let search: [FriendSearchResult]?
        
        // Computed property to get pending requests
        var pending_requests: [FriendData]? {
            friends.filter { $0.status == "pending" }
        }
    }
    
    struct FriendData: Decodable, Identifiable {
        let id: Int
        let friend_id: Int?
        let name: String?
        let username: String
        let status: String?
        let is_online: Bool?
        let last_active: String?
        let created_at: String?
    }
    
    struct FriendSearchResult: Decodable, Identifiable {
        let id: Int
        let name: String?
        let username: String?
        let email: String?
        let created_at: String?
    }
    
    struct FriendActionResponse: Decodable {
        let ok: Bool
    }
    
    func fetchFriends() async throws -> FriendsResponse {
        try await request("friends.php", expecting: FriendsResponse.self)
    }
    
    // Search for users by username or email
    func searchUsers(query: String) async throws -> [FriendSearchResult] {
        var components = URLComponents(string: baseURL.absoluteString + "friends.php")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw TychesError.server(apiError.error)
            }
            throw TychesError.httpStatus(http.statusCode)
        }
        
        let friendsResponse = try JSONDecoder().decode(FriendsResponse.self, from: data)
        return friendsResponse.search ?? []
    }
    
    // Send friend request by user ID
    func sendFriendRequest(userId: Int) async throws -> FriendActionResponse {
        struct FriendRequest: Encodable {
            let action: String
            let user_id: Int
        }
        return try await request("friends.php", method: "POST", body: FriendRequest(action: "send_request", user_id: userId), expecting: FriendActionResponse.self)
    }
    
    // Send friend request by username or email
    func sendFriendRequest(query: String) async throws -> FriendActionResponse {
        struct FriendRequest: Encodable {
            let action: String
            let query: String
        }
        return try await request("friends.php", method: "POST", body: FriendRequest(action: "send_request", query: query), expecting: FriendActionResponse.self)
    }
    
    func acceptFriendRequest(userId: Int) async throws -> FriendActionResponse {
        struct AcceptRequest: Encodable {
            let action: String
            let user_id: Int
        }
        return try await request("friends.php", method: "POST", body: AcceptRequest(action: "accept", user_id: userId), expecting: FriendActionResponse.self)
    }
    
    func declineFriendRequest(userId: Int) async throws -> FriendActionResponse {
        struct DeclineRequest: Encodable {
            let action: String
            let user_id: Int
        }
        return try await request("friends.php", method: "POST", body: DeclineRequest(action: "decline", user_id: userId), expecting: FriendActionResponse.self)
    }
    
    func removeFriend(userId: Int) async throws -> FriendActionResponse {
        struct RemoveRequest: Encodable {
            let action: String
            let user_id: Int
        }
        return try await request("friends.php", method: "POST", body: RemoveRequest(action: "unfriend", user_id: userId), expecting: FriendActionResponse.self)
    }
}

// Helpers
struct APIErrorResponse: Decodable { let error: String }
struct CSRFResponse: Decodable { let csrf_token: String }
enum TychesError: Error {
    case server(String)
    case httpStatus(Int)
    case unauthorized(String)
}

struct AnyEncodable: Encodable {
    private let encodeFn: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) {
        encodeFn = value.encode
    }
    func encode(to encoder: Encoder) throws { try encodeFn(encoder) }
}

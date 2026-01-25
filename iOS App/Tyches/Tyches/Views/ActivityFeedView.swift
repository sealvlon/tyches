import SwiftUI

// MARK: - Activity Feed View (Notifications + Social Activity)
// Clean, card-based notification center - fully API-driven

struct ActivityFeedView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var deepLink: DeepLinkRouter
    @State private var notifications: [TychesAPI.NotificationData] = []
    @State private var recentActivity: [ActivityBet] = []
    @State private var yourPositions: [BetSummary] = []
    @State private var globalActivity: [GlobalActivityItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isLoadingRecents = false
    @State private var isLoadingMore = false
    @State private var isLoadingPositions = false
    @State private var isLoadingGlobal = false
    @State private var lastUpdateTime = Date()
    @State private var liveUpdateTimer: Timer?
    
    // Pagination
    @State private var page = 1
    @State private var hasMore = true
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                        .padding(.top, 32)
                        .padding(.horizontal, 20)
                    
                    Group {
                        contentBody
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 80)
                }
            }
            .background(TychesTheme.background)
            .refreshable {
                await loadNotifications()
                await loadGlobalActivity()
            }
            .navigationTitle("")
        }
        .task {
            await loadNotifications()
            await loadGlobalActivity()
            startLiveUpdates()
        }
        .onDisappear {
            stopLiveUpdates()
        }
        .onAppear {
            // Refresh when view appears if stale
            if notifications.isEmpty && recentActivity.isEmpty && !isLoading {
                Task {
                    await loadNotifications()
                }
            }
            startLiveUpdates()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PushEventDeepLink"))) { notification in
            if let payload = notification.userInfo {
                let eventId = payload["event_id"] as? Int
                let side = (payload["side"] as? String ?? payload["outcome"] as? String)?.uppercased()
                let type = (payload["type"] as? String ?? payload["category"] as? String ?? "").lowercased()
                
                if let eventId {
                    deepLink.targetEventId = eventId
                    deepLink.targetSide = side
                    deepLink.targetOpenChat = type.contains("mention") || type.contains("invite")
                }
            }
        }
    }
    
    @ViewBuilder
    private var contentBody: some View {
        if isLoading && notifications.isEmpty && globalActivity.isEmpty && yourPositions.isEmpty {
            loadingView
        } else {
            // Your Positions section (from profile.bets)
            if isLoadingPositions || !yourPositions.isEmpty {
                yourPositionsSection
            }
            
            // Global Activity section - always show (main content)
            globalActivitySection
            
            // Notifications list
            if !notifications.isEmpty {
                notificationsList
            }
            
            // Recent Bets section (API-driven from event-activity.php)
            if isLoadingRecents || !recentActivity.isEmpty {
                recentActivitySection
            }
            
            // Load more button with proper loading state
            if hasMore {
                Button {
                    Task { await loadMoreNotifications() }
                } label: {
                    HStack(spacing: 8) {
                        if isLoadingMore {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isLoadingMore ? "Loading..." : "Load more")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(TychesTheme.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(TychesTheme.primary.opacity(0.08))
                    .cornerRadius(12)
                }
                .disabled(isLoadingMore)
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Activity")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(TychesTheme.textPrimary)
                
                Spacer()
                
                // Live indicator
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(TychesTheme.success)
                            .frame(width: 6, height: 6)
                            .opacity(0.6)
                            .scaleEffect(1.5)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: UUID())
                        
                        Circle()
                            .fill(TychesTheme.success)
                            .frame(width: 6, height: 6)
                    }
                    
                    Text("LIVE")
                        .font(.caption2.bold())
                        .foregroundColor(TychesTheme.success)
                }
            }
            
            HStack {
                if !notifications.isEmpty {
                    let unread = notifications.filter { !$0.is_read }.count
                    HStack(spacing: 6) {
                        if unread > 0 {
                            Text("\(unread)")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(TychesTheme.primary)
                                .clipShape(Capsule())
                        }
                        Text(unread > 0 ? "unread" : "All caught up!")
                            .font(.subheadline)
                            .foregroundColor(unread > 0 ? TychesTheme.textSecondary : TychesTheme.success)
                    }
                } else {
                    Text("Stay updated on bets, invites, and mentions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if notifications.contains(where: { !$0.is_read }) {
                    Button {
                        markAllRead()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle")
                            Text("Mark all read")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(TychesTheme.primary)
                    }
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { _ in
                ShimmerCard()
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(TychesTheme.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Text("🔔")
                    .font(.system(size: 40))
            }
            
            VStack(spacing: 8) {
                Text("No activity yet")
                    .font(.title3.bold())
                    .foregroundColor(TychesTheme.textPrimary)
                
                Text("Place bets, chat with friends, or create events\nto see activity here")
                    .font(.subheadline)
                    .foregroundColor(TychesTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 10) {
                NavigationLink(destination: FeedView()) {
                    Text("Browse Events")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(TychesTheme.primaryGradient)
                        .cornerRadius(12)
                }
                NavigationLink(destination: CreateEventView()) {
                    Text("Create an Event")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(TychesTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(TychesTheme.primary.opacity(0.1))
                        .cornerRadius(12)
                }
                NavigationLink(destination: CreateMarketView()) {
                    Text("Create a Market")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(TychesTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(TychesTheme.primary.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(.top, 4)
        }
        .padding(.top, 40)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Error State
    
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(TychesTheme.danger.opacity(0.1))
                    .frame(width: 90, height: 90)
                Text("😕")
                    .font(.system(size: 36))
            }
            
            Text("Couldn’t load activity")
                .font(.title3.bold())
                .foregroundColor(TychesTheme.textPrimary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(TychesTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            
            Button {
                Task { await loadNotifications() }
            } label: {
                Text("Try Again")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(TychesTheme.primaryGradient)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Your Positions Section
    
    private var yourPositionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📊 Your Positions")
                    .font(.headline)
                    .foregroundColor(TychesTheme.textPrimary)
                Spacer()
                if !yourPositions.isEmpty {
                    Text("\(yourPositions.count) events")
                        .font(.caption)
                        .foregroundColor(TychesTheme.textTertiary)
                }
            }
            
            if isLoadingPositions {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading positions...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
            } else if yourPositions.isEmpty {
                Text("No active positions")
                    .font(.subheadline)
                    .foregroundColor(TychesTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(yourPositions.prefix(10)) { position in
                        PositionCard(bet: position)
                            .onTapGesture {
                                if let eventId = position.event_id as? Int {
                                    deepLink.routeToEvent(eventId: eventId)
                                }
                            }
                    }
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Global Activity Section
    
    private var globalActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("What's Happening")
                    .font(.headline)
                    .foregroundColor(TychesTheme.textPrimary)
                Spacer()
                if !globalActivity.isEmpty {
                    Text("in your markets")
                        .font(.caption)
                        .foregroundColor(TychesTheme.textTertiary)
                }
            }
            
            if isLoadingGlobal {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading activity...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
            } else if globalActivity.isEmpty {
                VStack(spacing: 12) {
                    Text("💬")
                        .font(.system(size: 40))
                    
                    Text("No activity yet")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(TychesTheme.textPrimary)
                    
                    Text("When people in your markets place bets, create events, or leave comments, you'll see it here")
                        .font(.caption)
                        .foregroundColor(TychesTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        Task { await loadGlobalActivity() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundColor(TychesTheme.primary)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
                .background(TychesTheme.cardBackground)
                .cornerRadius(16)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(globalActivity.prefix(20)) { activity in
                        GlobalActivityCard(activity: activity)
                            .onTapGesture {
                                if let eventId = activity.event_id {
                                    deepLink.routeToEvent(eventId: eventId)
                                    HapticManager.impact(.light)
                                }
                            }
                    }
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Recent Activity Section
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Bets")
                    .font(.headline)
                    .foregroundColor(TychesTheme.textPrimary)
                Spacer()
                if !recentActivity.isEmpty {
                    Text("\(recentActivity.count) bets")
                        .font(.caption)
                        .foregroundColor(TychesTheme.textTertiary)
                }
            }
            
            if isLoadingRecents {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading recent bets...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
            } else if recentActivity.isEmpty {
                Text("No recent bets from events you follow")
                    .font(.subheadline)
                    .foregroundColor(TychesTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(recentActivity.prefix(10)) { bet in
                        RecentBetCard(bet: bet)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Notifications List
    
    private var notificationsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(notifications) { notification in
                NotificationCard(notification: notification)
                    .onTapGesture {
                        handleNotificationTap(notification)
                    }
            }
        }
    }
    
    // MARK: - Fallback Recents removed (API-driven only)
    
    // MARK: - Handle Notification Tap
    
    private func handleNotificationTap(_ notification: TychesAPI.NotificationData) {
        // Mark as read if unread
        if !notification.is_read {
            Task {
                do {
                    _ = try await TychesAPI.shared.markNotificationsRead(ids: [notification.id])
                    // Update local state
                    if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                        notifications[index] = TychesAPI.NotificationData(
                            id: notification.id,
                            type: notification.type,
                            title: notification.title,
                            body: notification.body,
                            data: notification.data,
                            is_read: true,
                            read_at: ISO8601DateFormatter().string(from: Date()),
                            created_at: notification.created_at,
                            time_ago: notification.time_ago
                        )
                    }
                } catch {
                    // Silently fail
                }
            }
        }
        
        // Navigate based on notification type/data
        HapticManager.selection()
        if let eventId = notification.data?.event_id {
            deepLink.targetOpenChat = notification.type.lowercased().contains("mention") || notification.type.lowercased().contains("invite")
            deepLink.targetEventId = eventId
            deepLink.targetSide = nil
        }
    }
    
    // MARK: - Actions
    
    private func loadNotifications() async {
        isLoading = true
        errorMessage = nil
        
        // Load in parallel
        async let notificationsTask = loadNotificationsData()
        async let positionsTask = loadYourPositions()
        
        _ = await (notificationsTask, positionsTask)
        
        isLoading = false
    }
    
    private func loadNotificationsData() async {
        do {
            let response = try await TychesAPI.shared.fetchNotifications(page: 1, limit: 20, unreadOnly: false)
            await MainActor.run {
                notifications = response.notifications
                page = 1
                hasMore = response.has_more
                errorMessage = nil // Clear any previous errors
            }
            // Load recent bets from event activity API
            await loadRecentActivity(from: response.notifications)
        } catch let TychesError.server(msg) {
            await MainActor.run {
                errorMessage = msg
            }
        } catch let TychesError.unauthorized(msg) {
            await MainActor.run {
                errorMessage = msg.isEmpty ? "Please log in to view activity" : msg
            }
        } catch let TychesError.httpStatus(code) {
            await MainActor.run {
                if code == 401 {
                    errorMessage = "Please log in to view activity"
                } else {
                    errorMessage = "Server error (code: \(code))"
                }
            }
        } catch let urlError as URLError {
            await MainActor.run {
                if urlError.code == .notConnectedToInternet {
                    errorMessage = "No internet connection"
                } else {
                    errorMessage = "Connection error. Please try again."
                }
            }
        } catch {
            await MainActor.run {
                // Don't show technical error details to user
                errorMessage = "Unable to load activity. Pull down to refresh."
            }
        }
    }
    
    private func loadYourPositions() async {
        await MainActor.run { isLoadingPositions = true }
        
        // Refresh profile to get latest bets
        await session.refreshProfile()
        
        // Group bets by event_id and keep the most recent one per event
        // (Web shows grouped positions, but we'll show unique events with latest bet)
        var positionsByEvent: [Int: BetSummary] = [:]
        
        if let bets = session.profile?.bets {
            for bet in bets {
                // Keep the most recent bet per event
                if let existing = positionsByEvent[bet.event_id] {
                    let existingDate = existing.created_at.toDate() ?? Date.distantPast
                    let betDate = bet.created_at.toDate() ?? Date.distantPast
                    if betDate > existingDate {
                        positionsByEvent[bet.event_id] = bet
                    }
                } else {
                    positionsByEvent[bet.event_id] = bet
                }
            }
        }
        
        // Sort by most recent
        let sorted = Array(positionsByEvent.values).sorted { bet1, bet2 in
            (bet1.created_at.toDate() ?? Date.distantPast) > (bet2.created_at.toDate() ?? Date.distantPast)
        }
        
        await MainActor.run {
            yourPositions = sorted
            isLoadingPositions = false
        }
    }
    
    private func loadMoreNotifications() async {
        guard !isLoadingMore && hasMore else { return }
        isLoadingMore = true
        
        let nextPage = page + 1
        do {
            let response = try await TychesAPI.shared.fetchNotifications(page: nextPage, limit: 20, unreadOnly: false)
            await MainActor.run {
                // Deduplicate by ID
                let existingIds = Set(notifications.map { $0.id })
                let newNotifications = response.notifications.filter { !existingIds.contains($0.id) }
                notifications.append(contentsOf: newNotifications)
                page = nextPage
                hasMore = response.has_more
            }
        } catch {
            // Silently fail for pagination errors
        }
        
        isLoadingMore = false
    }
    
    private func markAllRead() {
        Task {
            do {
                _ = try await TychesAPI.shared.markNotificationsRead()
                // Update local state
                for i in notifications.indices {
                    notifications[i] = TychesAPI.NotificationData(
                        id: notifications[i].id,
                        type: notifications[i].type,
                        title: notifications[i].title,
                        body: notifications[i].body,
                        data: notifications[i].data,
                        is_read: true,
                        read_at: ISO8601DateFormatter().string(from: Date()),
                        created_at: notifications[i].created_at,
                        time_ago: notifications[i].time_ago
                    )
                }
                HapticManager.notification(.success)
            } catch {
                // Handle error
            }
        }
    }
    
    /// Pulls recent bet activity for a few of the most recent events mentioned in notifications.
    /// Uses event-activity.php API endpoint.
    private func loadRecentActivity(from notifications: [TychesAPI.NotificationData]) async {
        // Extract unique event IDs from notifications; if empty, fall back to profile bets
        var eventIds = Array(Set(notifications.compactMap { $0.data?.event_id })).prefix(5)
        if eventIds.isEmpty, let profileBets = session.profile?.bets {
            eventIds = Array(Set(profileBets.prefix(10).map { $0.event_id })).prefix(5)
        }
        
        guard !eventIds.isEmpty else {
            await MainActor.run {
                recentActivity = []
                isLoadingRecents = false
            }
            return
        }
        
        await MainActor.run { isLoadingRecents = true }
        
        // Fetch activity from multiple events in parallel
        var allBets: [ActivityBet] = []
        
        await withTaskGroup(of: [ActivityBet].self) { group in
            for eventId in eventIds {
                group.addTask {
                    do {
                        let response = try await TychesAPI.shared.fetchEventActivity(eventId: eventId)
                        return Array(response.bets.prefix(5))
                    } catch {
                        return []
                    }
                }
            }
            
            for await bets in group {
                allBets.append(contentsOf: bets)
            }
        }
        
        // Sort by timestamp (most recent first) and deduplicate by bet ID
        let sortedBets = allBets
            .sorted { ($0.timestamp.toDate() ?? Date.distantPast) > ($1.timestamp.toDate() ?? Date.distantPast) }
        
        // Deduplicate by bet ID
        var seenIds = Set<Int>()
        let uniqueBets = sortedBets.filter { bet in
            if seenIds.contains(bet.id) { return false }
            seenIds.insert(bet.id)
            return true
        }
        
        await MainActor.run {
            recentActivity = Array(uniqueBets.prefix(15))
            isLoadingRecents = false
        }
    }
    
    /// Loads global activity feed from user's markets
    private func loadGlobalActivity() async {
        await MainActor.run { isLoadingGlobal = true }
        
        do {
            let response = try await TychesAPI.shared.fetchGlobalActivity(limit: 30)
            await MainActor.run {
                globalActivity = response.activities
                isLoadingGlobal = false
            }
        } catch {
            await MainActor.run {
                globalActivity = []
                isLoadingGlobal = false
            }
        }
    }
    
    // MARK: - Live Updates
    
    private func startLiveUpdates() {
        stopLiveUpdates()
        liveUpdateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task { @MainActor in
                await self.refreshSilently()
            }
        }
    }
    
    private func stopLiveUpdates() {
        liveUpdateTimer?.invalidate()
        liveUpdateTimer = nil
    }
    
    private func refreshSilently() async {
        // Only refresh if it's been more than 5 seconds since last update
        guard Date().timeIntervalSince(lastUpdateTime) > 5 else { return }
        
        do {
            let response = try await TychesAPI.shared.fetchNotifications(page: 1, limit: 20, unreadOnly: false)
            await MainActor.run {
                // Only update if there are new notifications
                if response.notifications.count != notifications.count || 
                   response.notifications.first?.id != notifications.first?.id {
                    notifications = response.notifications
                    lastUpdateTime = Date()
                    HapticManager.impact(.light) // Subtle haptic for new activity
                }
            }
        } catch {
            // Silently fail for background updates
        }
    }
}

// MARK: - Notification Card

struct NotificationCard: View {
    let notification: TychesAPI.NotificationData
    
    var icon: String {
        switch notification.type.lowercased() {
        case let t where t.contains("bet"):
            return "chart.line.uptrend.xyaxis"
        case let t where t.contains("resolution"):
            return "checkmark.seal"
        case let t where t.contains("friend"):
            return "person.2"
        case let t where t.contains("gossip"), let t where t.contains("mention"):
            return "bubble.left"
        case let t where t.contains("streak"):
            return "flame"
        case let t where t.contains("achievement"):
            return "star"
        case let t where t.contains("invite") || t.contains("member_joined") || t.contains("added"):
            return "person.badge.plus"
        case let t where t.contains("market"):
            return "person.3"
        default:
            return "bell"
        }
    }
    
    var iconColor: Color {
        switch notification.type.lowercased() {
        case let t where t.contains("bet"):
            return TychesTheme.primary
        case let t where t.contains("resolution"):
            return TychesTheme.success
        case let t where t.contains("friend"):
            return TychesTheme.secondary
        case let t where t.contains("gossip"), let t where t.contains("mention"):
            return TychesTheme.accent
        case let t where t.contains("streak"):
            return .orange
        case let t where t.contains("achievement"):
            return TychesTheme.gold
        case let t where t.contains("invite") || t.contains("member_joined") || t.contains("added"):
            return TychesTheme.primary
        case let t where t.contains("market"):
            return TychesTheme.secondary
        default:
            return TychesTheme.textSecondary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(TychesTheme.textPrimary)
                    .lineLimit(2)
                
                if let body = notification.body {
                    Text(body)
                        .font(.caption)
                        .foregroundColor(TychesTheme.textSecondary)
                        .lineLimit(2)
                }
                
                Text(notification.time_ago)
                    .font(.caption2)
                    .foregroundColor(TychesTheme.textTertiary)
            }
            
            Spacer()
            
            // Unread indicator
            if !notification.is_read {
                Circle()
                    .fill(TychesTheme.primary)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(TychesTheme.cardBackground)
        .overlay(alignment: .leading) {
            if !notification.is_read {
                Rectangle()
                    .fill(TychesTheme.primary)
                    .frame(width: 3)
                    .cornerRadius(2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Shimmer Card

struct ShimmerCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(TychesTheme.surfaceElevated)
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(TychesTheme.surfaceElevated)
                    .frame(width: 150, height: 14)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(TychesTheme.surfaceElevated)
                    .frame(width: 100, height: 10)
            }
            
            Spacer()
        }
        .padding(14)
        .background(TychesTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(isAnimating ? 0.6 : 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Position Card

struct PositionCard: View {
    let bet: BetSummary
    
    var sideColor: Color {
        if let side = bet.side {
            return side == "YES" ? TychesTheme.success : TychesTheme.danger
        }
        return TychesTheme.primary
    }
    
    var sideLabel: String {
        bet.side ?? bet.outcome_id ?? "BET"
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Side indicator
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(sideColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Text(sideLabel.prefix(1))
                    .font(.headline.bold())
                    .foregroundColor(sideColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(bet.event_title ?? "Event")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(TychesTheme.textPrimary)
                    .lineLimit(2)
                
                if let marketName = bet.market_name {
                    Text(marketName)
                        .font(.caption)
                        .foregroundColor(TychesTheme.textSecondary)
                }
                
                HStack(spacing: 8) {
                    Text("\(Int(bet.shares)) tokens")
                        .font(.caption.weight(.medium))
                        .foregroundColor(TychesTheme.textSecondary)
                    
                    Text("•")
                        .foregroundColor(TychesTheme.textTertiary)
                    
                    Text(bet.created_at.toRelativeTime())
                        .font(.caption2)
                        .foregroundColor(TychesTheme.textTertiary)
                }
            }
            
            Spacer()
            
            // Side badge
            Text(sideLabel)
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(sideColor)
                .cornerRadius(8)
        }
        .padding(14)
        .background(TychesTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Recent Bet Card

struct RecentBetCard: View {
    let bet: ActivityBet
    
    var sideColor: Color {
        (bet.side ?? "YES") == "YES" ? TychesTheme.success : TychesTheme.danger
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Side indicator
            ZStack {
                Circle()
                    .fill(sideColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: (bet.side ?? "YES") == "YES" ? "arrow.up" : "arrow.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(sideColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Use user info since we don't have event title
                Text(bet.user_name ?? bet.user_username ?? "User")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(TychesTheme.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(bet.side ?? "BET")
                        .font(.caption.bold())
                        .foregroundColor(sideColor)
                    
                    Text("•")
                        .foregroundColor(TychesTheme.textTertiary)
                    
                    Text("\(Int(bet.notional)) tokens")
                        .font(.caption)
                        .foregroundColor(TychesTheme.textSecondary)
                }
                
                Text(bet.timestamp.toRelativeTime())
                    .font(.caption2)
                    .foregroundColor(TychesTheme.textTertiary)
            }
            
            Spacer()
        }
        .padding(14)
        .background(TychesTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Global Activity Card

struct GlobalActivityCard: View {
    let activity: GlobalActivityItem
    
    var activityColor: Color {
        switch activity.type {
        case "bet": return TychesTheme.primary
        case "event_created": return TychesTheme.secondary
        case "event_resolved": return TychesTheme.gold
        case "member_joined": return TychesTheme.success
        case "gossip": return TychesTheme.accent
        default: return TychesTheme.textSecondary
        }
    }
    
    var activityEmoji: String {
        switch activity.type {
        case "bet": return "📈"
        case "event_created": return "✨"
        case "event_resolved": return "🏆"
        case "member_joined": return "👋"
        case "gossip": return "💬"
        default: return "📌"
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Activity icon
            ZStack {
                Circle()
                    .fill(activityColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Text(activityEmoji)
                    .font(.title3)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(activity.user_name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(TychesTheme.textPrimary)
                    
                    // Activity type label
                    Text(activityLabel)
                        .font(.caption)
                        .foregroundColor(TychesTheme.textSecondary)
                }
                
                Text(activity.description)
                    .font(.subheadline)
                    .foregroundColor(activity.type == "gossip" ? TychesTheme.textPrimary : TychesTheme.textSecondary)
                    .lineLimit(activity.type == "gossip" ? 3 : 2)
                    .italic(activity.type == "gossip")
                
                HStack(spacing: 8) {
                    if let marketName = activity.market_name {
                        HStack(spacing: 4) {
                            if let emoji = activity.market_emoji {
                                Text(emoji)
                                    .font(.caption2)
                            }
                            Text(marketName)
                                .font(.caption)
                                .foregroundColor(TychesTheme.textTertiary)
                        }
                        
                        Text("•")
                            .foregroundColor(TychesTheme.textTertiary)
                    }
                    
                    Text(activity.created_at.toRelativeTime())
                        .font(.caption2)
                        .foregroundColor(TychesTheme.textTertiary)
                }
            }
            
            Spacer()
            
            // Navigation indicator
            if activity.event_id != nil {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(TychesTheme.textTertiary)
            }
        }
        .padding(14)
        .background(TychesTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    var activityLabel: String {
        switch activity.type {
        case "bet": return "placed a bet"
        case "event_created": return "created an event"
        case "event_resolved": return "resolved an event"
        case "member_joined": return "joined"
        case "gossip": return "commented"
        default: return ""
        }
    }
}

#Preview {
    ActivityFeedView()
        .environmentObject(SessionStore())
        .environmentObject(DeepLinkRouter())
}


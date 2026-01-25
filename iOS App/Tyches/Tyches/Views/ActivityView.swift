import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var deepLink: DeepLinkRouter
    @StateObject private var gamification = GamificationManager.shared
    @State private var activityItems: [ActivityItem] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var selectedTab = 0
    @State private var showAchievements = false
    @State private var showNotifications = false
    @State private var unreadNotifications = 0
    
    let tabs = ["All", "Bets", "Social"]
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    // Stats header
                    statsHeader
                    
                    // Tab selector
                    tabSelector
                    
                    // Activity feed
                    LazyVStack(spacing: 0) {
                        if isLoading {
                            loadingState
                        } else if let error = loadError {
                            errorState(error)
                        } else if filteredItems.isEmpty {
                            emptyState
                        } else {
                            ForEach(groupedActivities.keys.sorted(by: >), id: \.self) { date in
                                ActivitySection(date: date, items: groupedActivities[date] ?? [])
                                    .environmentObject(deepLink)
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(TychesTheme.background)
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showNotifications = true
                        HapticManager.impact(.light)
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.title3)
                                .foregroundColor(TychesTheme.primary)
                            
                            if unreadNotifications > 0 {
                                Text("\(min(unreadNotifications, 99))")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(TychesTheme.danger)
                                    .clipShape(Capsule())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAchievements = true
                        HapticManager.impact(.light)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                            Text("\(unlockedAchievements)")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(TychesTheme.gold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(TychesTheme.gold.opacity(0.15))
                        .cornerRadius(20)
                    }
                }
            }
            .refreshable {
                await session.refreshProfile()
                await loadActivity()
                await loadNotificationCount()
            }
            .task {
                await loadActivity()
                await loadNotificationCount()
            }
            .onAppear {
                Analytics.shared.trackScreenView("Activity")
            }
            .sheet(isPresented: $showAchievements) {
                AchievementsView()
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
            }
        }
    }
    
    private var unlockedAchievements: Int {
        gamification.achievements.filter { $0.isUnlocked }.count
    }
    
    private var filteredItems: [ActivityItem] {
        switch selectedTab {
        case 1: return activityItems.filter { $0.type == .bet || $0.type == .resolved }
        case 2: return activityItems.filter { $0.type == .gossip || $0.type == .newEvent || $0.type == .invite }
        default: return activityItems
        }
    }
    
    private var groupedActivities: [String: [ActivityItem]] {
        Dictionary(grouping: filteredItems) { item in
            item.dateGroup
        }
    }
    
    // MARK: - Stats Header
    
    private var statsHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatCard(
                    icon: "🔥",
                    value: "\(gamification.streak.currentStreak)",
                    label: "Day Streak",
                    color: .orange
                )
                
                StatCard(
                    icon: "🎯",
                    value: "\(session.profile?.bets?.count ?? 0)",
                    label: "Total Bets",
                    color: TychesTheme.primary
                )
                
                StatCard(
                    icon: "✨",
                    value: "\(session.profile?.events_created.count ?? 0)",
                    label: "Events",
                    color: TychesTheme.secondary
                )
                
                StatCard(
                    icon: "🏆",
                    value: "\(unlockedAchievements)",
                    label: "Achievements",
                    color: TychesTheme.gold
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = index
                        HapticManager.selection()
                    }
                } label: {
                    Text(tab)
                        .font(.subheadline.weight(selectedTab == index ? .semibold : .regular))
                        .foregroundColor(selectedTab == index ? TychesTheme.primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedTab == index ?
                            TychesTheme.primary.opacity(0.1) :
                            Color.clear
                        )
                        .cornerRadius(10)
                }
            }
        }
        .padding(4)
        .background(TychesTheme.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading activity...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Error State
    
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text("⚠️")
                .font(.system(size: 60))
            
            Text("Couldn't load activity")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                Task { await loadActivity() }
            } label: {
                Text("Try Again")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(TychesTheme.primary)
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("📭")
                .font(.system(size: 60))
            
            Text("No activity yet")
                .font(.headline)
            
            Text("Activity from your markets will appear here - bets, new events, and more!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Load Activity
    
    private func loadActivity() async {
        isLoading = true
        loadError = nil
        
        do {
            // Fetch global activity from API
            let response = try await TychesAPI.shared.fetchGlobalActivity(limit: 50)
            
            var items: [ActivityItem] = []
            
            for activity in response.activities {
                let type: ActivityType
                let emoji: String
                let accentColor: Color
                
                switch activity.type {
                case "bet":
                    type = .bet
                    emoji = "📈"
                    accentColor = TychesTheme.primary
                case "event_created":
                    type = .newEvent
                    emoji = "✨"
                    accentColor = TychesTheme.secondary
                case "event_resolved":
                    type = .resolved
                    emoji = "🏆"
                    accentColor = TychesTheme.gold
                case "member_joined":
                    type = .invite
                    emoji = "👋"
                    accentColor = TychesTheme.success
                default:
                    type = .gossip
                    emoji = "💬"
                    accentColor = TychesTheme.accent
                }
                
                items.append(ActivityItem(
                    id: items.count,
                    type: type,
                    title: activity.user_name,
                    subtitle: activity.description,
                    meta: activity.market_name ?? "",
                    emoji: activity.market_emoji ?? emoji,
                    timestamp: parseDate(activity.created_at),
                    accentColor: accentColor,
                    eventId: activity.event_id
                ))
            }
            
            // Also add own recent bets from profile
            if let bets = session.profile?.bets {
                for bet in bets.prefix(10) {
                    let action = bet.side == "YES" ? "bet YES" : (bet.side == "NO" ? "bet NO" : "placed a bet")
                    items.append(ActivityItem(
                        id: bet.id + 100000,
                        type: .bet,
                        title: "You",
                        subtitle: "\(action) on \(bet.event_title ?? "an event")",
                        meta: "\(bet.shares) tokens",
                        emoji: bet.side == "YES" ? "📈" : "📉",
                        timestamp: parseDate(bet.created_at),
                        accentColor: bet.side == "YES" ? TychesTheme.success : TychesTheme.danger,
                        eventId: bet.event_id
                    ))
                }
            }
            
            // Sort by date
            activityItems = items.sorted { $0.timestamp > $1.timestamp }
            isLoading = false
            
        } catch {
            loadError = error.localizedDescription
            isLoading = false
            
            // Fall back to profile data
            fallbackToProfileData()
        }
    }
    
    private func fallbackToProfileData() {
        var items: [ActivityItem] = []
        
        // Add bets from profile
        if let bets = session.profile?.bets {
            for bet in bets.prefix(30) {
                let action = bet.side == "YES" ? "bet YES" : (bet.side == "NO" ? "bet NO" : "placed a bet")
                items.append(ActivityItem(
                    id: bet.id,
                    type: .bet,
                    title: "You",
                    subtitle: "\(action) on \(bet.event_title ?? "an event")",
                    meta: "\(bet.shares) tokens @ \(bet.price)¢",
                    emoji: bet.side == "YES" ? "📈" : "📉",
                    timestamp: parseDate(bet.created_at),
                    accentColor: bet.side == "YES" ? TychesTheme.success : TychesTheme.danger,
                    eventId: bet.event_id
                ))
            }
        }
        
        // Add events created
        if let events = session.profile?.events_created {
            for event in events.prefix(15) {
                items.append(ActivityItem(
                    id: event.id + 10000,
                    type: .newEvent,
                    title: "You",
                    subtitle: "created \"\(event.title)\"",
                    meta: "\(event.traders_count) traders · \(Int(event.volume)) volume",
                    emoji: "✨",
                    timestamp: parseDate(event.created_at ?? ""),
                    accentColor: TychesTheme.secondary,
                    eventId: event.id
                ))
            }
        }
        
        activityItems = items.sorted { $0.timestamp > $1.timestamp }
        
        // Clear error if we have fallback data
        if !items.isEmpty {
            loadError = nil
        }
    }
    
    private func parseDate(_ dateString: String) -> Date {
        // Try multiple date formats
        let formatters: [DateFormatter] = {
            var list: [DateFormatter] = []
            
            // ISO8601 with timezone
            let iso = DateFormatter()
            iso.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            list.append(iso)
            
            // MySQL datetime
            let mysql = DateFormatter()
            mysql.dateFormat = "yyyy-MM-dd HH:mm:ss"
            list.append(mysql)
            
            return list
        }()
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        // Try ISO8601DateFormatter as fallback
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        return Date()
    }
    
    private func loadNotificationCount() async {
        do {
            let response = try await TychesAPI.shared.fetchNotifications(limit: 1)
            unreadNotifications = response.unread_count
        } catch {
            // Ignore errors
        }
    }
}

// MARK: - Activity Item Model

struct ActivityItem: Identifiable {
    let id: Int
    let type: ActivityType
    let title: String
    let subtitle: String
    let meta: String
    let emoji: String
    let timestamp: Date
    let accentColor: Color
    let eventId: Int?
    
    init(id: Int, type: ActivityType, title: String, subtitle: String, meta: String, emoji: String, timestamp: Date, accentColor: Color, eventId: Int? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.meta = meta
        self.emoji = emoji
        self.timestamp = timestamp
        self.accentColor = accentColor
        self.eventId = eventId
    }
    
    var dateGroup: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(timestamp) {
            return "Today"
        } else if calendar.isDateInYesterday(timestamp) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: timestamp)
        }
    }
    
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

enum ActivityType {
    case bet
    case gossip
    case newEvent
    case resolved
    case invite
}

// MARK: - Activity Section

struct ActivitySection: View {
    let date: String
    let items: [ActivityItem]
    @EnvironmentObject var deepLink: DeepLinkRouter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(date)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.top, 8)
            
            ForEach(items) { item in
                ActivityRow(item: item)
                    .environmentObject(deepLink)
            }
        }
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let item: ActivityItem
    @EnvironmentObject var deepLink: DeepLinkRouter
    @State private var isAppeared = false
    
    var body: some View {
        Button {
            if let eventId = item.eventId {
                deepLink.routeToEvent(eventId: eventId)
                HapticManager.impact(.light)
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                // Emoji badge
                ZStack {
                    Circle()
                        .fill(item.accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Text(item.emoji)
                        .font(.title3)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(TychesTheme.textPrimary)
                    
                    Text(item.subtitle)
                        .font(.body.weight(.medium))
                        .foregroundColor(TychesTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        if !item.meta.isEmpty {
                            Text(item.meta)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .foregroundColor(.secondary)
                        }
                        
                        Text(item.relativeTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Navigation indicator
                if item.eventId != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(TychesTheme.textTertiary)
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .opacity(isAppeared ? 1 : 0)
        .offset(x: isAppeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isAppeared = true
            }
        }
    }
}

// MARK: - Achievements View

struct AchievementsView: View {
    @ObservedObject private var gamification = GamificationManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedCategory: AchievementCategory? = nil
    @State private var isLoading = false
    
    var filteredAchievements: [Achievement] {
        if let category = selectedCategory {
            return gamification.achievements.filter { $0.category == category }
        }
        return gamification.achievements
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary
                    achievementSummary
                    
                    // Category filters
                    categoryFilters
                    
                    // Achievement grid
                    if filteredAchievements.isEmpty {
                        VStack(spacing: 16) {
                            Text("🎯")
                                .font(.system(size: 50))
                            Text("No achievements in this category")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(filteredAchievements) { achievement in
                                AchievementCard(achievement: achievement)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Syncing progress...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
                .padding(.vertical)
            }
            .background(TychesTheme.background)
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            isLoading = true
                            await gamification.syncWithBackend()
                            isLoading = false
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .refreshable {
                await gamification.syncWithBackend()
            }
        }
        .task {
            isLoading = true
            await gamification.syncWithBackend()
            isLoading = false
        }
    }
    
    private var achievementSummary: some View {
        let unlocked = gamification.achievements.filter { $0.isUnlocked }.count
        let total = gamification.achievements.count
        
        return VStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("🏆")
                    .font(.system(size: 50))
                VStack(alignment: .leading) {
                    Text("\(unlocked)/\(total)")
                        .font(.title.bold())
                    Text("Achievements Unlocked")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 10)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(TychesTheme.gold)
                        .frame(width: geo.size.width * (Double(unlocked) / Double(total)), height: 10)
                }
            }
            .frame(height: 10)
        }
        .padding()
        .background(TychesTheme.cardBackground)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                    HapticManager.selection()
                }
                
                ForEach(AchievementCategory.allCases, id: \.self) { category in
                    CategoryChip(title: category.rawValue, isSelected: selectedCategory == category) {
                        selectedCategory = category
                        HapticManager.selection()
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ?
                    TychesTheme.primaryGradient :
                    LinearGradient(colors: [TychesTheme.cardBackground], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(20)
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    @State private var isAppeared = false
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ?
                          TychesTheme.gold :
                          Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Text(achievement.emoji)
                    .font(.system(size: 30))
                    .grayscale(achievement.isUnlocked ? 0 : 1)
                    .opacity(achievement.isUnlocked ? 1 : 0.5)
            }
            .shadow(color: achievement.isUnlocked ? TychesTheme.gold.opacity(0.4) : .clear, radius: 10)
            
            Text(achievement.name)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(1)
            
            Text(achievement.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            if !achievement.isUnlocked {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(TychesTheme.primaryGradient)
                            .frame(width: geo.size.width * achievement.progressPercent, height: 4)
                    }
                }
                .frame(height: 4)
                
                Text("\(achievement.progress)/\(achievement.requirement)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("✓ Unlocked")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(TychesTheme.success)
            }
        }
        .padding()
        .background(TychesTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            achievement.isUnlocked ?
            RoundedRectangle(cornerRadius: 16)
                .stroke(TychesTheme.gold.opacity(0.5), lineWidth: 2)
            : nil
        )
        .scaleEffect(isAppeared ? 1 : 0.8)
        .opacity(isAppeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isAppeared = true
            }
        }
    }
}

import SwiftUI

// MARK: - Profile Dashboard (Reimagined)
// Clean stats dashboard with gamification

struct ProfileDashboard: View {
    @EnvironmentObject var session: SessionStore
    @State private var userStats: TychesAPI.UserStatsResponse?
    @State private var isLoading = true
    @State private var showSettings = false
    @State private var showFriends = false
    @State private var showAchievements = false
    @State private var showLeaderboard = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with avatar
                    profileHeader
                        .padding(.top, 60)
                    
                    // Token balance card
                    tokenCard
                    
                    // Level progress
                    levelProgress
                    
                    // Stats grid
                    statsGrid
                    
                    // Streak card
                    streakCard
                    
                    // Quick actions
                    quickActions
                    
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 20)
            }
            .background(TychesTheme.background)
            .refreshable {
                await refreshData()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(session)
            }
            .sheet(isPresented: $showFriends) {
                FriendsView()
                    .environmentObject(session)
            }
            .sheet(isPresented: $showAchievements) {
                AchievementsView()
            }
            .sheet(isPresented: $showLeaderboard) {
                LeaderboardView()
                    .environmentObject(session)
            }
        }
        .task {
            await loadStats()
        }
    }
    
    // MARK: - Refresh
    
    private func refreshData() async {
        await session.refreshProfile()
        await loadStats()
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(TychesTheme.primaryGradient)
                    .frame(width: 72, height: 72)
                
                Text(avatarInitial)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(TychesTheme.textPrimary)
                
                // Level badge
                ZStack {
                    Circle()
                        .fill(TychesTheme.gold)
                        .frame(width: 24, height: 24)
                    
                    Text("\(currentLevel)")
                        .font(.caption2.bold())
                        .foregroundColor(.black)
                }
                .offset(x: 26, y: 26)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.profile?.user.name ?? "User")
                    .font(.title2.bold())
                    .foregroundColor(TychesTheme.textPrimary)
                
                if let username = session.profile?.user.username {
                    Text("@\(username)")
                        .font(.subheadline)
                        .foregroundColor(TychesTheme.textSecondary)
                }
                
                // Level title
                Text(levelTitle)
                    .font(.caption.bold())
                    .foregroundColor(TychesTheme.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(TychesTheme.gold.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            // Settings button
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(TychesTheme.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(TychesTheme.surfaceElevated)
                    .clipShape(Circle())
            }
        }
    }
    
    private var avatarInitial: String {
        String((session.profile?.user.name ?? session.profile?.user.username ?? "U").prefix(1)).uppercased()
    }
    
    // MARK: - Token Card
    
    private var tokenCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Balance")
                    .font(.subheadline)
                    .foregroundColor(TychesTheme.textSecondary)
                
                Spacer()
                
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(TychesTheme.gold)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int(session.profile?.user.tokens_balance ?? 0))")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(TychesTheme.textPrimary)
                
                Text("tokens")
                    .font(.headline)
                    .foregroundColor(TychesTheme.textSecondary)
                
                Spacer()
            }
            
            // Token sources hint
            HStack(spacing: 16) {
                TokenSourceBadge(emoji: "🎯", text: "5k/event", color: TychesTheme.success)
                TokenSourceBadge(emoji: "📮", text: "2k/invite", color: TychesTheme.primary)
                TokenSourceBadge(emoji: "🏆", text: "Win bets", color: TychesTheme.gold)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [TychesTheme.cardBackground, TychesTheme.surfaceElevated],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(TychesTheme.gold.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Level Progress
    
    private var levelProgress: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Level \(currentLevel)")
                    .font(.headline)
                    .foregroundColor(TychesTheme.textPrimary)
                
                Spacer()
                
                Text("\(currentXP) / \(xpForNext) XP")
                    .font(.caption)
                    .foregroundColor(TychesTheme.textSecondary)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(TychesTheme.surfaceElevated)
                    
                    let progress = xpForNext > 0 ? CGFloat(currentXP) / CGFloat(xpForNext) : 0
                    RoundedRectangle(cornerRadius: 6)
                        .fill(TychesTheme.premiumGradient)
                        .frame(width: geo.size.width * min(progress, 1.0))
                }
            }
            .frame(height: 12)
        }
        .padding(16)
        .background(TychesTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                icon: "chart.bar.fill",
                value: "\(totalBetsCount)",
                label: "Total Bets",
                color: TychesTheme.primary
            )
            
            StatCard(
                icon: "trophy.fill",
                value: "\(winsCount)",
                label: "Wins",
                color: TychesTheme.success
            )
            
            StatCard(
                icon: "percent",
                value: "\(accuracyPercent)%",
                label: "Accuracy",
                color: TychesTheme.secondary
            )
            
            StatCard(
                icon: "person.2.fill",
                value: "\(friendsCount)",
                label: "Friends",
                color: TychesTheme.accent
            )
        }
    }
    
    // MARK: - Streak Card
    
    private var streakCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("🔥")
                            .font(.title)
                        Text("\(currentStreak) day streak")
                            .font(.headline)
                            .foregroundColor(TychesTheme.textPrimary)
                    }
                    
                    Text("Longest: \(userStats?.streak.longest ?? currentStreak) days")
                        .font(.caption)
                        .foregroundColor(TychesTheme.textSecondary)
                }
                
                Spacer()
            }
            
            // Weekly activity
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    let days = ["M", "T", "W", "T", "F", "S", "S"]
                    let weeklyActivity = userStats?.streak.weekly_activity ?? []
                    let isActive = weeklyActivity.indices.contains(index) && weeklyActivity[index]
                    
                    VStack(spacing: 4) {
                        Circle()
                            .fill(isActive ? TychesTheme.success : TychesTheme.surfaceElevated)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: isActive ? "checkmark" : "")
                                    .font(.caption.bold())
                                    .foregroundColor(TychesTheme.textPrimary)
                            )
                        
                        Text(days[index])
                            .font(.caption2)
                            .foregroundColor(TychesTheme.textTertiary)
                    }
                }
            }
        }
        .padding(20)
        .background(TychesTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Quick Actions
    
    private var quickActions: some View {
        VStack(spacing: 12) {
            QuickActionRow(icon: "person.2.fill", title: "Friends", subtitle: "\(friendsCount) friends") {
                showFriends = true
            }
            
            QuickActionRow(icon: "star.fill", title: "Achievements", subtitle: "View your progress") {
                showAchievements = true
            }
            
            QuickActionRow(icon: "chart.line.uptrend.xyaxis", title: "Leaderboard", subtitle: "See rankings") {
                showLeaderboard = true
            }
        }
    }
    
    // MARK: - Load Stats
    
    private func loadStats() async {
        do {
            userStats = try await TychesAPI.shared.fetchUserStats()
        } catch {
            // If stats API fails, create fallback stats from profile
            // This ensures users always see some data
            print("Failed to load user stats: \(error)")
        }
        isLoading = false
    }
    
    // Fallback values from session profile when API stats aren't available
    private var totalBetsCount: Int {
        if let apiCount = userStats?.trading.total_bets {
            return apiCount
        }
        if let userCount = session.profile?.user.bets_count {
            return userCount
        }
        // Calculate from bets array
        return session.profile?.bets?.count ?? 0
    }
    
    private var winsCount: Int {
        if let apiWins = userStats?.trading.wins {
            return apiWins
        }
        if let userWins = session.profile?.user.wins_count {
            return userWins
        }
        // Count won bets from bets array (bets with positive payout)
        return 0 // Can't determine from BetSummary
    }
    
    private var accuracyPercent: Int {
        if let accuracy = userStats?.trading.accuracy {
            return Int(accuracy)
        }
        // Calculate from profile if available
        let bets = session.profile?.user.bets_count ?? totalBetsCount
        let wins = session.profile?.user.wins_count ?? winsCount
        if bets > 0 {
            return Int((Double(wins) / Double(bets)) * 100)
        }
        return 0
    }
    
    private var friendsCount: Int {
        if let apiCount = userStats?.social.friends_count {
            return apiCount
        }
        if let userCount = session.profile?.user.friends_count {
            return userCount
        }
        // Count from friends array
        return session.profile?.friends?.filter { $0.status == "accepted" }.count ?? 0
    }
    
    private var currentStreak: Int {
        userStats?.streak.current ?? session.profile?.user.streak ?? 0
    }
    
    private var currentLevel: Int {
        userStats?.level.current ?? session.profile?.user.level ?? 1
    }
    
    private var currentXP: Int {
        userStats?.level.xp ?? session.profile?.user.xp ?? 0
    }
    
    private var xpForNext: Int {
        userStats?.level.xp_for_next ?? 1000
    }
    
    private var levelTitle: String {
        userStats?.level.title ?? getLevelTitle(currentLevel)
    }
    
    private func getLevelTitle(_ level: Int) -> String {
        switch level {
        case 1: return "Rookie"
        case 2...5: return "Apprentice"
        case 6...10: return "Trader"
        case 11...20: return "Expert"
        case 21...50: return "Master"
        default: return "Legend"
        }
    }
}

// MARK: - Token Source Badge

struct TokenSourceBadge: View {
    let emoji: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(emoji)
                .font(.caption)
            Text(text)
                .font(.caption2)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(TychesTheme.textPrimary)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(TychesTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(TychesTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Quick Action Row

struct QuickActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
            HapticManager.selection()
        }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(TychesTheme.primary)
                    .frame(width: 44, height: 44)
                    .background(TychesTheme.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(TychesTheme.textPrimary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(TychesTheme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(TychesTheme.textTertiary)
            }
            .padding(14)
            .background(TychesTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableStyle())
    }
}

#Preview {
    ProfileDashboard()
        .environmentObject(SessionStore())
}


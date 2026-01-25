import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var gamification = GamificationManager.shared
    @State private var showLogoutAlert = false
    @State private var showSettings = false
    @State private var showFriends = false
    @State private var selectedSection = 0
    @State private var userStats: TychesAPI.UserStatsResponse?
    @State private var isLoadingStats = true

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    profileHeader
                    levelProgress
                    statsGrid
                    
                    Picker("Section", selection: $selectedSection) {
                        Text("Positions").tag(0)
                        Text("Friends").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if selectedSection == 0 {
                        activePositionsSection
                    } else {
                        friendsSection
                    }
                }
                .padding(.bottom, 100)
            }
            .refreshable {
                await refreshData()
            }
            .background(TychesTheme.background)
            .onAppear {
                Analytics.shared.trackScreenView("Profile")
            }
            .task {
                await loadUserStats()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        
                        Button {
                            shareProfile()
                        } label: {
                            Label("Share Profile", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: {
                            showLogoutAlert = true
                        }) {
                            Label("Log Out", systemImage: "arrow.right.square")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(TychesTheme.primary)
                    }
                }
            }
            .alert("Log Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Log Out", role: .destructive) {
                    HapticManager.notification(.warning)
                    Task {
                        await session.logout()
                    }
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showFriends) {
                FriendsView()
            }
        }
    }
    
    private func loadUserStats() async {
        do {
            userStats = try await TychesAPI.shared.fetchUserStats()
        } catch {
            // Fall back to profile data
        }
        isLoadingStats = false
    }
    
    private func refreshData() async {
        async let profile: () = session.refreshProfile()
        async let stats: () = loadUserStats()
        _ = await (profile, stats)
    }
    
    private func shareProfile() {
        guard let username = session.profile?.user.username else { return }
        let url = URL(string: "https://www.tyches.us/profile/\(username)")!
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        HapticManager.impact(.light)
    }

    // MARK: - Profile Header
    
    private var profileHeader: some View {
        let user = session.profile?.user
        
        return VStack(spacing: 16) {
            // Avatar with level ring
            ZStack {
                // Progress ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: gamification.xpProgress)
                    .stroke(TychesTheme.primaryGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                
                // Avatar
                Circle()
                    .fill(TychesTheme.premiumGradient)
                    .frame(width: 88, height: 88)
                    .overlay(
                        Text(initials(for: user))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: TychesTheme.primary.opacity(0.4), radius: 10)
                
                // Level badge
                ZStack {
                    Circle()
                        .fill(TychesTheme.gold)
                        .frame(width: 28, height: 28)
                    
                    Text("\(gamification.level)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
                .offset(x: 38, y: 38)
            }
            
            // Name and username
            VStack(spacing: 4) {
                Text(user?.name ?? user?.username ?? "User")
                    .font(.title2.bold())
                
                if let username = user?.username {
                    Text("@\(username)")
                        .font(.subheadline)
                        .foregroundColor(TychesTheme.primary)
                }
                
                // Level title
                Text(gamification.levelTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top)
    }
    
    // MARK: - Level Progress
    
    private var levelProgress: some View {
        let level = userStats?.level
        let currentLevel = level?.current ?? gamification.level
        let xp = level?.xp ?? gamification.xp
        let xpForNext = level?.xp_for_next ?? gamification.xpForNextLevel
        let progress = level?.progress ?? gamification.xpProgress
        let title = level?.title ?? gamification.levelTitle
        
        return VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level \(currentLevel)")
                        .font(.subheadline.weight(.semibold))
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(xp)/\(xpForNext) XP")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(TychesTheme.premiumGradient)
                        .frame(width: geo.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(TychesTheme.cardBackground)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        let tokens = Int(session.profile?.user.tokens_balance ?? 0)
        let trading = userStats?.trading
        let streak = userStats?.streak
        
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ProfileStatCard(
                icon: "🪙",
                value: formatNumber(tokens),
                label: "Tokens",
                trend: trading.map { $0.realized_pnl >= 0 ? "+\(formatNumber(Int($0.realized_pnl)))" : "\(formatNumber(Int($0.realized_pnl)))" },
                trendUp: trading.map { $0.realized_pnl >= 0 }
            )
            
            ProfileStatCard(
                icon: "🎯",
                value: trading.map { "\(Int($0.accuracy))%" } ?? "—",
                label: "Accuracy",
                trend: trading.map { "\($0.wins)/\($0.wins + $0.losses) wins" },
                trendUp: nil
            )
            
            ProfileStatCard(
                icon: "📊",
                value: trading.map { "\($0.total_bets)" } ?? "0",
                label: "Total Bets",
                trend: trading.map { "\($0.events_bet_on) events" },
                trendUp: nil
            )
            
            ProfileStatCard(
                icon: "🔥",
                value: "\(streak?.current ?? gamification.streak.currentStreak)",
                label: "Day Streak",
                trend: streak.map { $0.current > 0 ? "Best: \($0.longest)" : nil } ?? nil,
                trendUp: nil
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Active Positions
    
    private var activePositionsSection: some View {
        let bets = session.profile?.bets ?? []
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Positions")
                    .font(.title3.bold())
                
                Spacer()
                
                if !bets.isEmpty {
                    Text("\(bets.count) total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            if bets.isEmpty {
                EmptyPositionsCard()
            } else {
                ForEach(bets.prefix(10)) { bet in
                    BetCard(bet: bet)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Friends Section
    
    private var friendsSection: some View {
        let friends = session.profile?.friends ?? []
        let friendsCount = userStats?.social.friends_count ?? friends.count
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Friends")
                    .font(.title3.bold())
                
                if friendsCount > 0 {
                    Text("\(friendsCount)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(TychesTheme.primary)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                Button {
                    showFriends = true
                    HapticManager.impact(.light)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.plus")
                        Text("Manage")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(TychesTheme.primary)
                }
            }
            .padding(.horizontal)
            
            if friends.isEmpty {
                EmptyFriendsCard(onAddFriend: { showFriends = true })
            } else {
                VStack(spacing: 0) {
                    ForEach(friends.prefix(5), id: \.id) { friend in
                        ProfileFriendRow(friend: friend)
                        if friend.id != friends.prefix(5).last?.id {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                    
                    if friends.count > 5 {
                        Button {
                            showFriends = true
                        } label: {
                            Text("View all \(friends.count) friends")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(TychesTheme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .background(TychesTheme.cardBackground)
                .cornerRadius(16)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helpers
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func initials(for user: User?) -> String {
        let base = user?.name ?? user?.username ?? "?"
        let parts = base.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(base.prefix(1)).uppercased()
    }
}

// MARK: - Profile Stat Card

struct ProfileStatCard: View {
    let icon: String
    let value: String
    let label: String
    let trend: String?
    let trendUp: Bool?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(icon)
                    .font(.title2)
                Spacer()
                if let trend = trend, let trendUp = trendUp {
                    Text(trend)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(trendUp ? TychesTheme.success : TychesTheme.danger)
                } else if let trend = trend {
                    Text(trend)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(value)
                .font(.title2.bold())
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(TychesTheme.cardBackground)
        .cornerRadius(16)
    }
}

// MARK: - Empty States

struct EmptyPositionsCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("📊")
                .font(.system(size: 40))
            Text("No active positions")
                .font(.subheadline.weight(.semibold))
            Text("Start betting to see your positions here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(TychesTheme.cardBackground)
        .cornerRadius(16)
    }
}

struct EmptyFriendsCard: View {
    var onAddFriend: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 12) {
            Text("👥")
                .font(.system(size: 40))
            Text("No friends yet")
                .font(.subheadline.weight(.semibold))
            Text("Add friends to compete and share predictions")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                HapticManager.impact(.light)
                onAddFriend()
            } label: {
                Text("Find Friends")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(TychesTheme.primaryGradient)
                    .cornerRadius(20)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(TychesTheme.cardBackground)
        .cornerRadius(16)
    }
}

// MARK: - Bet Card

struct BetCard: View {
    let bet: BetSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Event title
            Text(bet.event_title ?? "Event")
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            
            // Bet details
            HStack(spacing: 12) {
                if let side = bet.side {
                    Text(side)
                        .font(.caption.weight(.bold))
                        .foregroundColor(side == "YES" ? TychesTheme.success : TychesTheme.danger)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            (side == "YES" ? TychesTheme.success : TychesTheme.danger).opacity(0.12)
                        )
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(bet.shares) tokens @ \(bet.price)¢")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text("Potential:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        let payout = Int(Double(bet.shares * 100) / Double(bet.price))
                        let profit = payout - bet.shares
                        
                        Text("+\(profit)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(TychesTheme.success)
                    }
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(TychesTheme.success)
                    .frame(width: 8, height: 8)
            }
        }
        .padding()
        .background(TychesTheme.cardBackground)
        .cornerRadius(16)
    }
}

// MARK: - Profile Friend Row (for profile view)

struct ProfileFriendRow: View {
    let friend: FriendSummary
    
    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            Circle()
                .fill(TychesTheme.avatarGradient(for: friend.id))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(initials)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                )
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name ?? friend.username ?? "Friend")
                    .font(.body.weight(.medium))
                
                if let username = friend.username {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status badge
            Text(friend.shortStatus)
                .font(.caption.weight(.medium))
                .foregroundColor(friend.status == "accepted" ? TychesTheme.success : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    (friend.status == "accepted" ? TychesTheme.success : Color.gray).opacity(0.12)
                )
                .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private var initials: String {
        let name = friend.name ?? friend.username ?? "?"
        return String(name.prefix(1)).uppercased()
    }
}

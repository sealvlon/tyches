import SwiftUI

struct HomeView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var gamification = GamificationManager.shared
    @State private var isRefreshing = false
    @State private var showConfetti = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showLeaderboard = false
    @State private var selectedQuickBetEvent: EventSummary?
    @State private var deckEvents: [EventSummary] = []
    @State private var missions: [Mission] = []
    @State private var isLoadingMissions = false
    @State private var seenMissionIds: Set<String> = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 20) {
                        if !deckEvents.isEmpty {
                            SwipeDeckView(events: deckEvents)
                        } else {
                            // Show CTA when no deck events
                            SwipeDeckView(events: [])
                        }
                        streakBanner
                        closingSoonSection
                        dailyChallengesSection
                        quickBetSection
                        marketsPillsSection
                        hotEventsSection
                        leaderboardPreview
                        missionsSection
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
                .background(TychesTheme.background)
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 12) {
                            // Tokens balance pill
                            tokenBalancePill
                            
                            // Level indicator
                            levelBadge
                        }
                    }
                }
            .refreshable {
                await refreshData()
            }
            .task {
                await gamification.recordActivity()
                await gamification.syncWithBackend()
                if session.profile == nil {
                    await refreshData()
                }
                deckEvents = (session.profile?.events_created ?? []).filter { $0.status == "open" }
                await loadMissions()
            }
            .onAppear {
                Analytics.shared.trackScreenView("Home")
            }
                
                // Confetti overlay
                if showConfetti {
                    ConfettiView()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
            .sheet(isPresented: $showLeaderboard) {
                NavigationStack {
                    LeaderboardView()
                        .navigationTitle("Leaderboard")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showLeaderboard = false }
                            }
                        }
                }
            }
            .sheet(item: $selectedQuickBetEvent) { event in
                QuickBetSheet(event: event, onBetPlaced: {
                    selectedQuickBetEvent = nil
                    showConfetti = true
                    HapticManager.notification(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showConfetti = false
                    }
                    // Refresh data after bet placed
                    Task {
                        await refreshData()
                    }
                })
            }
            // Listen for bet placed notifications from other screens
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BetPlaced"))) { _ in
                Task {
                    await refreshData()
                }
            }
        }
    }
    
    private func refreshData() async {
        isRefreshing = true
        HapticManager.impact(.light)
        async let profile: () = session.refreshProfile()
        async let gamificationSync: () = gamification.syncWithBackend()
        async let missionLoad: () = loadMissions()
        _ = await (profile, gamificationSync, missionLoad)
        deckEvents = (session.profile?.events_created ?? []).filter { $0.status == "open" }
        isRefreshing = false
    }
    
    // MARK: - Closing Soon Section (FOMO + Urgency)
    
    private var closingSoonSection: some View {
        let events = (session.profile?.events_created ?? [])
            .filter { $0.status == "open" }
            .prefix(3)
        
        guard !events.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("⏰ Closing Soon")
                        .font(.title3.bold())
                    
                    Spacer()
                    
                    // Live indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(TychesTheme.danger)
                            .frame(width: 8, height: 8)
                        Text("LIVE")
                            .font(.caption.bold())
                            .foregroundColor(TychesTheme.danger)
                    }
                }
                
                ForEach(Array(events)) { event in
                    ClosingSoonCard(event: event) {
                        selectedQuickBetEvent = event
                        HapticManager.impact(.medium)
                    }
                }
            }
        )
    }
    
    // MARK: - Token Balance Pill
    
    private var tokenBalancePill: some View {
        TokenBalancePill(balance: session.profile?.user.tokens_balance ?? 0)
    }
    
    // MARK: - Level Badge
    
    private var levelBadge: some View {
        HStack(spacing: 4) {
            Text("Lv")
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
            Text("\(gamification.level)")
                .font(.subheadline.weight(.bold))
                .foregroundColor(TychesTheme.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(TychesTheme.primary.opacity(0.1))
        .cornerRadius(20)
    }

    // MARK: - Streak Banner
    
    private var streakBanner: some View {
        let streak = gamification.streak
        let name = session.profile?.user.name ?? session.profile?.user.username ?? "friend"
        
        return VStack(spacing: 0) {
            // Main banner
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(streak.streakEmoji)
                            .font(.title)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(streak.currentStreak) day streak")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            Text(streak.streakMessage)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                
                Spacer()
                
                // Weekly calendar
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { index in
                        let isActive = index < streak.weeklyActivity.count && streak.weeklyActivity[index]
                        Circle()
                            .fill(isActive ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: streak.currentStreak >= 7 ?
                        [Color.orange, Color.red] :
                        [TychesTheme.primary, TychesTheme.secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16, corners: [.topLeft, .topRight])
            
            // XP Progress bar
            VStack(spacing: 4) {
                HStack {
                    Text(gamification.levelTitle)
                        .font(.caption.weight(.medium))
                        .foregroundColor(TychesTheme.primary)
                    Spacer()
                    Text("\(gamification.xp)/\(gamification.xpForNextLevel) XP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(TychesTheme.primaryGradient)
                            .frame(width: geo.size.width * gamification.xpProgress, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding()
            .background(TychesTheme.cardBackground)
            .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
        }
        .shadow(color: TychesTheme.primary.opacity(0.2), radius: 10, y: 5)
    }
    
    // MARK: - Daily Challenges Section
    
    private var dailyChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Challenges")
                    .font(.title3.bold())
                
                Spacer()
                
                Text(timeUntilReset)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(gamification.dailyChallenges) { challenge in
                        DailyChallengeCard(challenge: challenge)
                    }
                }
            }
        }
    }
    
    private var timeUntilReset: String {
        let calendar = Calendar.current
        let now = Date()
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            let diff = calendar.dateComponents([.hour, .minute], from: now, to: tomorrow)
            return "Resets in \(diff.hour ?? 0)h \(diff.minute ?? 0)m"
        }
        return ""
    }
    
    // MARK: - Quick Bet Section
    
    private var quickBetSection: some View {
        let events = (session.profile?.events_created ?? [])
            .filter { $0.status == "open" }
            .prefix(3)
        
        guard !events.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("⚡️ Quick Bet")
                        .font(.title3.bold())
                    Spacer()
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(events)) { event in
                            QuickBetCard(event: event) {
                                selectedQuickBetEvent = event
                                HapticManager.impact(.medium)
                            }
                        }
                    }
                }
            }
        )
    }

    // MARK: - Markets Pills Section
    
    private var marketsPillsSection: some View {
        let markets = session.profile?.markets ?? []
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Markets")
                    .font(.title3.bold())
                Spacer()
                NavigationLink(destination: MarketsView()) {
                    Text("See All")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(TychesTheme.primary)
                }
            }
            
            if markets.isEmpty {
                EmptyStateCard(
                    emoji: "🎯",
                    title: "No markets yet",
                    subtitle: "Create one to start predicting with friends"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(markets) { market in
                            NavigationLink {
                                MarketDetailView(market: market)
                            } label: {
                                MarketPill(market: market)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Hot Events Section
    
    private var hotEventsSection: some View {
        let events = session.profile?.events_created ?? []
        let sortedEvents = events.sorted { $0.volume > $1.volume }
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🔥 Hot Events")
                    .font(.title3.bold())
                
                Spacer()
                
                if !sortedEvents.isEmpty {
                    Text("\(sortedEvents.count) active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            if sortedEvents.isEmpty {
                EmptyStateCard(
                    emoji: "✨",
                    title: "No events yet",
                    subtitle: "Events you create will appear here"
                )
            } else {
                ForEach(sortedEvents.prefix(5)) { event in
                    NavigationLink {
                        EventDetailView(eventID: event.id)
                    } label: {
                        EventCard(event: event)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Leaderboard Preview
    
    private var leaderboardPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🏆 Leaderboard")
                    .font(.title3.bold())
                
                Spacer()
                
                Button {
                    showLeaderboard = true
                    HapticManager.impact(.light)
                } label: {
                    Text("See All")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(TychesTheme.primary)
                }
            }
            
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    HStack(spacing: 12) {
                        Text(["🥇", "🥈", "🥉"][index])
                            .font(.title3)
                        
                        Circle()
                            .fill(TychesTheme.avatarGradient(for: index))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(["A", "L", "M"][index])
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                            )
                        
                        Text(["Alex Thunder", "Luna Star", "Max Profit"][index])
                            .font(.subheadline.weight(.medium))
                        
                        Spacer()
                        
                        Text(formatNumber([45234, 42100, 38900][index]))
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(TychesTheme.primary)
                    }
                    .padding(.vertical, 8)
                    
                    if index < 2 {
                        Divider()
                    }
                }
            }
            .padding()
            .background(TychesTheme.cardBackground)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Helpers
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    // MARK: - Missions Section
    private var missionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🎯 Missions")
                    .font(.title3.bold())
                Spacer()
                if isLoadingMissions {
                    ProgressView().scaleEffect(0.8)
                }
            }
            
            if missions.isEmpty {
                Text("Complete daily missions to earn tokens and XP.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(missions.prefix(3)) { mission in
                    MissionRow(mission: mission)
                        .padding(.vertical, 6)
                }
            }
        }
    }
    
    private func loadMissions() async {
        isLoadingMissions = true
        defer { isLoadingMissions = false }
        do {
            let response = try await TychesAPI.shared.fetchMissions()
            await MainActor.run {
                missions = response.missions
                let newlyCompleted = response.missions.filter { $0.isCompleted && !seenMissionIds.contains($0.id) }
                newlyCompleted.first.map {
                    NotificationCenter.default.post(name: .missionCompleted, object: nil, userInfo: ["mission_id": $0.id])
                }
                let completedIds = response.missions.filter { $0.isCompleted }.map { $0.id }
                seenMissionIds.formUnion(completedIds)
            }
        } catch {
            // quietly ignore
        }
    }
}

// MARK: - Mission Row
struct MissionRow: View {
    let mission: Mission
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(mission.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if mission.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(TychesTheme.success)
                }
            }
            Text(mission.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(TychesTheme.primaryGradient)
                        .frame(width: geo.size.width * mission.progressPercent, height: 8)
                }
            }
            .frame(height: 8)
            
            HStack {
                Text("\(mission.progress)/\(mission.target)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("+\(mission.reward) tokens")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(TychesTheme.gold)
            }
        }
        .padding(12)
        .background(TychesTheme.cardBackground)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Daily Challenge Card

struct DailyChallengeCard: View {
    let challenge: DailyChallenge
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(challenge.emoji)
                    .font(.title2)
                
                Spacer()
                
                if challenge.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(TychesTheme.success)
                } else {
                    Text("+\(challenge.reward)")
                        .font(.caption.bold())
                        .foregroundColor(TychesTheme.gold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(TychesTheme.gold.opacity(0.15))
                        .cornerRadius(6)
                }
            }
            
            Text(challenge.title)
                .font(.subheadline.weight(.semibold))
            
            Text(challenge.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(challenge.isCompleted ? TychesTheme.successGradient : TychesTheme.primaryGradient)
                        .frame(width: geo.size.width * challenge.progressPercent, height: 6)
                }
            }
            .frame(height: 6)
            
            Text("\(challenge.progress)/\(challenge.target)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 160)
        .background(TychesTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            challenge.isCompleted ?
            RoundedRectangle(cornerRadius: 16)
                .stroke(TychesTheme.success.opacity(0.5), lineWidth: 2)
            : nil
        )
    }
}

// MARK: - Quick Bet Card

struct QuickBetCard: View {
    let event: EventSummary
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(TychesTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if event.event_type == "binary" {
                    HStack(spacing: 8) {
                        QuickOddsPill(side: "YES", percent: event.currentYesPercent)
                        QuickOddsPill(side: "NO", percent: event.currentNoPercent)
                    }
                }
                
                HStack {
                    Text("\(event.traders_count) traders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Bet →")
                        .font(.caption.bold())
                        .foregroundColor(TychesTheme.primary)
                }
            }
            .padding()
            .frame(width: 200)
            .background(TychesTheme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(TychesTheme.primary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct QuickOddsPill: View {
    let side: String
    let percent: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Text(side)
                .font(.caption2.bold())
            Text("\(percent)%")
                .font(.caption.bold())
        }
        .foregroundColor(side == "YES" ? TychesTheme.success : TychesTheme.danger)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((side == "YES" ? TychesTheme.success : TychesTheme.danger).opacity(0.12))
        .cornerRadius(8)
    }
}

// MARK: - Quick Bet Sheet

struct QuickBetSheet: View {
    let event: EventSummary
    let onBetPlaced: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedSide: String? = nil
    @State private var betAmount: Int = 100
    @State private var isPlacing = false
    @EnvironmentObject var session: SessionStore
    
    let amounts = [50, 100, 250, 500, 1000]
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundColor(TychesTheme.primary)
                Spacer()
                Text("Quick Bet")
                    .font(.headline)
                Spacer()
                // Invisible button for balance
                Button("Cancel") { }
                    .opacity(0)
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Event title
                    Text(event.title)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 16)
                    
                    // Side selection
                    if event.event_type == "binary" {
                        HStack(spacing: 12) {
                            SideButton(
                                side: "YES",
                                percent: event.currentYesPercent,
                                isSelected: selectedSide == "YES"
                            ) {
                                selectedSide = "YES"
                                HapticManager.selection()
                            }
                            
                            SideButton(
                                side: "NO",
                                percent: event.currentNoPercent,
                                isSelected: selectedSide == "NO"
                            ) {
                                selectedSide = "NO"
                                HapticManager.selection()
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Amount selection
                    VStack(spacing: 12) {
                        Text("Amount")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 10) {
                            ForEach(amounts, id: \.self) { amount in
                                Button {
                                    betAmount = amount
                                    HapticManager.selection()
                                } label: {
                                    Text("\(amount)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(betAmount == amount ? .white : TychesTheme.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(betAmount == amount ? TychesTheme.primaryGradient : LinearGradient(colors: [TychesTheme.cardBackground], startPoint: .top, endPoint: .bottom))
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }
                    
                    // Summary
                    if let side = selectedSide {
                        let price = side == "YES" ? event.currentYesPercent : event.currentNoPercent
                        let payout = Int(Double(betAmount * 100) / Double(max(price, 1)))
                        let profit = payout - betAmount
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("If \(side) wins:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("+\(profit) tokens")
                                    .font(.headline)
                                    .foregroundColor(TychesTheme.success)
                            }
                            HStack {
                                Text("Total payout:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(payout) tokens")
                                    .font(.headline)
                            }
                        }
                        .padding()
                        .background(TychesTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
            
            // Place bet button
            Button {
                Task {
                    await placeBet()
                }
            } label: {
                HStack {
                    if isPlacing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Place Bet")
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    selectedSide != nil ?
                    TychesTheme.primaryGradient :
                    LinearGradient(colors: [Color.gray], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(14)
            }
            .disabled(selectedSide == nil || isPlacing)
            .padding()
        }
        .presentationDetents([.medium])
    }
    
    private func placeBet() async {
        guard let side = selectedSide else { return }
        isPlacing = true
        
        // Use amount-based betting (parimutuel)
        let bet = BetPlaceRequest(
            event_id: event.id,
            side: side,
            outcome_id: nil,
            amount: Double(betAmount)
        )
        
        do {
            _ = try await TychesAPI.shared.placeBet(bet)
            GamificationManager.shared.recordBet(amount: betAmount)
            await session.refreshProfile()
            
            // Notify other screens to refresh with updated odds
            NotificationCenter.default.post(name: NSNotification.Name("BetPlaced"), object: nil)
            
            dismiss()
            onBetPlaced()
        } catch {
            // Handle error
            isPlacing = false
        }
    }
}

struct SideButton: View {
    let side: String
    let percent: Int
    let isSelected: Bool
    let action: () -> Void
    
    var sideColor: Color {
        side == "YES" ? TychesTheme.success : TychesTheme.danger
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(side)
                    .font(.headline.bold())
                Text("\(percent)%")
                    .font(.title.bold())
            }
            .foregroundColor(isSelected ? .white : sideColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                isSelected ?
                (side == "YES" ? TychesTheme.successGradient : TychesTheme.dangerGradient) :
                LinearGradient(colors: [sideColor.opacity(0.12)], startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : sideColor.opacity(0.3), lineWidth: 2)
            )
        }
    }
}

// EmptyStateCard is now available as TychesEmptyStateView in SharedComponents
// Keeping this wrapper for backward compatibility
struct EmptyStateCard: View {
    let emoji: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 40))
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(TychesTheme.cardBackground)
        .cornerRadius(16)
    }
}

// MARK: - Market Pill Component

struct MarketPill: View {
    let market: MarketSummary
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 6) {
            Text(market.avatar_emoji ?? "🎯")
                .font(.system(size: 28))
            Text(market.name)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(TychesTheme.textPrimary)
                .lineLimit(1)
            HStack(spacing: 4) {
                Text("\(market.events_count ?? 0)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(TychesTheme.primary)
                Text("events")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .background(TychesTheme.cardBackground)
        .cornerRadius(16)
        .scaleEffect(isPressed ? 0.95 : 1)
        .animation(.spring(response: 0.3), value: isPressed)
    }
}

// MARK: - Event Card Component

struct EventCard: View {
    let event: EventSummary
    @State private var isAppeared = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text(event.market_name ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                StatusBadge(status: event.status, closesAt: event.closes_at)
            }
            
            // Title
            Text(event.title)
                .font(.headline)
                .foregroundColor(TychesTheme.textPrimary)
                .lineLimit(2)
            
            // Odds (if binary)
            if event.event_type == "binary" {
                HStack(spacing: 10) {
                    OddsPill(side: "YES", percent: event.currentYesPercent)
                    OddsPill(side: "NO", percent: event.currentNoPercent)
                }
            }
            
            // Footer
            HStack {
                // Avatar stack
                HStack(spacing: -8) {
                    ForEach(0..<min(3, event.traders_count), id: \.self) { i in
                        Circle()
                            .fill(TychesTheme.avatarGradient(for: i + event.id))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().stroke(TychesTheme.cardBackground, lineWidth: 2)
                            )
                    }
                }
                
                Text("\(event.traders_count) traders")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("🪙")
                        .font(.caption)
                    Text("\(Int(event.volume))")
                        .font(.caption.weight(.bold))
                        .foregroundColor(TychesTheme.gold)
                }
            }
        }
        .padding()
        .background(TychesTheme.cardBackground)
        .cornerRadius(16)
        .opacity(isAppeared ? 1 : 0)
        .offset(y: isAppeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isAppeared = true
            }
        }
    }
}

// MARK: - Supporting Views

// StatusBadge is now available as StatusBadgeView in SharedComponents
// Keeping this wrapper for backward compatibility
struct StatusBadge: View {
    let status: String
    let closesAt: String
    
    var body: some View {
        StatusBadgeView(status: status, closesAt: closesAt, style: .standard)
    }
}

// OddsPill is now available as OddsPillView in SharedComponents
// Keeping this wrapper for backward compatibility
struct OddsPill: View {
    let side: String
    let percent: Int
    
    var body: some View {
        OddsPillView(side: side, percent: percent, style: .standard)
    }
}

// MARK: - Closing Soon Card (Urgency + Countdown)

struct ClosingSoonCard: View {
    let event: EventSummary
    let onTap: () -> Void
    
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Countdown timer
                VStack(spacing: 2) {
                    Text(formatCountdown())
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundColor(urgencyColor)
                    Text("left")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 70)
                .padding(.vertical, 10)
                .background(urgencyColor.opacity(0.12))
                .cornerRadius(10)
                
                // Event info
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(TychesTheme.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("YES")
                                .font(.caption2.bold())
                                .foregroundColor(TychesTheme.success)
                            Text("\(event.currentYesPercent)%")
                                .font(.caption.bold())
                                .foregroundColor(TychesTheme.success)
                        }
                        
                        HStack(spacing: 4) {
                            Text("NO")
                                .font(.caption2.bold())
                                .foregroundColor(TychesTheme.danger)
                            Text("\(event.currentNoPercent)%")
                                .font(.caption.bold())
                                .foregroundColor(TychesTheme.danger)
                        }
                        
                        Spacer()
                        
                        Text("\(event.traders_count) betting")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(TychesTheme.cardBackground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(urgencyColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            calculateTimeRemaining()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private var urgencyColor: Color {
        if timeRemaining < 3600 { return TychesTheme.danger } // < 1 hour
        if timeRemaining < 86400 { return TychesTheme.warning } // < 1 day
        return TychesTheme.primary
    }
    
    private func formatCountdown() -> String {
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60
        
        if hours > 24 {
            return "\(hours / 24)d \(hours % 24)h"
        } else if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func calculateTimeRemaining() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        
        if let closeDate = formatter.date(from: event.closes_at) {
            timeRemaining = max(0, closeDate.timeIntervalSinceNow)
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            }
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

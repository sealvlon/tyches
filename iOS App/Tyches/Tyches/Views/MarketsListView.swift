import SwiftUI

// MARK: - Markets List View (Reimagined)
// Instagram-story style markets with visual appeal

struct MarketsListView: View {
    @EnvironmentObject var session: SessionStore
    @State private var selectedMarket: MarketSummary?
    @State private var showMarketDetail = false
    
    var markets: [MarketSummary] {
        session.profile?.markets ?? []
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with gradient accent
                    header
                        .padding(.top, 70)
                    
                    // Stories-style market row with extra padding for circles
                    if !markets.isEmpty {
                        marketStoriesRow
                            .padding(.vertical, 8)
                    }
                    
                    // Section title for cards
                    if !markets.isEmpty {
                        HStack {
                            Text("All Markets")
                                .font(.headline)
                                .foregroundColor(TychesTheme.textPrimary)
                            Spacer()
                            Text("\(markets.count)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(TychesTheme.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(TychesTheme.primary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Market cards
                    LazyVStack(spacing: 16) {
                        ForEach(markets) { market in
                            MarketCardNew(market: market)
                                .onTapGesture {
                                    selectedMarket = market
                                    showMarketDetail = true
                                    HapticManager.selection()
                                }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Empty state
                    if markets.isEmpty {
                        emptyState
                    }
                    
                    Spacer(minLength: 120)
                }
            }
            .background(TychesTheme.background)
            .refreshable {
                await session.refreshProfile()
            }
            .navigationDestination(isPresented: $showMarketDetail) {
                if let market = selectedMarket {
                    MarketDetailNew(marketId: market.id)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Markets")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(TychesTheme.premiumGradient)
                    
                    Text("\(markets.count) groups · \(totalEvents) active events")
                        .font(.subheadline)
                        .foregroundColor(TychesTheme.textSecondary)
                }
                
                Spacer()
                
                // Stats badge
                if totalEvents > 0 {
                    VStack(spacing: 2) {
                        Text("🔥")
                            .font(.title2)
                        Text("\(totalEvents)")
                            .font(.caption.bold())
                            .foregroundColor(TychesTheme.textPrimary)
                    }
                    .padding(12)
                    .background(TychesTheme.cardBackground)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
    
    private var totalEvents: Int {
        markets.reduce(0) { $0 + ($1.events_count ?? 0) }
    }
    
    // MARK: - Stories Row
    
    private var marketStoriesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(markets) { market in
                    MarketStoryBubble(market: market) {
                        selectedMarket = market
                        showMarketDetail = true
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6) // Extra padding to prevent circles from being cut
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(TychesTheme.primary.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Text("👥")
                    .font(.system(size: 50))
            }
            
            VStack(spacing: 8) {
                Text("No markets yet")
                    .font(.title3.bold())
                
                Text("Create a market to start predicting\nwith your friends")
                    .font(.subheadline)
                    .foregroundColor(TychesTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 60)
    }
}

// MARK: - Market Story Bubble

struct MarketStoryBubble: View {
    let market: MarketSummary
    let action: () -> Void
    
    var hasActivity: Bool {
        (market.events_count ?? 0) > 0
    }
    
    var body: some View {
        Button(action: {
            action()
            HapticManager.selection()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    // Ring
                    Circle()
                        .stroke(
                            hasActivity 
                                ? TychesTheme.premiumGradient 
                                : LinearGradient(colors: [TychesTheme.textTertiary], startPoint: .top, endPoint: .bottom),
                            lineWidth: 3
                        )
                        .frame(width: 72, height: 72)
                    
                    // Avatar
                    Circle()
                        .fill(Color(hex: market.avatar_color ?? "6366F1"))
                        .frame(width: 64, height: 64)
                    
                    Text(market.avatar_emoji ?? "🎯")
                        .font(.system(size: 28))
                }
                
                Text(market.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: 72)
            }
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Market Card New

struct MarketCardNew: View {
    let market: MarketSummary
    
    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: market.avatar_color ?? "6366F1"))
                    .frame(width: 52, height: 52)
                
                Text(market.avatar_emoji ?? "🎯")
                    .font(.title2)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(market.name)
                    .font(.headline)
                    .foregroundColor(TychesTheme.textPrimary)
                
                HStack(spacing: 12) {
                    Label("\(market.members_count ?? 0)", systemImage: "person.2.fill")
                    Label("\(market.events_count ?? 0)", systemImage: "list.bullet")
                }
                .font(.caption)
                .foregroundColor(TychesTheme.textSecondary)
            }
            
            Spacer()
            
            // Activity badge + Arrow
            HStack(spacing: 8) {
                if (market.events_count ?? 0) > 0 {
                    Text("\(market.events_count ?? 0)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(TychesTheme.success)
                        .clipShape(Circle())
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(TychesTheme.textTertiary)
            }
        }
        .padding(16)
        .background(TychesTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Market Detail New

struct MarketDetailNew: View {
    let marketId: Int
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) var dismiss
    @State private var market: MarketDetail?
    @State private var members: [MarketMember] = []
    @State private var events: [EventSummary] = []
    @State private var isLoading = true
    @State private var selectedEvent: EventSummary?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                if let market = market {
                    marketHeader(market, members: members)
                }
                
                // Events
                LazyVStack(spacing: 12) {
                    ForEach(events) { event in
                        EventRowNew(event: event)
                            .onTapGesture {
                                selectedEvent = event
                            }
                    }
                }
                .padding()
                
                Spacer(minLength: 120)
            }
        }
        .background(TychesTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: Binding(
            get: { selectedEvent != nil },
            set: { if !$0 { selectedEvent = nil } }
        )) {
            if let event = selectedEvent {
                EventDetailNew(eventId: event.id)
            }
        }
        .task {
            await loadMarket()
        }
    }
    
    private func marketHeader(_ market: MarketDetail, members: [MarketMember]) -> some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: market.avatar_color ?? "6366F1"))
                    .frame(width: 80, height: 80)
                
                Text(market.avatar_emoji ?? "🎯")
                    .font(.system(size: 40))
            }
            
            // Name
            Text(market.name)
                .font(.title2.bold())
                .foregroundColor(TychesTheme.textPrimary)
            
            // Stats
            HStack(spacing: 32) {
                StatBubble(value: "\(members.count)", label: "Members")
                StatBubble(value: "\(events.count)", label: "Events")
            }
            
            // Members avatars
            if !members.isEmpty {
                HStack(spacing: -8) {
                    ForEach(members.prefix(5)) { member in
                        Circle()
                            .fill(TychesTheme.avatarGradient(for: member.id))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String((member.name ?? member.username ?? "U").prefix(1)).uppercased())
                                    .font(.caption.bold())
                                    .foregroundColor(TychesTheme.textPrimary)
                            )
                            .overlay(Circle().stroke(TychesTheme.background, lineWidth: 2))
                    }
                    
                    if members.count > 5 {
                        Circle()
                            .fill(TychesTheme.surfaceElevated)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text("+\(members.count - 5)")
                                    .font(.caption2.bold())
                                    .foregroundColor(TychesTheme.textSecondary)
                            )
                            .overlay(Circle().stroke(TychesTheme.background, lineWidth: 2))
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: market.avatar_color ?? "6366F1").opacity(0.2),
                    TychesTheme.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func loadMarket() async {
        do {
            let response = try await TychesAPI.shared.fetchMarketDetail(id: marketId)
            market = response.market
            members = response.members
            events = response.events
        } catch {
            // Handle error
        }
        isLoading = false
    }
}

struct StatBubble: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundColor(TychesTheme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundColor(TychesTheme.textSecondary)
        }
    }
}

// MARK: - Event Row New

struct EventRowNew: View {
    let event: EventSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(event.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(TychesTheme.textPrimary)
                .lineLimit(2)
            
            // Probability bar
            HStack(spacing: 0) {
                // YES side
                HStack {
                    Text("\(event.currentYesPercent)%")
                        .font(.caption.bold())
                    Text("YES")
                        .font(.caption2)
                }
                .foregroundColor(TychesTheme.success)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(TychesTheme.success.opacity(0.12))
                
                // NO side
                HStack {
                    Text("NO")
                        .font(.caption2)
                    Text("\(event.currentNoPercent)%")
                        .font(.caption.bold())
                }
                .foregroundColor(TychesTheme.danger)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(TychesTheme.danger.opacity(0.12))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Stats row
            HStack {
                HStack(spacing: 12) {
                    Label("\(Int(event.totalPool))", systemImage: "dollarsign.circle")
                    Label("\(event.traders_count)", systemImage: "person.2")
                }
                .font(.caption)
                .foregroundColor(TychesTheme.textTertiary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(TychesTheme.textTertiary)
            }
        }
        .padding(16)
        .background(TychesTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Event Detail New

struct EventDetailNew: View {
    let eventId: Int
    @EnvironmentObject var session: SessionStore
    @State private var event: EventDetail?
    @State private var isLoading = true
    @State private var showBetSheet = false
    @State private var selectedSide: String = "YES"
    
    var body: some View {
        ZStack {
            TychesTheme.background.ignoresSafeArea()
            
            if isLoading {
                ProgressView()
            } else if let event = event {
                ScrollView {
                    VStack(spacing: 24) {
                        // Main card
                        eventCard(event)
                        
                        // Betting section
                        bettingSection(event)
                        
                        // Activity/Gossip tabs
                        activitySection(event)
                        
                        Spacer(minLength: 120)
                    }
                    .padding()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBetSheet) {
            if let event = event {
                BetSheetNew(event: event, side: selectedSide)
            }
        }
        .task {
            await loadEvent()
        }
    }
    
    private func eventCard(_ event: EventDetail) -> some View {
        VStack(spacing: 20) {
            // Status badge
            HStack {
                Text(event.status.uppercased())
                    .font(.caption2.bold())
                    .foregroundColor(event.status == "open" ? TychesTheme.success : TychesTheme.warning)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        (event.status == "open" ? TychesTheme.success : TychesTheme.warning).opacity(0.1)
                    )
                    .clipShape(Capsule())
                
                Spacer()
                
                if let closesAt = event.closes_at.toDate() {
                    Label(closesAt.timeRemaining(), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(TychesTheme.textSecondary)
                }
            }
            
            // Question
            Text(event.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .foregroundColor(TychesTheme.textPrimary)
            
            // Probability bar
            probabilityBar(event)
            
            // Stats
            HStack(spacing: 24) {
                Label("\(Int(event.totalPool)) pool", systemImage: "dollarsign.circle")
                Label("\(event.traders_count ?? 0) traders", systemImage: "person.2")
            }
            .font(.subheadline)
            .foregroundColor(TychesTheme.textSecondary)
        }
        .padding(24)
        .background(TychesTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    private func probabilityBar(_ event: EventDetail) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(TychesTheme.danger.opacity(0.3))
                
                // YES portion
                RoundedRectangle(cornerRadius: 8)
                    .fill(TychesTheme.success)
                    .frame(width: geo.size.width * CGFloat(event.currentYesPercent) / 100)
                
                // Labels
                HStack {
                    Text("\(event.currentYesPercent)% YES")
                        .font(.caption.bold())
                        .foregroundColor(TychesTheme.textPrimary)
                        .padding(.leading, 12)
                    
                    Spacer()
                    
                    Text("\(event.currentNoPercent)% NO")
                        .font(.caption.bold())
                        .foregroundColor(TychesTheme.textPrimary)
                        .padding(.trailing, 12)
                }
            }
        }
        .frame(height: 36)
    }
    
    private func bettingSection(_ event: EventDetail) -> some View {
        HStack(spacing: 12) {
            // YES button
            Button {
                selectedSide = "YES"
                showBetSheet = true
                HapticManager.impact(.medium)
            } label: {
                VStack(spacing: 8) {
                    Text("YES")
                        .font(.headline.bold())
                    Text("\(event.yesOdds, specifier: "%.2f")x")
                        .font(.caption)
                        .foregroundColor(TychesTheme.textSecondary)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(TychesTheme.successGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(BounceButtonStyle())
            
            // NO button
            Button {
                selectedSide = "NO"
                showBetSheet = true
                HapticManager.impact(.medium)
            } label: {
                VStack(spacing: 8) {
                    Text("NO")
                        .font(.headline.bold())
                    Text("\(event.noOdds, specifier: "%.2f")x")
                        .font(.caption)
                        .foregroundColor(TychesTheme.textSecondary)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(TychesTheme.dangerGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(BounceButtonStyle())
        }
    }
    
    private func activitySection(_ event: EventDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)
                .foregroundColor(TychesTheme.textPrimary)
            
            // Placeholder for activity
            HStack {
                Text("💬")
                Text("Start the conversation...")
                    .foregroundColor(TychesTheme.textTertiary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TychesTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func loadEvent() async {
        do {
            let response = try await TychesAPI.shared.fetchEventDetail(id: eventId)
            event = response.event
        } catch {
            // Handle error
        }
        isLoading = false
    }
}

// MARK: - Bet Sheet New

struct BetSheetNew: View {
    let event: EventDetail
    let side: String
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionStore
    @State private var amount: Double = 100
    @State private var isPlacing = false
    @State private var error: String?
    
    var odds: Double {
        side == "YES" ? event.yesOdds : event.noOdds
    }
    
    var potentialReturn: Double {
        amount * odds
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Side indicator
                VStack(spacing: 8) {
                    Circle()
                        .fill(side == "YES" ? TychesTheme.successGradient : TychesTheme.dangerGradient)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: side == "YES" ? "checkmark" : "xmark")
                                .font(.title.bold())
                                .foregroundColor(TychesTheme.textPrimary)
                        )
                    
                    Text("Bet \(side)")
                        .font(.title2.bold())
                        .foregroundColor(side == "YES" ? TychesTheme.success : TychesTheme.danger)
                }
                
                // Question
                Text(event.title)
                    .font(.subheadline)
                    .foregroundColor(TychesTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Amount
                VStack(spacing: 20) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(amount))")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(TychesTheme.textPrimary)
                        Text("tokens")
                            .font(.subheadline)
                            .foregroundColor(TychesTheme.textSecondary)
                    }
                    
                    // Quick amounts
                    HStack(spacing: 12) {
                        ForEach([50, 100, 250, 500, 1000], id: \.self) { quickAmount in
                            QuickAmountButton(
                                amount: quickAmount,
                                isSelected: Int(amount) == quickAmount
                            ) {
                                amount = Double(quickAmount)
                                HapticManager.selection()
                            }
                        }
                    }
                    
                    // Slider
                    Slider(value: $amount, in: 10...Double(session.profile?.user.tokens_balance ?? 1000), step: 10)
                        .tint(side == "YES" ? TychesTheme.success : TychesTheme.danger)
                }
                .padding()
                .background(TychesTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)
                
                // Return info
                VStack(spacing: 12) {
                    HStack {
                        Text("Current Odds")
                        Spacer()
                        Text("\(odds, specifier: "%.2f")x")
                            .fontWeight(.semibold)
                    }
                    
                    Divider()
                        .background(TychesTheme.textTertiary)
                    
                    HStack {
                        Text("Potential return")
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(Int(potentialReturn)) tokens")
                                .fontWeight(.bold)
                                .foregroundColor(TychesTheme.success)
                            Text("+\(Int(potentialReturn - amount)) profit")
                                .font(.caption)
                                .foregroundColor(TychesTheme.success)
                        }
                    }
                    
                    Divider()
                        .background(TychesTheme.textTertiary)
                    
                    // Parimutuel explanation
                    VStack(spacing: 6) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(TychesTheme.primary)
                            Text("How it works")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        Text("Tyches uses parimutuel betting: all bets go into a pool, and winners split the pot proportionally. Your final payout may change as others bet.")
                            .font(.caption)
                            .foregroundColor(TychesTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .font(.subheadline)
                .foregroundColor(TychesTheme.textSecondary)
                .padding()
                .background(TychesTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                
                if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(TychesTheme.danger)
                }
                
                Spacer()
                
                // Place bet
                Button {
                    placeBet()
                } label: {
                    HStack {
                        if isPlacing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Place Bet")
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(side == "YES" ? TychesTheme.successGradient : TychesTheme.dangerGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isPlacing)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding(.top)
            .background(TychesTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(TychesTheme.background)
    }
    
    private func placeBet() {
        isPlacing = true
        error = nil
        
        Task {
            do {
                _ = try await TychesAPI.shared.placeBet(
                    eventId: event.id,
                    side: side,
                    outcomeId: nil,
                    amount: amount
                )
                await session.refreshProfile()
                
                // Notify other screens to refresh with updated odds
                NotificationCenter.default.post(name: NSNotification.Name("BetPlaced"), object: nil)
                
                HapticManager.notification(.success)
                dismiss()
            } catch let TychesError.server(msg) {
                error = msg
                HapticManager.notification(.error)
            } catch {
                self.error = "Failed to place bet"
                HapticManager.notification(.error)
            }
            isPlacing = false
        }
    }
}

struct QuickAmountButton: View {
    let amount: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(amount)")
                .font(.caption.bold())
                .foregroundColor(isSelected ? .white : TychesTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? TychesTheme.primary : TychesTheme.surfaceElevated)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    MarketsListView()
        .environmentObject(SessionStore())
}


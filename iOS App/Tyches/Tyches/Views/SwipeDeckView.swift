import SwiftUI

/// Hero swipe/tap deck for binary and multiple-choice events.
/// Uses EventSummary as the data source and lazily loads EventDetail on demand.
/// Optimized for instant display with background refresh and odds-change cues.
struct SwipeDeckView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var deepLink: DeepLinkRouter
    
    let events: [EventSummary]
    
    @State private var currentIndex: Int = 0
    @State private var eventDetails: [Int: EventDetail] = [:]
    @State private var isLoadingDetail: Bool = false
    @State private var selectedSide: String? = nil   // YES/NO or outcome id
    @State private var betAmount: String = "100"
    @State private var isPlacingBet: Bool = false
    @State private var showBetSheet: Bool = false
    @State private var betEvent: EventDetail? = nil
    @State private var showEventDetailSheet: Bool = false
    @State private var detailEventId: Int? = nil
    @State private var pollingTask: Task<Void, Never>?
    @State private var livePools: [Int: PoolData] = [:]
    @State private var showShareSheet: Bool = false
    @State private var shareURL: URL?
    @State private var lastPercents: [Int: [String: Int]] = [:] // eventId -> outcomeId/side -> percent
    @State private var closingNotified: Set<Int> = []
    @State private var percentDeltas: [Int: [String: Int]] = [:] // eventId -> key -> delta
    @State private var lastFetchAt: [Int: Date] = [:]
    @State private var inflightEvents: Set<Int> = []
    @State private var openChatTab: Bool = false
    @State private var oddsFlashEvents: Set<Int> = [] // Events with recent odds changes for flash effect
    @State private var preloadedIndices: Set<Int> = [] // Track which cards we've preloaded
    
    var body: some View {
        VStack(spacing: 12) {
            if events.isEmpty {
                deckEmptyState
            } else {
                deckPager
            }
        }
        .task {
            // Preload first 3 cards for instant display
            await preloadAdjacentCards(around: 0)
        }
        .sheet(isPresented: $showBetSheet) {
            if let event = betEvent {
                BetSheet(
                    event: event,
                    selectedSide: $selectedSide,
                    betAmount: $betAmount,
                    isPlacingBet: $isPlacingBet,
                    onPlaceBet: {
                        await placeBet(event: event)
                    }
                )
                .environmentObject(session)
            }
        }
        .sheet(isPresented: $showEventDetailSheet) {
            if let eventId = detailEventId {
                if openChatTab {
                    EventDetailView(eventID: eventId, initialTab: 1)
                        .environmentObject(session)
                } else {
                EventDetailNew(eventId: eventId)
                    .environmentObject(session)
                }
            }
        }
        .onAppear {
            startPolling()
            // Force immediate fetch for current event
            if !events.isEmpty {
                Task {
                    await fetchDetailAndPools(for: events[currentIndex].id, force: true)
                }
            }
        }
        .onDisappear {
            stopPolling()
        }
        .onChange(of: currentIndex) { oldIndex, newIndex in
            // Fetch pools when switching cards
            if newIndex < events.count {
                Task {
                    await fetchDetailAndPools(for: events[newIndex].id, force: false)
                }
            }
        }
        .onChange(of: currentIndex) { _, newIndex in
            Task {
                await reloadCurrentEventDetail()
                // Preload adjacent cards for instant swipe
                await preloadAdjacentCards(around: newIndex)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BetPlaced"))) { _ in
            Task { await reloadCurrentEventDetail() }
        }
        .onChange(of: deepLink.targetEventId) { _, _ in
            Task { await handleDeepLinkIfNeeded() }
        }
        .sheet(isPresented: $showShareSheet, content: {
            if let shareURL = shareURL {
                ShareSheet(activityItems: [shareURL])
            }
        })
        .onChange(of: showEventDetailSheet) { _, isPresented in
            if !isPresented {
                openChatTab = false
            }
        }
    }
}

// MARK: - UI

private extension SwipeDeckView {
    var deckEmptyState: some View {
        VStack(spacing: 16) {
            Text("No predictions yet")
                .font(.title2.bold())
            Text("Join or create a market to see predictions from your friends")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 10) {
                NavigationLink(destination: CreateEventView()) {
                    primaryCTA(title: "Create an Event", gradient: TychesTheme.primaryGradient)
                }
                NavigationLink(destination: CreateMarketView()) {
                    secondaryCTA(title: "Create a Market")
                }
                NavigationLink(destination: MarketsView()) {
                    secondaryCTA(title: "Browse Markets")
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(TychesTheme.cardBackground)
        .cornerRadius(20)
    }
    
    var deckPager: some View {
        VStack(spacing: 14) {
            TabView(selection: $currentIndex) {
                ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                    deckCard(for: event, index: index)
                        .tag(index)
                        .padding(.horizontal)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 460)
            pagerIndicator
        }
    }
    
    func deckCard(for event: EventSummary, index: Int) -> some View {
        let detail = eventDetails[event.id]
        let pools = livePools[event.id] ?? detail?.pools
        return VStack(spacing: 16) {
            // Header
            HStack {
                Text("Tyches")
                    .font(.headline)
                    .foregroundColor(TychesTheme.textPrimary)
                Spacer()
                HStack(spacing: 8) {
                    if let minutes = closingSoonMinutes(event: event, detail: detail) {
                        closingSoonBadge(minutes: minutes)
                    }
                    if isFresh(eventId: event.id) {
                        liveDot
                    }
                    Button {
                        detailEventId = event.id
                        openChatTab = false
                        showEventDetailSheet = true
                        HapticManager.selection()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(TychesTheme.primary)
                            .padding(6)
                            .background(TychesTheme.primary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    HStack(spacing: 6) {
                        Text("\(index + 1)/\(events.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .opacity(0.7)
                    }
                }
            }
            
            // Title
            Text(event.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .foregroundColor(TychesTheme.textPrimary)
                .padding(.horizontal)
            
            if detail == nil && pools == nil {
                ShimmerView(cornerRadius: 12)
                    .frame(height: 120)
            }
            
            if event.event_type == "binary" {
                binaryOdds(event: event, detail: detail, pools: pools)
            } else {
                multiChoiceOptions(event: event, detail: detail, pools: pools)
            }
            
            statsRow(event: event, detail: detail, pools: pools)
            
            // Social proof: Friend activity indicator
            if let detail = detail, let pools = pools, (pools.total_pool ?? 0) > 0 {
                friendActivityIndicator(event: event, detail: detail, pools: pools)
            }
            
            // Bottom actions
            HStack(spacing: 16) {
                actionButton(title: "NO", color: TychesTheme.danger) {
                    Task { await openBet(event: event, side: "NO") }
                }
                chatButton(eventId: event.id)
                actionButton(title: "YES", color: TychesTheme.success) {
                    Task { await openBet(event: event, side: "YES") }
                }
            }
            
            challengeButton(event: event)
        }
        .padding()
        .background(TychesTheme.cardBackground)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        .onAppear {
            Task { await preloadDetailIfNeeded(index: index) }
        }
    }
    
    @ViewBuilder
    func challengeButton(event: EventSummary) -> some View {
        Button {
            let urlString = "https://www.tyches.us/app?event_id=\(event.id)"
            shareURL = URL(string: urlString)
            showShareSheet = true
            HapticManager.selection()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                    .font(.headline)
                Text("Challenge a friend")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(TychesTheme.primary)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(TychesTheme.primary.opacity(0.08))
            .cornerRadius(12)
        }
    }
    
    func binaryOdds(event: EventSummary, detail: EventDetail?, pools: PoolData?) -> some View {
        // Use pool data ONLY if there are actual bets
        let hasBets = (pools?.total_pool ?? 0) > 0
        
        let noPercent: Int
        let yesPercent: Int
        let noOdds: Double
        let yesOdds: Double
        
        if hasBets, let pools = pools {
            noPercent = pools.no_percent ?? detail?.currentNoPercent ?? event.currentNoPercent
            yesPercent = pools.yes_percent ?? detail?.currentYesPercent ?? event.currentYesPercent
            noOdds = pools.no_odds ?? detail?.noOdds ?? event.noOdds
            yesOdds = pools.yes_odds ?? detail?.yesOdds ?? event.yesOdds
        } else {
            // Use stored initial odds when no bets
            noPercent = detail?.currentNoPercent ?? event.currentNoPercent
            yesPercent = detail?.currentYesPercent ?? event.currentYesPercent
            noOdds = detail?.noOdds ?? event.noOdds
            yesOdds = detail?.yesOdds ?? event.yesOdds
        }
        
        return HStack(spacing: 12) {
            
            binaryPill(
                title: "NO",
                percent: noPercent,
                odds: noOdds,
                color: TychesTheme.danger,
                eventId: event.id,
                key: "NO"
            )
            binaryPill(
                title: "YES",
                percent: yesPercent,
                odds: yesOdds,
                color: TychesTheme.success,
                eventId: event.id,
                key: "YES"
            )
        }
    }
    
    func binaryPill(title: String, percent: Int, odds: Double, color: Color, eventId: Int, key: String) -> some View {
        let delta = percentDelta(for: eventId, key: key)
        let hasFlash = oddsFlashEvents.contains(eventId) && delta != nil
        return VStack(spacing: 6) {
            Text(title)
                .font(.caption.bold())
            HStack(spacing: 4) {
                Text("\(percent)%")
                    .font(.title2.bold())
                if let delta {
                    oddsDeltaBadge(delta: delta)
                }
            }
            Text(String(format: "%.2fx", odds))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(hasFlash ? color.opacity(0.25) : color.opacity(0.1))
                .animation(.easeInOut(duration: 0.3), value: hasFlash)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(hasFlash ? color.opacity(0.5) : Color.clear, lineWidth: 2)
                .animation(.easeInOut(duration: 0.3), value: hasFlash)
        )
        .cornerRadius(16)
    }
    
    func multiChoiceOptions(event: EventSummary, detail: EventDetail?, pools: PoolData?) -> some View {
        VStack(spacing: 10) {
            if let outcomes = detail?.outcomes {
                // Sort by percentage (highest first) for better visual hierarchy
                let sortedOutcomes = outcomes.sorted { outcome1, outcome2 in
                    let percent1 = outcomeDisplay(eventId: event.id, outcome: outcome1, detail: detail, pools: pools).percent
                    let percent2 = outcomeDisplay(eventId: event.id, outcome: outcome2, detail: detail, pools: pools).percent
                    return percent1 > percent2
                }
                
                ForEach(sortedOutcomes, id: \.id) { outcome in
                    let display = outcomeDisplay(eventId: event.id, outcome: outcome, detail: detail, pools: pools)
                    let colorScheme = outcomeColorScheme(percent: display.percent)
                    let hasFlash = oddsFlashEvents.contains(event.id) && percentDelta(for: event.id, key: outcome.id) != nil
                    
                    Button {
                        Task { await openBet(event: event, side: outcome.id) }
                    } label: {
                        HStack(spacing: 12) {
                            Text(outcome.label)
                                .font(.headline.weight(.semibold))
                                .foregroundColor(colorScheme.textColor)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Text("\(display.percent)%")
                                    .font(.title3.bold())
                                    .foregroundColor(colorScheme.percentColor)
                                
                                if let delta = percentDelta(for: event.id, key: outcome.id) {
                                    oddsDeltaBadge(delta: delta)
                                }
                            }
                            
                            Text(String(format: "%.2fx", display.odds))
                                .font(.caption.weight(.medium))
                                .foregroundColor(colorScheme.secondaryColor)
                                .frame(width: 50, alignment: .trailing)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    // Background fill
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(colorScheme.backgroundColor)
                                    
                                    // Percentage fill bar
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(colorScheme.fillColor)
                                        .frame(width: geo.size.width * CGFloat(display.percent) / 100)
                                    
                                    // Flash overlay
                                    if hasFlash {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(colorScheme.fillColor.opacity(0.3))
                                            .animation(.easeInOut(duration: 0.3), value: hasFlash)
                                    }
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(colorScheme.borderColor, lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(PressableStyle())
                }
            } else {
                // Fallback while loading detail
                ProgressView()
                    .padding(.vertical, 16)
            }
        }
    }
    
    /// Returns color scheme for an outcome based on its percentage
    func outcomeColorScheme(percent: Int) -> OutcomeColorScheme {
        if percent >= 50 {
            return OutcomeColorScheme(
                textColor: TychesTheme.textPrimary,
                percentColor: TychesTheme.success,
                secondaryColor: TychesTheme.textSecondary,
                backgroundColor: TychesTheme.success.opacity(0.08),
                fillColor: TychesTheme.success.opacity(0.15),
                borderColor: TychesTheme.success.opacity(0.3)
            )
        } else if percent >= 25 {
            return OutcomeColorScheme(
                textColor: TychesTheme.textPrimary,
                percentColor: TychesTheme.warning,
                secondaryColor: TychesTheme.textSecondary,
                backgroundColor: TychesTheme.warning.opacity(0.08),
                fillColor: TychesTheme.warning.opacity(0.15),
                borderColor: TychesTheme.warning.opacity(0.3)
            )
        } else if percent >= 10 {
            return OutcomeColorScheme(
                textColor: TychesTheme.textPrimary,
                percentColor: TychesTheme.danger,
                secondaryColor: TychesTheme.textSecondary,
                backgroundColor: TychesTheme.danger.opacity(0.08),
                fillColor: TychesTheme.danger.opacity(0.15),
                borderColor: TychesTheme.danger.opacity(0.3)
            )
        } else {
            return OutcomeColorScheme(
                textColor: TychesTheme.textSecondary,
                percentColor: TychesTheme.textTertiary,
                secondaryColor: TychesTheme.textTertiary,
                backgroundColor: TychesTheme.surfaceElevated,
                fillColor: TychesTheme.textTertiary.opacity(0.1),
                borderColor: TychesTheme.textTertiary.opacity(0.2)
            )
        }
    }
    
    struct OutcomeColorScheme {
        let textColor: Color
        let percentColor: Color
        let secondaryColor: Color
        let backgroundColor: Color
        let fillColor: Color
        let borderColor: Color
    }
    
    /// Prefer live pool data when available; fall back to static probabilities.
    /// Uses pool data ONLY if there are actual bets (total_pool > 0)
    func outcomeDisplay(eventId: Int, outcome: EventOutcome, detail: EventDetail?, pools: PoolData?) -> (percent: Int, odds: Double) {
        // Check if we have pool data with actual bets
        if let pools = pools, let totalPool = pools.total_pool, totalPool > 0 {
            if let poolOutcome = pools.outcomes?.first(where: { $0.id == outcome.id }) {
                return (poolOutcome.percent, poolOutcome.odds)
            }
        }
        
        // Use detail's helper method if available
        if let detail = detail {
            let percent = detail.outcomePercent(for: outcome.id)
            let odds = detail.outcomeOdds(for: outcome.id)
            return (percent, odds)
        }
        
        // Final fallback to static probability
        let percent = outcome.percent ?? outcome.probability
        let odds = outcome.odds ?? (percent > 0 ? 100.0 / Double(percent) : 1.0)
        return (percent, odds)
    }

    /// Palette for multi-choice outcomes to make them visually distinct.
    func outcomeColor(for index: Int) -> (primary: Color, secondary: Color, background: Color) {
        let palette: [(Color, Color)] = [
            (Color(hex: "5B8DEF"), Color(hex: "2D5ECF")),
            (Color(hex: "34C759"), Color(hex: "1E9E45")),
            (Color(hex: "F59E0B"), Color(hex: "B45309")),
            (Color(hex: "EC4899"), Color(hex: "BE185D")),
            (Color(hex: "8B5CF6"), Color(hex: "6D28D9"))
        ]
        let colors = palette[index % palette.count]
        return (
            primary: colors.0,
            secondary: colors.1.opacity(0.7),
            background: colors.0.opacity(0.12)
        )
    }
    
    func statsRow(event: EventSummary, detail: EventDetail?, pools: PoolData?) -> some View {
        HStack(spacing: 18) {
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(TychesTheme.gold)
                Text("\(Int(pools?.total_pool ?? detail?.volume ?? event.volume))")
                    .fontWeight(.semibold)
            }
            
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(TychesTheme.primary)
                Text("\(detail?.traders_count ?? event.traders_count)")
                    .fontWeight(.semibold)
            }
            
            if let closesAt = detail?.closes_at.toDate() ?? event.closes_at.toDate() {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(closesAt.isClosingSoon ? TychesTheme.danger : TychesTheme.textSecondary)
                    Text(closesAt.timeRemaining())
                        .fontWeight(.semibold)
                        .foregroundColor(closesAt.isClosingSoon ? TychesTheme.danger : TychesTheme.textSecondary)
                }
            }
        }
        .font(.subheadline)
        .foregroundColor(TychesTheme.textSecondary)
    }
    
    /// Shows friend activity and social proof
    func friendActivityIndicator(event: EventSummary, detail: EventDetail, pools: PoolData) -> some View {
        // Show if there's recent activity (last 5 minutes)
        let tradersCount = detail.traders_count
        let isHot = tradersCount >= 3 || (pools.total_pool ?? 0) > 500
        
        if isHot {
            return AnyView(
                HStack(spacing: 8) {
                    // Pulsing live indicator
                    ZStack {
                        Circle()
                            .fill(TychesTheme.success)
                            .frame(width: 8, height: 8)
                            .opacity(0.6)
                            .scaleEffect(1.5)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: UUID())
                        
                        Circle()
                            .fill(TychesTheme.success)
                            .frame(width: 8, height: 8)
                    }
                    
                    Text("\(tradersCount) people betting")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(TychesTheme.success)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(TychesTheme.success.opacity(0.1))
                .cornerRadius(12)
            )
        }
        return AnyView(EmptyView())
    }
    
    var pagerIndicator: some View {
        Text("\(currentIndex + 1)/\(max(events.count, 1)) events")
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.vertical, 4)
    }
    
    var liveDot: some View {
        Circle()
            .fill(TychesTheme.success)
            .frame(width: 8, height: 8)
            .shadow(color: TychesTheme.success.opacity(0.4), radius: 4)
    }
    
    func isFresh(eventId: Int) -> Bool {
        guard let last = lastFetchAt[eventId] else { return false }
        return Date().timeIntervalSince(last) < 10
    }
    
    func actionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.impact(.medium)
            action()
        }) {
            Text(title)
                .font(.headline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(16)
                .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PressableStyle())
    }
    
    func chatButton(eventId: Int) -> some View {
        Button {
            HapticManager.impact(.light)
            detailEventId = eventId
            openChatTab = true
            showEventDetailSheet = true
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "bubble.left.fill")
                    .font(.title3)
                Text("Chat")
                    .font(.caption.bold())
            }
            .foregroundColor(.white)
            .frame(width: 70, height: 70)
            .background(
                LinearGradient(
                    colors: [TychesTheme.primary, TychesTheme.primary.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
            .shadow(color: TychesTheme.primary.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PressableStyle())
    }
    
    func primaryCTA(title: String, gradient: LinearGradient) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(gradient)
            .cornerRadius(14)
    }
    
    func secondaryCTA(title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(TychesTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(TychesTheme.primary.opacity(0.1))
            .cornerRadius(14)
    }
    
    func percentDelta(for eventId: Int, key: String) -> Int? {
        percentDeltas[eventId]?[key]
    }
    
    func closingSoonBadge(minutes: Int? = nil) -> some View {
        let isUrgent = (minutes ?? 15) < 5
        return HStack(spacing: 6) {
            Image(systemName: isUrgent ? "exclamationmark.triangle.fill" : "clock.fill")
                .font(.caption.weight(.bold))
            if let minutes, minutes < 60 {
                Text("\(minutes)m left")
                    .font(.caption.weight(.bold))
            } else {
                Text("Closing soon")
                    .font(.caption.weight(.semibold))
            }
        }
        .foregroundColor(isUrgent ? .red : .orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((isUrgent ? Color.red : Color.orange).opacity(0.15))
        .overlay(
            Capsule()
                .stroke(isUrgent ? Color.red.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .clipShape(Capsule())
    }
    
    func oddsDeltaBadge(delta: Int) -> some View {
        let isUp = delta > 0
        return Text("\(isUp ? "+" : "")\(delta)%")
            .font(.caption2.weight(.bold))
            .foregroundColor(isUp ? TychesTheme.success : TychesTheme.danger)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((isUp ? TychesTheme.success : TychesTheme.danger).opacity(0.15))
            .clipShape(Capsule())
    }
    
    /// Returns minutes remaining if closing within 15 minutes, nil otherwise
    func closingSoonMinutes(event: EventSummary, detail: EventDetail?) -> Int? {
        let closingString = detail?.closes_at ?? event.closes_at
        guard let date = closingString.toDate() else { return nil }
        let remaining = date.timeIntervalSinceNow
        guard remaining > 0 && remaining < 15 * 60 else { return nil }
        return max(1, Int(remaining / 60))
    }
    
    func isClosingSoon(event: EventSummary, detail: EventDetail?) -> Bool {
        closingSoonMinutes(event: event, detail: detail) != nil
    }
}

// MARK: - Data / Actions

private extension SwipeDeckView {
    /// Preload cards around the current index for instant display
    func preloadAdjacentCards(around index: Int) async {
        // Preload current, previous, and next 2 cards
        let indicesToPreload = [index - 1, index, index + 1, index + 2].filter { 
            events.indices.contains($0) && !preloadedIndices.contains($0)
        }
        
        // Mark as preloaded
        for i in indicesToPreload {
            preloadedIndices.insert(i)
        }
        
        // Fetch all in parallel
        await withTaskGroup(of: Void.self) { group in
            for i in indicesToPreload {
                group.addTask {
                    await self.preloadDetailIfNeeded(index: i)
                }
            }
        }
    }
    
    func preloadDetailIfNeeded(index: Int) async {
        guard events.indices.contains(index) else { return }
        let event = events[index]
        // Skip if already cached and fresh
        if eventDetails[event.id] != nil,
           let lastFetch = lastFetchAt[event.id],
           Date().timeIntervalSince(lastFetch) < 10 { return }
        await fetchDetailAndPools(for: event.id, force: eventDetails[event.id] == nil)
    }
    
    func reloadCurrentEventDetail() async {
        guard events.indices.contains(currentIndex) else { return }
        let eventId = events[currentIndex].id
        await fetchDetailAndPools(for: eventId, force: true)
    }
    
    func openBet(event: EventSummary, side: String) async {
        isLoadingDetail = true
        if eventDetails[event.id] == nil {
            await fetchDetailAndPools(for: event.id, force: true)
        }
        isLoadingDetail = false
        
        guard let detail = eventDetails[event.id] else { return }
        await MainActor.run {
            betEvent = detail
            selectedSide = side
            showBetSheet = true
        }
    }
    
    func placeBet(event: EventDetail) async {
        guard let side = selectedSide, let amount = Int(betAmount), amount > 0 else { return }
        isPlacingBet = true
        do {
            let bet = BetPlaceRequest(
                event_id: event.id,
                side: event.event_type == "binary" ? side : nil,
                outcome_id: event.event_type == "multiple" ? side : nil,
                amount: Double(amount)
            )
            _ = try await TychesAPI.shared.placeBet(bet)
            await session.refreshProfile()
            NotificationCenter.default.post(name: NSNotification.Name("BetPlaced"), object: nil)
            await MainActor.run {
                showBetSheet = false
            }
            // Celebration!
            HapticManager.notification(.success)
            HapticManager.impact(.heavy)
            // Show confetti
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowConfetti"),
                object: nil,
                userInfo: ["message": "Bet placed! 🎯"]
            )
            MissionTracker.track(action: .betPlaced)
        } catch {
            HapticManager.notification(.error)
        }
        isPlacingBet = false
    }
    
    func startPolling() {
        stopPolling()
        pollingTask = Task {
            while !Task.isCancelled {
                await reloadCurrentEventDetail()
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
            }
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    /// Coalesced fetch for detail + pools to keep the deck instant while refreshing in background.
    func fetchDetailAndPools(for eventId: Int, force: Bool = false) async {
        if inflightEvents.contains(eventId) { return }
        if !force, let last = lastFetchAt[eventId], Date().timeIntervalSince(last) < 3 {
            return
        }
        
        inflightEvents.insert(eventId)
        defer { inflightEvents.remove(eventId) }
        
        async let detailTask = TychesAPI.shared.fetchEventDetail(id: eventId)
        async let oddsTask = TychesAPI.shared.fetchOdds(eventId: eventId)
        
        let detailResponse = try? await detailTask
        let oddsResponse = try? await oddsTask

        await MainActor.run {
            if let detail = detailResponse?.event {
                eventDetails[eventId] = detail
            }
            if let pools = oddsResponse?.odds {
                // Force view update by creating a new dictionary
                var updated = livePools
                updated[eventId] = pools
                livePools = updated
            }
            lastFetchAt[eventId] = Date()
        }
        
        if let pools = oddsResponse?.odds {
            await detectOddsSwing(eventId: eventId, pools: pools)
        }
    }
    
    func handleDeepLinkIfNeeded() async {
        guard let targetId = deepLink.targetEventId else { return }
        
        // Try to find event in current deck
        if let idx = events.firstIndex(where: { $0.id == targetId }) {
            await MainActor.run {
                currentIndex = idx
            }
            await preloadDetailIfNeeded(index: idx)
            
            if let side = deepLink.targetSide {
                // Open bet sheet with pre-selected side
                let event = events[idx]
                await openBet(event: event, side: side)
            } else if deepLink.targetOpenChat {
                // Open event detail with chat tab
                await MainActor.run {
                    detailEventId = targetId
                    openChatTab = true
                    showEventDetailSheet = true
                }
            }
            // If neither side nor chat, just scroll to the card (already done above)
            deepLink.clear()
        } else {
            // Event not in deck - open detail sheet directly
            // First fetch the event detail
            await fetchDetailAndPools(for: targetId, force: true)
            
            await MainActor.run {
                if let side = deepLink.targetSide, let detail = eventDetails[targetId] {
                    // Open bet sheet
                    betEvent = detail
                    selectedSide = side
                    showBetSheet = true
                } else {
                    // Open event detail sheet (with chat if requested)
                    detailEventId = targetId
                    openChatTab = deepLink.targetOpenChat
                    showEventDetailSheet = true
                }
                deepLink.clear()
            }
        }
    }
    
    func detectOddsSwing(eventId: Int, pools: PoolData) async {
        guard let event = events.first(where: { $0.id == eventId }) else { return }
        var current: [String: Int] = [:]
        
        // Binary events
        if let yes = pools.yes_percent { current["YES"] = yes }
        if let no = pools.no_percent { current["NO"] = no }
        
        // Multiple choice events - ensure we track all outcomes
        if let outcomes = pools.outcomes {
            for o in outcomes {
                current[o.id] = o.percent
            }
        }
        
        // Also check detail outcomes if pools don't have them
        if let detail = eventDetails[eventId], let detailOutcomes = detail.outcomes, pools.outcomes == nil {
            for outcome in detailOutcomes {
                // Use pool percent if available, otherwise calculate from probability
                if let poolOutcome = pools.outcomes?.first(where: { $0.id == outcome.id }) {
                    current[outcome.id] = poolOutcome.percent
                } else if let percent = outcome.percent {
                    current[outcome.id] = percent
                } else {
                    current[outcome.id] = outcome.probability
                }
            }
        }
        
        let previous = lastPercents[eventId] ?? [:]
        var hasChange = false
        
        for (key, value) in current {
            let old = previous[key] ?? value
            let delta = value - old
            if abs(delta) >= 5 {
                NotificationManager.shared.scheduleOddsSwing(eventId: eventId, title: event.title, delta: delta)
            }
            
            if delta != 0 {
                hasChange = true
                await MainActor.run {
                    var deltas = percentDeltas[eventId] ?? [:]
                    deltas[key] = delta
                    percentDeltas[eventId] = deltas
                    
                    // Trigger flash effect
                    oddsFlashEvents.insert(eventId)
                }
                
                // Clear delta badge after 2.5s
                Task {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    await MainActor.run {
                        var deltas = percentDeltas[eventId] ?? [:]
                        if deltas[key] == delta {
                            deltas.removeValue(forKey: key)
                            percentDeltas[eventId] = deltas.isEmpty ? nil : deltas
                        }
                    }
                }
            }
        }
        
        // Clear flash effect after animation
        if hasChange {
            Task {
                try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
                await MainActor.run {
                    oddsFlashEvents.remove(eventId)
                }
            }
        }
        
        await MainActor.run {
            lastPercents[eventId] = current
        }
        
        // Closing soon check
        if let detail = eventDetails[eventId], let closeDate = detail.closes_at.toDate() {
            let remaining = closeDate.timeIntervalSinceNow
            if remaining > 0, remaining < 15 * 60, !closingNotified.contains(eventId) {
                NotificationManager.shared.scheduleClosingSoon(eventId: eventId, title: event.title, minutes: Int(remaining / 60))
                closingNotified.insert(eventId)
            }
        }
    }
}


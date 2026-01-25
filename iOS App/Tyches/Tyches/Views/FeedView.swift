import SwiftUI

// MARK: - Feed View (TikTok-style Immersive Events)
// Full-screen event cards with swipe-to-bet gestures

struct FeedView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var gamification = GamificationManager.shared
    @State private var events: [EventSummary] = []
    @State private var currentIndex = 0
    @State private var isLoading = true
    @State private var showStreak = true
    @State private var showEventPicker = false
    @State private var refreshTrigger = UUID() // Used to force refresh cards
    
    // Callbacks for empty state actions
    var onCreateEvent: (() -> Void)?
    var onCreateMarket: (() -> Void)?
    var onBrowseMarkets: (() -> Void)?
    
    // Check if user has markets
    private var userHasMarkets: Bool {
        guard let markets = session.profile?.markets else { return false }
        return !markets.isEmpty
    }
    
    var body: some View {
        ZStack {
            TychesTheme.background.ignoresSafeArea()
            
            if isLoading {
                loadingView
            } else if events.isEmpty {
                emptyState
            } else {
                // Vertical paging feed
                TabView(selection: $currentIndex) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        EventFeedCard(
                            event: event,
                            onRefresh: { await loadEvents() },
                            eventCount: events.count,
                            currentEventIndex: index,
                            onShowMoreEvents: { showEventPicker = true }
                        )
                        .tag(index)
                        .id("\(event.id)-\(refreshTrigger)")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
                
                // Top overlay with event indicator
                topOverlay
            }
        }
        .task {
            await loadEvents()
            // Sync gamification data for streak and record daily activity
            await gamification.recordActivity()
            await gamification.syncWithBackend()
        }
        .refreshable {
            await loadEvents()
            await session.refreshProfile()
            await gamification.syncWithBackend()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BetPlaced"))) { _ in
            Task {
                await loadEvents()
                await session.refreshProfile()
                refreshTrigger = UUID() // Force cards to refresh
            }
        }
        .sheet(isPresented: $showEventPicker) {
            EventPickerSheet(
                events: events,
                currentIndex: currentIndex,
                onSelect: { index in
                    currentIndex = index
                    showEventPicker = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(TychesTheme.background)
        }
    }
    
    // MARK: - Top Overlay
    
    private var topOverlay: some View {
        VStack {
            HStack(alignment: .top) {
                // Logo
                HStack(spacing: 8) {
                    TychesLogoSmall()
                    Text("Tyches")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(TychesTheme.textPrimary)
                }
                
                Spacer()
                
                // Event counter
                if events.count > 1 {
                    Text("\(currentIndex + 1)/\(events.count)")
                        .font(.caption.bold())
                        .foregroundColor(TychesTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(TychesTheme.surfaceElevated)
                        .clipShape(Capsule())
                }
                
                // Streak indicator
                if showStreak {
                    StreakPill(streak: gamification.streak.currentStreak)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            
            Spacer()
        }
    }
    
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            TychesAnimatedLogo()
            Text("Loading predictions...")
                .font(.subheadline)
                .foregroundColor(TychesTheme.textSecondary)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 0) {
            // Header with logo (matching topOverlay positioning)
            HStack {
                HStack(spacing: 8) {
                    TychesLogoSmall()
                    Text("Tyches")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(TychesTheme.textPrimary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            
            Spacer()
            
            // Empty state content
            VStack(spacing: 24) {
                // Chart icon
                ZStack {
                    Circle()
                        .fill(TychesTheme.primary.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(TychesTheme.primaryGradient)
                }
                
                VStack(spacing: 8) {
                    Text("No predictions yet")
                        .font(.title2.bold())
                        .foregroundColor(TychesTheme.textPrimary)
                    Text("Join or create a market to see\npredictions from your friends")
                        .font(.subheadline)
                        .foregroundColor(TychesTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // Quick action buttons
                VStack(spacing: 12) {
                    // Show Create Event first if user has markets
                    if userHasMarkets {
                        Button {
                            onCreateEvent?()
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Create an Event")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(TychesTheme.primaryGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        Button {
                            onCreateMarket?()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create a Market")
                            }
                            .font(.headline)
                            .foregroundColor(TychesTheme.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(TychesTheme.primary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    } else {
                        Button {
                            onCreateMarket?()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create a Market")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(TychesTheme.primaryGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    
                    Button {
                        onBrowseMarkets?()
                    } label: {
                        HStack {
                            Image(systemName: "person.2.fill")
                            Text("Browse Markets")
                        }
                        .font(.headline)
                        .foregroundColor(TychesTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(TychesTheme.primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .padding(.bottom, 100) // Extra margin from tab bar
    }
    
    // MARK: - Load Events

    private func loadEvents() async {
        do {
            // Use the direct events API instead of fetching each market individually
            let response = try await TychesAPI.shared.fetchEvents()
            // Only show open events, sorted by activity (volume * traders)
            events = response.events
                .filter { $0.status == "open" }
                .sorted {
                    ($0.volume * Double($0.traders_count)) > ($1.volume * Double($1.traders_count))
                }
        } catch {
            // If API fails, try fallback method with market details
            await loadEventsFallback()
        }

        isLoading = false
    }

    private func loadEventsFallback() async {
        var allEvents: [EventSummary] = []

        // Load events from ALL markets the user is in (fallback method)
        if let markets = session.profile?.markets {
            for market in markets {
                do {
                    let marketDetail = try await TychesAPI.shared.fetchMarketDetail(id: market.id)
                    // Only add open events
                    let openEvents = marketDetail.events.filter { $0.status == "open" }
                    allEvents.append(contentsOf: openEvents)
                } catch {
                    // Continue with other markets
                }
            }
        }

        // Remove duplicates and sort by activity
        let uniqueEvents = Array(Set(allEvents.map { $0.id })).compactMap { id in
            allEvents.first { $0.id == id }
        }

        events = uniqueEvents.sorted {
            ($0.volume * Double($0.traders_count)) > ($1.volume * Double($1.traders_count))
        }
    }
}

// MARK: - Event Picker Sheet

struct EventPickerSheet: View {
    let events: [EventSummary]
    let currentIndex: Int
    let onSelect: (Int) -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        EventPickerRow(
                            event: event,
                            isSelected: index == currentIndex
                        )
                        .onTapGesture {
                            onSelect(index)
                            HapticManager.selection()
                        }
                    }
                }
                .padding()
            }
            .background(TychesTheme.background)
            .navigationTitle("All Events (\(events.count))")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Event Picker Row

struct EventPickerRow: View {
    let event: EventSummary
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            // Type indicator with chart emoji based on leading odds
            ZStack {
                Circle()
                    .fill(event.event_type == "multiple" ? TychesTheme.primary.opacity(0.15) : 
                          (event.currentYesPercent > 50 ? TychesTheme.success.opacity(0.15) : TychesTheme.danger.opacity(0.15)))
                    .frame(width: 44, height: 44)
                
                Text(event.event_type == "multiple" ? "🎯" : (event.currentYesPercent >= 50 ? "📉" : "📈"))
                    .font(.system(size: 20))
            }
            
            // Event info
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(TychesTheme.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    if event.event_type == "binary" {
                        Text("YES \(event.currentYesPercent)%")
                            .font(.caption.bold())
                            .foregroundColor(TychesTheme.success)
                        Text("NO \(event.currentNoPercent)%")
                            .font(.caption.bold())
                            .foregroundColor(TychesTheme.danger)
                    } else {
                        Text("Multiple choice")
                            .font(.caption)
                            .foregroundColor(TychesTheme.textSecondary)
                    }
                    
                    Text("•")
                        .foregroundColor(TychesTheme.textTertiary)
                    
                    Text("\(event.traders_count) traders")
                        .font(.caption)
                        .foregroundColor(TychesTheme.textTertiary)
                }
            }
            
            Spacer()
            
            // Selected indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(TychesTheme.primary)
                    .font(.title3)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(TychesTheme.textTertiary)
                    .font(.caption)
            }
        }
        .padding(14)
        .background(isSelected ? TychesTheme.primary.opacity(0.08) : TychesTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? TychesTheme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Event Feed Card (Full Screen)

struct EventFeedCard: View {
    let event: EventSummary
    let onRefresh: () async -> Void
    let eventCount: Int
    let currentEventIndex: Int
    let onShowMoreEvents: () -> Void
    @EnvironmentObject var session: SessionStore
    @State private var dragOffset: CGFloat = 0
    @State private var showChatSheet = false
    @State private var selectedOutcome: String?
    @State private var hasVoted = false
    @State private var eventDetail: EventDetail?
    @State private var isLoadingDetail = false
    
    // Use a separate state for bet sheet with the side included
    @State private var betSheetSide: String? = nil
    
    private var showBetSheet: Binding<Bool> {
        Binding(
            get: { betSheetSide != nil || selectedOutcome != nil },
            set: { if !$0 { betSheetSide = nil; selectedOutcome = nil } }
        )
    }
    
    private let swipeThreshold: CGFloat = 100
    
    // Check if this is a multiple choice event
    private var isMultipleChoice: Bool {
        event.event_type == "multiple"
    }
    
    // Check if there are more events to browse
    private var hasMoreEvents: Bool {
        eventCount > 1
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background gradient based on event
                backgroundGradient
                    .ignoresSafeArea()
                
                // Content
                VStack {
                    Spacer()
                    
                    // Event content
                    eventContent
                        .padding(.horizontal, 24)
                        .offset(x: dragOffset * 0.3)
                    
                    Spacer()
                    
                    // Bottom section
                    bottomActions
                        .padding(.bottom, 85)
                }
                
                // Swipe indicators
                swipeIndicators
            }
            .gesture(swipeGesture)
        }
        .sheet(isPresented: showBetSheet) {
            SwipeBetSheet(
                event: event,
                side: betSheetSide,
                outcomeId: selectedOutcome,
                outcomeName: getOutcomeName(),
                onBetPlaced: {
                    Task { await onRefresh() }
                }
            )
            .environmentObject(session)
        }
        .sheet(isPresented: $showChatSheet) {
            EventChatSheet(eventId: event.id, eventTitle: event.title)
                .environmentObject(session)
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            // Base
            TychesTheme.background
            
            // Gradient overlay
            LinearGradient(
                colors: [
                    TychesTheme.primary.opacity(0.15),
                    TychesTheme.background,
                    TychesTheme.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // YES side glow (swipe right - glow on RIGHT)
            if dragOffset > 30 {
                TychesTheme.success.opacity(Double(dragOffset / 300))
                    .blur(radius: 100)
                    .offset(x: 150)
            }
            
            // NO side glow (swipe left - glow on LEFT)
            if dragOffset < -30 {
                TychesTheme.danger.opacity(Double(-dragOffset / 300))
                    .blur(radius: 100)
                    .offset(x: -150)
            }
        }
    }
    
    // MARK: - Event Content
    
    private var eventContent: some View {
        VStack(spacing: 24) {
            // Market badge
            if let marketName = event.market_name {
                HStack(spacing: 6) {
                    Text("🎯")
                    Text(marketName)
                        .font(.subheadline.weight(.medium))
                }
                .foregroundColor(TychesTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(TychesTheme.surfaceElevated)
                .clipShape(Capsule())
                .padding(.top, 40) // Add margin below the header
            }
            
            // Question
            Text(event.title)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(TychesTheme.textPrimary)
                .lineLimit(4)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            // Current odds
            oddsDisplay
            
            // Stats with social proof
            statsRow
            
            // Social proof: Live activity indicator
            if event.traders_count >= 3 {
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
                    
                    Text("\(event.traders_count) people betting")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(TychesTheme.success)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(TychesTheme.success.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Odds Display
    
    private var oddsDisplay: some View {
        Group {
            if isMultipleChoice {
                // Multiple choice outcomes
                multipleChoiceDisplay
            } else {
                // Binary YES/NO display
                binaryOddsDisplay
            }
        }
    }
    
    // MARK: - Binary Odds Display (NO/red on LEFT, YES/green on RIGHT)
    
    // MARK: - Odds Display Helpers (use eventDetail when available)
    
    private var displayYesPercent: Int {
        eventDetail?.currentYesPercent ?? event.currentYesPercent
    }
    
    private var displayNoPercent: Int {
        eventDetail?.currentNoPercent ?? event.currentNoPercent
    }
    
    private var displayYesOdds: Double {
        eventDetail?.yesOdds ?? event.yesOdds
    }
    
    private var displayNoOdds: Double {
        eventDetail?.noOdds ?? event.noOdds
    }
    
    private var binaryOddsDisplay: some View {
        HStack(spacing: 12) {
            // NO (LEFT side - red, swipe left = NO)
            VStack(spacing: 4) {
                Text("NO")
                    .font(.caption.bold())
                    .foregroundColor(TychesTheme.danger)
                Text("\(displayNoPercent)%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(TychesTheme.danger)
                Text("\(displayNoOdds, specifier: "%.2f")x")
                    .font(.caption)
                    .foregroundColor(TychesTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(TychesTheme.danger.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Divider
            Rectangle()
                .fill(TychesTheme.textTertiary.opacity(0.3))
                .frame(width: 1, height: 50)
            
            // YES (RIGHT side - green, swipe right = YES)
            VStack(spacing: 4) {
                Text("YES")
                    .font(.caption.bold())
                    .foregroundColor(TychesTheme.success)
                Text("\(displayYesPercent)%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(TychesTheme.success)
                Text("\(displayYesOdds, specifier: "%.2f")x")
                    .font(.caption)
                    .foregroundColor(TychesTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(TychesTheme.success.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .task {
            // Load event detail to get proper pool data
            await loadEventDetail()
        }
    }
    
    // MARK: - Multiple Choice Display
    
    private var multipleChoiceDisplay: some View {
        Group {
            if let outcomes = eventDetail?.outcomes, !outcomes.isEmpty {
                // Use ScrollView for long option lists
                if outcomes.count > 4 {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(outcomes) { outcome in
                                MultipleChoiceOptionRow(
                                    outcome: outcome,
                                    isSelected: selectedOutcome == outcome.id,
                                    onSelect: {
                                        selectedOutcome = outcome.id
                                        HapticManager.selection()
                                    },
                                    eventDetail: eventDetail
                                )
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .frame(maxHeight: 400)
                } else {
                    VStack(spacing: 10) {
                        ForEach(outcomes) { outcome in
                            MultipleChoiceOptionRow(
                                outcome: outcome,
                                isSelected: selectedOutcome == outcome.id,
                                onSelect: {
                                    selectedOutcome = outcome.id
                                    HapticManager.selection()
                                },
                                eventDetail: eventDetail
                            )
                        }
                    }
                }
            } else {
                // Loading or no outcomes
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading options...")
                        .font(.subheadline)
                        .foregroundColor(TychesTheme.textSecondary)
                }
                .padding()
            }
        }
        .task {
            await loadEventDetail()
        }
    }
    
    private func loadEventDetail() async {
        guard eventDetail == nil else { return }
        isLoadingDetail = true
        do {
            let response = try await TychesAPI.shared.fetchEventDetail(id: event.id)
            eventDetail = response.event
        } catch {
            // Handle error silently
        }
        isLoadingDetail = false
    }
    
    private func getOutcomeName() -> String? {
        guard let outcomeId = selectedOutcome,
              let outcomes = eventDetail?.outcomes else { return nil }
        return outcomes.first { $0.id == outcomeId }?.label
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 18) {
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(TychesTheme.gold)
                Text("\(Int(event.totalPool))")
                    .fontWeight(.semibold)
            }
            
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(TychesTheme.primary)
                Text("\(event.traders_count)")
                    .fontWeight(.semibold)
            }
            
            if let closesAt = event.closes_at.toDate() {
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
    
    // MARK: - Bottom Actions
    
    private var bottomActions: some View {
        VStack(spacing: 12) {
            // Swipe hint (only for binary events)
            if !hasVoted && !isMultipleChoice {
                Text("Swipe to bet")
                    .font(.caption.bold())
                    .foregroundColor(TychesTheme.textTertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(TychesTheme.surfaceElevated)
                    .clipShape(Capsule())
            }
            
            if isMultipleChoice {
                // Multiple choice: just show chat button
                HStack(spacing: 32) {
                    ActionButton(
                        icon: "bubble.left.fill",
                        color: TychesTheme.primary,
                        label: "Chat",
                        size: .small
                    ) {
                        showChatSheet = true
                    }
                }
                
                Text("Tap an option above to bet")
                    .font(.caption)
                    .foregroundColor(TychesTheme.textTertiary)
            } else {
                // Binary: NO, Chat, YES buttons
                HStack(spacing: 44) {
                    // NO button (LEFT side)
                    ActionButton(
                        icon: "xmark",
                        color: TychesTheme.danger,
                        label: "NO"
                    ) {
                        betSheetSide = "NO"
                        HapticManager.impact(.medium)
                    }
                    
                    // Gossip button (smaller)
                    ActionButton(
                        icon: "bubble.left.fill",
                        color: TychesTheme.primary,
                        label: "Chat",
                        size: .small
                    ) {
                        showChatSheet = true
                    }
                    
                    // YES button (RIGHT side)
                    ActionButton(
                        icon: "checkmark",
                        color: TychesTheme.success,
                        label: "YES"
                    ) {
                        betSheetSide = "YES"
                        HapticManager.impact(.medium)
                    }
                }
            }
            
            // More events arrow button
            if hasMoreEvents {
                Button {
                    onShowMoreEvents()
                    HapticManager.selection()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 16, weight: .semibold))
                        Text("\(currentEventIndex + 1)/\(eventCount) events")
                            .font(.caption2.bold())
                    }
                    .foregroundColor(TychesTheme.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(TychesTheme.surfaceElevated.opacity(0.8))
                    .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Swipe Indicators (only for binary events)
    
    private var swipeIndicators: some View {
        Group {
            if !isMultipleChoice {
                HStack {
                    // Left indicator (NO - swipe left reveals this)
                    ZStack {
                        Circle()
                            .fill(TychesTheme.danger)
                            .frame(width: 80, height: 80)
                            .opacity(dragOffset < -30 ? Double(-dragOffset / 150) : 0)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(dragOffset < -50 ? 1 : 0)
                    }
                    .offset(x: min(0, dragOffset + 100))
                    
                    Spacer()
                    
                    // Right indicator (YES - swipe right reveals this)
                    ZStack {
                        Circle()
                            .fill(TychesTheme.success)
                            .frame(width: 80, height: 80)
                            .opacity(dragOffset > 30 ? Double(dragOffset / 150) : 0)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(dragOffset > 50 ? 1 : 0)
                    }
                    .offset(x: max(0, dragOffset - 100))
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Swipe Gesture (only for binary events)
    
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow swipe for binary events
                if !isMultipleChoice {
                    dragOffset = value.translation.width
                }
            }
            .onEnded { value in
                // Only process swipe for binary events
                guard !isMultipleChoice else {
                    dragOffset = 0
                    return
                }
                
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    if value.translation.width > swipeThreshold {
                        // Swiped RIGHT = YES (green, positive)
                        betSheetSide = "YES"
                        HapticManager.notification(.success)
                    } else if value.translation.width < -swipeThreshold {
                        // Swiped LEFT = NO (red, negative)
                        betSheetSide = "NO"
                        HapticManager.notification(.warning)
                    }
                    dragOffset = 0
                }
            }
    }
}

// MARK: - Multiple Choice Option Row

struct MultipleChoiceOptionRow: View {
    let outcome: EventOutcome
    let isSelected: Bool
    let onSelect: () -> Void
    let eventDetail: EventDetail? // Add event detail for computed odds
    
    // Generate a color based on outcome id for variety
    private var optionColor: Color {
        let colors: [Color] = [TychesTheme.primary, TychesTheme.success, TychesTheme.accent, TychesTheme.secondary, TychesTheme.warning]
        let idInt = Int(outcome.id) ?? 0
        return colors[idInt % colors.count]
    }
    
    // Use computed odds from eventDetail if available
    private var displayPercent: Int {
        if let detail = eventDetail {
            return detail.outcomePercent(for: outcome.id)
        }
        return outcome.percent ?? outcome.probability
    }
    
    private var displayOdds: Double {
        if let detail = eventDetail {
            return detail.outcomeOdds(for: outcome.id)
        }
        return outcome.odds ?? (outcome.probability > 0 ? 100.0 / Double(outcome.probability) : 1.0)
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Option label
                Text(outcome.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(TychesTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Percentage and odds
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(displayPercent)%")
                        .font(.title3.bold())
                        .foregroundColor(optionColor)
                    
                    Text("\(displayOdds, specifier: "%.2f")x")
                        .font(.caption)
                        .foregroundColor(TychesTheme.textSecondary)
                }
                
                // Bet indicator
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(TychesTheme.textTertiary)
            }
            .padding()
            .background(optionColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? optionColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let color: Color
    let label: String
    var size: ActionButtonSize = .large
    let action: () -> Void
    
    enum ActionButtonSize {
        case large  // YES/NO buttons
        case small  // Chat button
        
        var frameSize: CGFloat {
            switch self {
            case .large: return 68
            case .small: return 50
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .large: return 28
            case .small: return 20
            }
        }
        
        var shadowRadius: CGFloat {
            switch self {
            case .large: return 12
            case .small: return 8
            }
        }
    }
    
    var body: some View {
        Button(action: {
            action()
            HapticManager.impact(.medium)
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: size.iconSize, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: size.frameSize, height: size.frameSize)
                    .background(color)
                    .clipShape(Circle())
                    .shadow(color: color.opacity(0.5), radius: size.shadowRadius)
                
                Text(label)
                    .font(.caption2.bold())
                    .foregroundColor(TychesTheme.textSecondary)
            }
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Swipe Bet Sheet

struct SwipeBetSheet: View {
    let event: EventSummary
    let side: String?
    let outcomeId: String?
    let outcomeName: String?
    let onBetPlaced: () -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionStore
    @State private var amount: Double = 100
    @State private var isPlacing = false
    @State private var errorMessage: String?
    
    // Determine if this is a multiple choice bet
    private var isMultipleChoice: Bool {
        outcomeId != nil
    }
    
    // Display text for the bet
    private var betDisplayText: String {
        if let outcomeName = outcomeName {
            return outcomeName
        }
        return side ?? "YES"
    }
    
    // Color for the bet
    private var betColor: Color {
        if isMultipleChoice {
            return TychesTheme.primary
        }
        return (side ?? "YES") == "YES" ? TychesTheme.success : TychesTheme.danger
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(TychesTheme.danger)
                        .clipShape(Capsule())
                }
                
                // Header
                VStack(spacing: 8) {
                    if isMultipleChoice {
                        Text("🎯")
                            .font(.system(size: 60))
                    } else {
                        Text((side ?? "YES") == "YES" ? "✅" : "❌")
                            .font(.system(size: 60))
                    }
                    
                    Text("Bet \(betDisplayText)")
                        .font(.title.bold())
                        .foregroundColor(betColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Question
                Text(event.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(TychesTheme.textSecondary)
                    .padding(.horizontal)
                
                // Amount selector
                VStack(spacing: 16) {
                    Text("\(Int(amount))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    
                    Text("tokens")
                        .font(.subheadline)
                        .foregroundColor(TychesTheme.textSecondary)
                    
                    // Quick amounts
                    HStack(spacing: 12) {
                        ForEach([50, 100, 250, 500], id: \.self) { quickAmount in
                            Button {
                                amount = Double(quickAmount)
                                HapticManager.selection()
                            } label: {
                                Text("\(quickAmount)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(amount == Double(quickAmount) ? .white : TychesTheme.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(amount == Double(quickAmount) ? TychesTheme.primary : TychesTheme.surfaceElevated)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    
                    // Slider (max is user's balance)
                    Slider(value: $amount, in: 10...max(10, Double(session.profile?.user.tokens_balance ?? 1000)), step: 10)
                        .tint(betColor)
                        .padding(.horizontal)
                    
                    // Balance indicator
                    HStack {
                        Text("Your balance:")
                            .font(.caption)
                            .foregroundColor(TychesTheme.textTertiary)
                        Spacer()
                        Text("\(Int(session.profile?.user.tokens_balance ?? 0)) tokens")
                            .font(.caption.bold())
                            .foregroundColor(TychesTheme.textSecondary)
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(TychesTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)
                
                // Potential return
                let odds = isMultipleChoice ? 2.0 : ((side ?? "YES") == "YES" ? event.yesOdds : event.noOdds)
                let potentialReturn = amount * odds
                
                VStack(spacing: 8) {
                    Text("Potential return")
                        .font(.caption)
                        .foregroundColor(TychesTheme.textSecondary)
                    Text("+\(Int(potentialReturn - amount)) tokens")
                        .font(.title2.bold())
                        .foregroundColor(TychesTheme.success)
                    
                    // Parimutuel explanation
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                        Text("Pool-based odds • Final payout depends on all bets")
                            .font(.caption2)
                    }
                    .foregroundColor(TychesTheme.textTertiary)
                }
                
                Spacer()
                
                // Place bet button
                Button {
                    placeBet()
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
                        isMultipleChoice ? TychesTheme.primaryGradient :
                        ((side ?? "YES") == "YES" ? TychesTheme.successGradient : TychesTheme.dangerGradient)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isPlacing)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(TychesTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(TychesTheme.background)
    }
    
    private func placeBet() {
        isPlacing = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await TychesAPI.shared.placeBet(
                    eventId: event.id,
                    side: isMultipleChoice ? nil : side,
                    outcomeId: outcomeId,
                    amount: amount
                )
                HapticManager.notification(.success)
                HapticManager.impact(.heavy)
                
                // Show confetti celebration
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowConfetti"),
                    object: nil,
                    userInfo: ["message": "Bet placed! 🎯"]
                )
                
                // Refresh session profile to update token balance
                await session.refreshProfile()
                
                // Post notification to refresh data
                NotificationCenter.default.post(name: NSNotification.Name("BetPlaced"), object: nil)
                
                // Call the refresh callback
                onBetPlaced()
                
                dismiss()
            } catch let TychesError.server(msg) {
                errorMessage = msg
                HapticManager.notification(.error)
                isPlacing = false
            } catch {
                errorMessage = "Failed to place bet. Please try again."
                HapticManager.notification(.error)
                isPlacing = false
            }
        }
    }
}

// MARK: - Supporting Views

struct TychesLogoSmall: View {
    var body: some View {
        Image("iOS-iOS-Default-1024x1024")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StreakPill: View {
    let streak: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Text("🔥")
            Text("\(streak)")
                .font(.subheadline.bold())
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            streak > 0 
                ? LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [TychesTheme.surfaceElevated, TychesTheme.surfaceElevated], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(Capsule())
    }
}

// MARK: - Event Chat Sheet

struct EventChatSheet: View {
    let eventId: Int
    let eventTitle: String
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionStore
    @State private var messages: [GossipMessage] = []
    @State private var newMessage = ""
    @State private var isLoading = true
    @State private var isSending = false
    @FocusState private var isMessageFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Event title header
                VStack(spacing: 4) {
                    Text(eventTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(TychesTheme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(TychesTheme.surfaceElevated)
                
                // Messages
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if messages.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Text("💬")
                            .font(.system(size: 60))
                        Text("No messages yet")
                            .font(.headline)
                            .foregroundColor(TychesTheme.textSecondary)
                        Text("Be the first to share your thoughts!")
                            .font(.subheadline)
                            .foregroundColor(TychesTheme.textTertiary)
                    }
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(messages) { message in
                                    ChatMessageRow(message: message, isOwn: message.user_id == session.currentUser?.id)
                                        .id(message.id)
                                }
                            }
                            .padding()
                        }
                        .onAppear {
                            // Scroll to bottom on initial load
                            if let lastMessage = messages.last {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let lastMessage = messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                
                // Message input
                HStack(spacing: 12) {
                    TextField("Share your thoughts...", text: $newMessage, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(TychesTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .lineLimit(1...4)
                        .focused($isMessageFocused)
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: isSending ? "ellipsis" : "paperplane.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(newMessage.isEmpty ? TychesTheme.textTertiary : TychesTheme.primary)
                            .clipShape(Circle())
                    }
                    .disabled(newMessage.isEmpty || isSending)
                }
                .padding()
                .background(TychesTheme.cardBackground)
            }
            .background(TychesTheme.background)
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(TychesTheme.background)
        .task {
            await loadMessages()
        }
    }
    
    private func loadMessages() async {
        do {
            let response = try await TychesAPI.shared.fetchGossip(eventId: eventId)
            messages = response.messages
        } catch {
            // Handle error silently
        }
        isLoading = false
    }
    
    private func sendMessage() {
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSending = true
        let messageText = newMessage
        newMessage = ""
        
        Task {
            do {
                let request = GossipPostRequest(event_id: eventId, message: messageText)
                let response = try await TychesAPI.shared.postGossip(request)
                // Add the new message to the list
                let newGossip = GossipMessage(
                    id: response.id,
                    message: messageText,
                    created_at: ISO8601DateFormatter().string(from: Date()),
                    user_id: session.currentUser?.id ?? 0,
                    user_name: session.currentUser?.name,
                    user_username: session.currentUser?.username
                )
                messages.append(newGossip)
                HapticManager.notification(.success)
            } catch {
                // Restore message on error
                newMessage = messageText
                HapticManager.notification(.error)
            }
            isSending = false
        }
    }
}

// MARK: - Chat Message Row

struct ChatMessageRow: View {
    let message: GossipMessage
    let isOwn: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isOwn { Spacer(minLength: 60) }
            
            if !isOwn {
                // Avatar
                Circle()
                    .fill(TychesTheme.avatarGradient(for: message.user_id))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String((message.user_name ?? message.user_username ?? "U").prefix(1)).uppercased())
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: isOwn ? .trailing : .leading, spacing: 4) {
                if !isOwn {
                    Text(message.user_name ?? message.user_username ?? "User")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(TychesTheme.textSecondary)
                }
                
                Text(message.message)
                    .font(.body)
                    .foregroundColor(isOwn ? .white : TychesTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isOwn ? TychesTheme.primary : TychesTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                Text(message.created_at.toRelativeTime())
                    .font(.caption2)
                    .foregroundColor(TychesTheme.textTertiary)
            }
            
            if !isOwn { Spacer(minLength: 60) }
        }
    }
}

// Date extensions are now available in Helpers/DateFormatters.swift

#Preview {
    FeedView()
        .environmentObject(SessionStore())
}


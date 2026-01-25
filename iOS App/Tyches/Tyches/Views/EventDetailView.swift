import SwiftUI
import Contacts
import UIKit

struct EventDetailView: View {
    let eventID: Int
    let initialTab: Int
    @State private var event: EventDetail?
    @State private var gossip: [GossipMessage] = []
    @State private var activity: [ActivityBet] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showBetSheet = false
    @State private var selectedSide: String? = nil
    @State private var betAmount: String = "100"
    @State private var isPlacingBet = false
    @State private var showToast: String?
    @State private var showConfetti = false
    @State private var selectedTab: Int
    @State private var showInviteSheet = false
    @State private var inviteEvent: EventDetail?
    @EnvironmentObject var session: SessionStore
    @StateObject private var gamification = GamificationManager.shared
    @State private var replyToMessage: GossipMessage?
    @State private var optimisticGossip: [GossipMessage] = []
    @State private var failedLocalIds: Set<String> = []
    @State private var livePools: PoolData?
    
    init(eventID: Int, initialTab: Int = 0) {
        self.eventID = eventID
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }
    
    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    // ALWAYS SHOW INVITE BUTTON AT TOP - NEVER HIDDEN
                    Button {
                        if let event = event {
                            inviteEvent = event
                            showInviteSheet = true
                            HapticManager.impact(.medium)
                        } else {
                            // Load event first, then show sheet
                            Task {
                                await loadEvent()
                                if let event = event {
                                    inviteEvent = event
                                    showInviteSheet = true
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.badge.plus.fill")
                                .font(.title2)
                            Text("INVITE PEOPLE TO THIS EVENT")
                                .font(.headline.weight(.bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.purple.opacity(0.5), radius: 12, x: 0, y: 6)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    if isLoading {
                        LoadingView()
                    } else if let error = errorMessage {
                        ErrorView(message: error, onRetry: {
                            Task { await loadEvent() }
                        })
                    } else if let event = event {
                        eventHeader(event)
                        tradeCard(event)
                        
                        // Tab picker
                        Picker("Section", selection: $selectedTab) {
                            Text("Activity").tag(0)
                            Text("Gossip (\(gossip.count))").tag(1)
                        }
                        .pickerStyle(.segmented)
                        
                        if selectedTab == 0 {
                            activitySection
                        } else {
                            gossipSection
                        }
                    }
                }
                .padding()
                .padding(.bottom, 100)
            }
            .navigationTitle("Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if let event = event {
                            inviteEvent = event
                            showInviteSheet = true
                        } else {
                            Task {
                                await loadEvent()
                                if let event = event {
                                    inviteEvent = event
                                    showInviteSheet = true
                                }
                            }
                        }
                        HapticManager.impact(.medium)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.badge.plus.fill")
                            Text("Invite")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(TychesTheme.primaryGradient)
                        .cornerRadius(20)
                    }
                }
            }
        .task {
            gamification.recordEventView()
            await loadEvent()
            
            // Track event view
            if let event = event {
                Analytics.shared.trackEventViewed(eventId: event.id, eventTitle: event.title)
            }
        }
        .onAppear {
            Analytics.shared.trackScreenView("EventDetail")
        }
            .refreshable {
                await loadEvent()
                await session.refreshProfile()
            }
            .sheet(isPresented: $showBetSheet) {
                if let event = event {
                    BetSheet(
                        event: event,
                        selectedSide: $selectedSide,
                        betAmount: $betAmount,
                        isPlacingBet: $isPlacingBet,
                        onPlaceBet: { await placeBet() }
                    )
                }
            }
            .sheet(isPresented: $showInviteSheet) {
                if let eventToInvite = inviteEvent ?? event {
                    InviteToEventSheet(event: eventToInvite, onInviteSent: {
                        Task {
                            await loadEvent()
                        }
                    })
                    .environmentObject(session)
                }
            }
            
            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = showToast {
                ToastView(message: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation {
                                showToast = nil
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - Loading
    
    private func loadEvent() async {
        isLoading = true
        errorMessage = nil
        do {
            async let detailTask = TychesAPI.shared.fetchEventDetail(id: eventID)
            async let oddsTask = TychesAPI.shared.fetchOdds(eventId: eventID)
            
            let response = try await detailTask
            let oddsResponse = try? await oddsTask
            
            await MainActor.run {
                withAnimation {
                    event = response.event
                }
                if let pools = oddsResponse?.odds {
                    livePools = pools
                } else {
                    livePools = response.event.pools
                }
            }
            await loadGossip()
            await loadActivity()
        } catch let TychesError.unauthorized(msg) {
            errorMessage = msg.isEmpty ? "Session expired. Please log in again." : msg
        } catch let TychesError.server(msg) {
            errorMessage = msg
        } catch let TychesError.httpStatus(code) {
            if code == 404 {
                errorMessage = "Event not found"
            } else if code == 403 {
                errorMessage = "You don't have access to this event"
            } else {
                errorMessage = "Server error (code \(code))"
            }
        } catch let error as DecodingError {
            errorMessage = "Invalid response format"
            print("EventDetail decoding error: \(error)")
        } catch let error as URLError {
            if error.code == .notConnectedToInternet {
                errorMessage = "No internet connection"
            } else if error.code == .timedOut {
                errorMessage = "Request timed out"
            } else {
                errorMessage = "Network error: \(error.localizedDescription)"
            }
        } catch {
            errorMessage = "Failed to load event: \(error.localizedDescription)"
            print("EventDetail load error: \(error)")
        }
        isLoading = false
    }
    
    private func loadGossip() async {
        do {
            let response = try await TychesAPI.shared.fetchGossip(eventId: eventID)
            gossip = response.messages
        } catch {
            // Silently fail for gossip
        }
    }
    
    @discardableResult
    private func sendGossipMessage(_ text: String, replyToId: Int?, reuseLocalId: String? = nil) async -> Result<Void, Error> {
        let formatter = ISO8601DateFormatter()
        let localId = reuseLocalId ?? UUID().uuidString
        
        let pending = GossipMessage(
            id: reuseLocalId == nil ? Int.random(in: -1_000_000 ... -1) : (optimisticGossip.first(where: { $0.localId == reuseLocalId })?.id ?? Int.random(in: -1_000_000 ... -1)),
            message: text,
            created_at: formatter.string(from: Date()),
            user_id: session.profile?.user.id ?? 0,
            user_name: session.profile?.user.name,
            user_username: session.profile?.user.username,
            reply_to_id: replyToId,
            localId: localId
        )
        
        await MainActor.run {
            addPendingGossip(pending)
        }
        
        do {
            let response = try await TychesAPI.shared.postGossipThreaded(eventId: eventID, message: text, replyTo: replyToId)
            let confirmed = GossipMessage(
                id: response.id,
                message: response.message,
                created_at: response.created_at,
                user_id: response.user_id,
                user_name: session.profile?.user.name,
                user_username: session.profile?.user.username,
                reply_to_id: replyToId,
                localId: nil
            )
            await MainActor.run {
                handleGossipResult(localId: localId, result: .success(confirmed))
            }
            MissionTracker.track(action: .chatPosted)
            Analytics.shared.trackGossipPosted(eventId: eventID)
            return .success(())
        } catch {
            await MainActor.run {
                handleGossipResult(localId: localId, result: .failure(error))
            }
            return .failure(error)
        }
    }
    
    private func retryPending(_ message: GossipMessage) {
        guard let localId = message.localId else { return }
        failedLocalIds.remove(localId)
        Task {
            _ = await sendGossipMessage(message.message, replyToId: message.reply_to_id, reuseLocalId: localId)
        }
    }
    
    private func addPendingGossip(_ message: GossipMessage) {
        optimisticGossip.removeAll { $0.localId == message.localId }
        optimisticGossip.insert(message, at: 0)
    }
    
    private func handleGossipResult(localId: String, result: Result<GossipMessage, Error>) {
        switch result {
        case .success(let confirmed):
            optimisticGossip.removeAll { $0.localId == localId }
            failedLocalIds.remove(localId)
            gossip.insert(confirmed, at: 0)
        case .failure:
            failedLocalIds.insert(localId)
        }
    }
    
    private func loadActivity() async {
        do {
            let response = try await TychesAPI.shared.fetchEventActivity(eventId: eventID)
            activity = response.bets
        } catch {
            // Silently fail
        }
    }
    
    // MARK: - Header
    
    private func eventHeader(_ event: EventDetail) -> some View {
        VStack(spacing: 0) {
            // Status badge at top
            HStack {
                EventStatusBadge(status: event.status)
                Spacer()
                
                Button {
                    inviteEvent = event
                    showInviteSheet = true
                    HapticManager.impact(.medium)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.badge.plus.fill")
                        Text("Invite")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: Color.purple.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.bottom, 16)
            
            // Event Title Card
            VStack(spacing: 16) {
                // Market info
            HStack(spacing: 8) {
                if let emoji = event.market_avatar_emoji {
                    Text(emoji)
                        .font(.title3)
                }
                Text(event.market_name ?? "Market")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(TychesTheme.textSecondary)
                
                Spacer()
                
                // Time remaining
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(formatDate(event.closes_at))
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(TychesTheme.textTertiary)
            }
                
            // Title
            Text(event.title)
                .font(.title3.bold())
                .foregroundColor(TychesTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
                
                // Probability Bar
                probabilityBar(event)
                
            // Stats
            if Int(event.volume) == 0 && event.traders_count == 0 {
                HStack {
                    Text("Be the first to bet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(TychesTheme.primary)
                    Spacer()
                }
            } else {
                HStack(spacing: 24) {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(TychesTheme.gold)
                        Text("\(Int(event.volume))")
                            .font(.subheadline.weight(.semibold))
                        Text("pool")
                            .font(.caption)
                            .foregroundColor(TychesTheme.textTertiary)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(TychesTheme.primary)
                        Text("\(event.traders_count)")
                            .font(.subheadline.weight(.semibold))
                        Text("traders")
                            .font(.caption)
                            .foregroundColor(TychesTheme.textTertiary)
                    }
                    
                    Spacer()
                }
                .foregroundColor(TychesTheme.textPrimary)
            }
                
                // Invite Button - Prominent
                if (event.can_invite ?? false) && event.status != "resolved" && event.status != "closed" {
                    Button {
                        inviteEvent = event
                        showInviteSheet = true
                        HapticManager.impact(.medium)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.badge.plus")
                                .font(.headline)
                            Text("Invite People")
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(TychesTheme.primaryGradient)
                        .cornerRadius(16)
                        .shadow(color: TychesTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(16)
            .background(TychesTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        }
    }
    
    // MARK: - Probability Bar
    
    private func probabilityBar(_ event: EventDetail) -> some View {
        let pools = livePools ?? event.pools
        // Only use pool data if there are actual bets
        let hasBets = (pools?.total_pool ?? 0) > 0
        let yesPercent = (hasBets ? pools?.yes_percent : nil) ?? event.currentYesPercent
        let noPercent = (hasBets ? pools?.no_percent : nil) ?? event.currentNoPercent
        return GeometryReader { geo in
            HStack(spacing: 0) {
                // YES side
                HStack {
                    Text("\(yesPercent)%")
                        .font(.subheadline.bold())
                    Text("YES")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(width: geo.size.width * CGFloat(yesPercent) / 100, alignment: .center)
                .frame(height: 36)
                .background(TychesTheme.success)
                
                // NO side
                HStack {
                    Text("\(noPercent)%")
                        .font(.subheadline.bold())
                    Text("NO")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(TychesTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 36)
                .background(TychesTheme.danger.opacity(0.15))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(height: 36)
    }
    
    // MARK: - Trade Card
    
    private func tradeCard(_ event: EventDetail) -> some View {
        // If resolved, show a read-only summary instead of bet buttons
        if event.status == "resolved" {
            return AnyView(resolvedSummary(event))
        }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Live trading")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(event.status.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundColor(TychesTheme.textSecondary)
                }
                
                // Trade Buttons - use REAL pool-based odds
                let pools = livePools ?? event.pools
                
                if event.event_type == "binary" {
                    HStack(spacing: 12) {
                        // YES Button
                        Button {
                            selectedSide = "YES"
                            showBetSheet = true
                            HapticManager.impact(.medium)
                        } label: {
                            VStack(spacing: 8) {
                                Text("YES")
                                    .font(.headline.bold())
                                Text("\(String(format: "%.2f", pools?.yes_odds ?? event.yesOdds))x")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                            .background(TychesTheme.success)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // NO Button
                        Button {
                            selectedSide = "NO"
                            showBetSheet = true
                            HapticManager.impact(.medium)
                        } label: {
                            VStack(spacing: 8) {
                                Text("NO")
                                    .font(.headline.bold())
                                Text("\(String(format: "%.2f", pools?.no_odds ?? event.noOdds))x")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                            .background(TychesTheme.danger)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                } else if let outcomes = event.outcomes, let poolOutcomes = pools?.outcomes {
                    // Multi-choice with pool data
                    VStack(spacing: 10) {
                        ForEach(outcomes) { outcome in
                            let poolOutcome = poolOutcomes.first(where: { $0.id == outcome.id })
                            OutcomeButton(
                                outcome: outcome,
                                poolData: poolOutcome,
                                isSelected: selectedSide == outcome.id
                            ) {
                                selectedSide = outcome.id
                                showBetSheet = true
                                HapticManager.impact(.medium)
                            }
                        }
                    }
                } else if let outcomes = event.outcomes {
                    // Fallback without pool data
                    VStack(spacing: 10) {
                        ForEach(outcomes) { outcome in
                            OutcomeButton(
                                outcome: outcome,
                                poolData: nil,
                                isSelected: selectedSide == outcome.id
                            ) {
                                selectedSide = outcome.id
                                showBetSheet = true
                                HapticManager.impact(.medium)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(TychesTheme.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }

    // Read-only summary once the event is resolved
    private func resolvedSummary(_ event: EventDetail) -> some View {
        let pools = livePools ?? event.pools
        let winningLabel: String = {
            if let outcomeId = event.winning_outcome_id,
               let outcome = event.outcomes?.first(where: { $0.id == outcomeId }) {
                return "Resolved: \(outcome.label)"
            }
            if let side = event.winning_side {
                return "Resolved: \(side)"
            }
            return "Resolved"
        }()
        
        let totalPool = pools?.total_pool ?? event.volume
        let yesOdds = pools?.yes_odds ?? event.yesOdds
        let noOdds = pools?.no_odds ?? event.noOdds
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(winningLabel)
                    .font(.headline.bold())
                Spacer()
                Text("Trading closed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if event.event_type == "binary" {
                HStack(spacing: 12) {
                    summaryPill(title: "YES", value: String(format: "%.2fx", yesOdds), color: TychesTheme.success)
                    summaryPill(title: "NO", value: String(format: "%.2fx", noOdds), color: TychesTheme.danger)
                }
            } else if let outcomes = event.outcomes {
                VStack(spacing: 8) {
                    ForEach(outcomes) { outcome in
                        summaryPill(
                            title: outcome.label,
                            value: "\(outcome.percent ?? 0)%",
                            color: TychesTheme.primary.opacity(outcome.id == event.winning_outcome_id ? 0.25 : 0.1)
                        )
                        .overlay(
                            outcome.id == event.winning_outcome_id ?
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(TychesTheme.primary, lineWidth: 1.5) : nil
                        )
                    }
                }
            }
            
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(TychesTheme.gold)
                    Text(totalPool == 0 ? "No pool" : "\(Int(totalPool)) pool")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(TychesTheme.textPrimary)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(TychesTheme.primary)
                    Text(event.traders_count == 0 ? "No traders" : "\(event.traders_count) traders")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(TychesTheme.textPrimary)
                }
            }
        }
        .padding(16)
        .background(TychesTheme.cardBackground)
        .cornerRadius(16)
    }

    private func summaryPill(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.bold())
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(color.opacity(0.12))
        .foregroundColor(TychesTheme.textPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Activity Section
    
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.title3.bold())
            
            if activity.isEmpty {
                VStack(spacing: 12) {
                    Text("📊")
                        .font(.system(size: 40))
                    Text("No bets yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text("Place the first one.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(TychesTheme.cardBackground)
                .cornerRadius(16)
            } else {
                ForEach(activity.prefix(10)) { bet in
                    ActivityBetRow(bet: bet)
                }
            }
        }
    }
    
    // MARK: - Gossip Section
    
    private var gossipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gossip")
                .font(.title3.bold())
            
            let messages = renderedGossip
            
            if messages.isEmpty {
                VStack(spacing: 12) {
                    Text("💬")
                        .font(.system(size: 40))
                    Text("No gossip yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Drop a spicy take!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(TychesTheme.cardBackground)
                .cornerRadius(16)
            } else {
                ForEach(messages) { item in
                    GossipRow(
                        message: item.message,
                        state: item.state,
                        replyContext: item.replyContext,
                        onRetry: {
                            if item.state == .failed {
                                retryPending(item.message)
                            }
                        },
                        onReply: { tapped in
                        replyToMessage = tapped
                    }
                    )
                }
            }
            
            GossipComposer(
                replyTo: replyToMessage,
                onSend: { text, reply in
                    let result = await sendGossipMessage(text, replyToId: reply?.id)
                    if case .success = result {
                        replyToMessage = nil
                        gamification.recordGossip()
                    }
                    return result
                },
                onCancelReply: {
                    replyToMessage = nil
                }
            )
        }
    }
    
    private var renderedGossip: [GossipDisplayItem] {
        var items: [GossipDisplayItem] = gossip.map {
            GossipDisplayItem(
                id: "srv-\($0.id)",
                message: $0,
                state: .sent,
                replyContext: replyContext(for: $0)
            )
        }
        
        for pending in optimisticGossip {
            let state: GossipDeliveryState = failedLocalIds.contains(pending.localId ?? "") ? .failed : .pending
            items.insert(
                GossipDisplayItem(
                    id: pending.localId ?? "pending-\(pending.id)",
                    message: pending,
                    state: state,
                    replyContext: replyContext(for: pending)
                ),
                at: 0
            )
        }
        return items
    }
    
    private func replyContext(for message: GossipMessage) -> String? {
        guard let parentId = message.reply_to_id else { return nil }
        if let parent = gossip.first(where: { $0.id == parentId }) {
            return parent.user_username ?? parent.user_name
        }
        return nil
    }
    
    // MARK: - Bet Placement
    
    private func placeBet() async {
        guard let event = event,
              let side = selectedSide,
              let amount = Int(betAmount),
              amount > 0 else {
            showToast = "Invalid bet amount"
            HapticManager.notification(.error)
            return
        }
        
        isPlacingBet = true
        
        do {
            // Use amount-based betting (parimutuel)
            let bet = BetPlaceRequest(
                event_id: event.id,
                side: event.event_type == "binary" ? side : nil,
                outcome_id: event.event_type == "multiple" ? side : nil,
                amount: Double(amount)
            )
            
            let response = try await TychesAPI.shared.placeBet(bet)
            
            // Record gamification
            gamification.recordBet(amount: amount)
            
            // Track bet placed (use pool-based odds)
            let currentOdds = event.event_type == "binary" 
                ? (side == "YES" ? event.yesOdds : event.noOdds)
                : 2.0
            Analytics.shared.trackBetPlaced(eventId: event.id, side: side, amount: amount, price: Int(currentOdds * 100))
            
            // Refresh
            await loadEvent()
            await session.refreshProfile()
            
            showBetSheet = false
            showConfetti = true
            HapticManager.notification(.success)
            
            // Notify other screens to refresh
            NotificationCenter.default.post(name: NSNotification.Name("BetPlaced"), object: nil)
            
            withAnimation {
                showToast = "Bet placed successfully! 🎯"
            }
            
            selectedSide = nil
            betAmount = "100"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showConfetti = false
            }
        } catch let TychesError.server(msg) {
            showToast = msg
            HapticManager.notification(.error)
        } catch {
            showToast = "Failed to place bet"
            HapticManager.notification(.error)
        }
        
        isPlacingBet = false
    }
    
    // MARK: - Helpers
    // Date formatting is now available via String.toDisplayDate() from Helpers/DateFormatters.swift
    private func formatDate(_ dateString: String) -> String {
        dateString.toDisplayDate()
    }
}

// MARK: - Supporting Views

// LoadingView is now available as TychesLoadingView in SharedComponents
typealias LoadingView = TychesLoadingView

// ErrorView wrapper that calls shared component
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        TychesErrorView(message, onRetry: onRetry)
    }
}

struct EventStatPill: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(icon)
            Text(value)
                .font(.subheadline.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// EventStatusBadge is now available as StatusBadgeView in SharedComponents
struct EventStatusBadge: View {
    let status: String
    
    var body: some View {
        StatusBadgeView(status: status, style: .pill)
    }
}

struct ActivityBetRow: View {
    let bet: ActivityBet
    
    var body: some View {
        HStack(spacing: 12) {
            // Using shared UserAvatarView-style rendering
            UserAvatarView(
                name: bet.user_name ?? bet.user_username,
                userId: bet.id,
                size: .medium
            )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(bet.user_name ?? bet.user_username ?? "Trader")
                        .font(.subheadline.weight(.semibold))
                    
                    if let side = bet.side {
                        OddsPillView(side: side, percent: bet.price, style: .minimal)
                    }
                }
                
                TokenAmountView(amount: bet.shares, size: .small)
            }
            
            Spacer()
            
            Text(bet.timestamp.toRelativeTime())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Odds Button (Pool-based)

struct OddsButton: View {
    let side: String
    let percent: Int
    let odds: Double
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(side)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundColor(isSelected ? .white : sideColor)
                
                Text("\(percent)%")
                    .font(.title.bold())
                    .foregroundColor(isSelected ? .white : sideColor)
                
                // Show odds multiplier instead of meaningless "price"
                Text(String(format: "%.2fx", odds))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                isSelected ?
                (side == "YES" ? TychesTheme.successGradient : TychesTheme.dangerGradient) :
                LinearGradient(colors: [sideColor.opacity(0.08)], startPoint: .top, endPoint: .bottom)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : sideColor.opacity(0.3), lineWidth: 2)
            )
            .cornerRadius(16)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var sideColor: Color {
        side == "YES" ? TychesTheme.success : TychesTheme.danger
    }
}

// MARK: - Outcome Button (Multiple Choice - Pool-based)

struct OutcomeButton: View {
    let outcome: EventOutcome
    let poolData: OutcomePool?
    let isSelected: Bool
    let action: () -> Void
    
    // Use pool data if available, otherwise fall back to static probability
    var displayPercent: Int {
        poolData?.percent ?? outcome.probability
    }
    
    var displayOdds: Double {
        poolData?.odds ?? Double(outcome.probability > 0 ? 100 / outcome.probability : 1)
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(outcome.label)
                    .font(.headline)
                    .foregroundColor(TychesTheme.textPrimary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(displayPercent)%")
                        .font(.title3.bold())
                        .foregroundColor(TychesTheme.primary)
                    Text(String(format: "%.2fx", displayOdds))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(isSelected ? TychesTheme.primary.opacity(0.1) : TychesTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? TychesTheme.primary : Color.gray.opacity(0.2), lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Bet Sheet

struct BetSheet: View {
    let event: EventDetail
    @Binding var selectedSide: String?
    @Binding var betAmount: String
    @Binding var isPlacingBet: Bool
    let onPlaceBet: () async -> Void
    @Environment(\.dismiss) var dismiss
    
    let quickAmounts = [50, 100, 250, 500, 1000]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Pool info section
                    if let pools = event.pools {
                        PoolInfoCard(event: event, pools: pools)
                    }
                    
                    // Side selection
                    if event.event_type == "binary" {
                        HStack(spacing: 12) {
                            SideSelector(
                                side: "YES",
                                percent: event.currentYesPercent,
                                isSelected: selectedSide == "YES"
                            ) {
                                selectedSide = "YES"
                                HapticManager.selection()
                            }
                            
                            SideSelector(
                                side: "NO",
                                percent: event.currentNoPercent,
                                isSelected: selectedSide == "NO"
                            ) {
                                selectedSide = "NO"
                                HapticManager.selection()
                            }
                        }
                    }
                    
                    // Amount input
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Bet Amount")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("🪙")
                            TextField("0", text: $betAmount)
                                .keyboardType(.numberPad)
                                .font(.title2.bold())
                            Text("tokens")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(TychesTheme.cardBackground)
                        .cornerRadius(12)
                        
                        // Quick amounts
                        HStack(spacing: 8) {
                            ForEach(quickAmounts, id: \.self) { amount in
                                Button {
                                    betAmount = "\(amount)"
                                    HapticManager.selection()
                                } label: {
                                    Text("\(amount)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(betAmount == "\(amount)" ? .white : TychesTheme.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            betAmount == "\(amount)" ?
                                            TychesTheme.primaryGradient :
                                            LinearGradient(colors: [TychesTheme.primary.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                                        )
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Summary
                    if let amount = Int(betAmount), amount > 0, let side = selectedSide {
                        TradeSummary(event: event, side: side, amount: amount)
                    }
                    
                    // How it works explanation
                    HowItWorksCard()
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                // Place bet button
                Button(action: {
                    Task {
                        await onPlaceBet()
                    }
                }) {
                    HStack {
                        if isPlacingBet {
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
                        canPlaceBet ?
                        TychesTheme.premiumGradient :
                        LinearGradient(colors: [Color.gray], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(14)
                }
                .disabled(!canPlaceBet || isPlacingBet)
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Place Bet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    private var canPlaceBet: Bool {
        selectedSide != nil && (Int(betAmount) ?? 0) > 0
    }
}

// MARK: - Pool Info Card

struct PoolInfoCard: View {
    let event: EventDetail
    let pools: PoolData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(TychesTheme.primary)
                Text("Current Pool")
                    .font(.subheadline.weight(.semibold))
            }
            
            if event.event_type == "binary" {
                HStack(spacing: 12) {
                    // YES pool
                    VStack(alignment: .leading, spacing: 4) {
                        Text("YES")
                            .font(.caption.weight(.bold))
                            .foregroundColor(TychesTheme.success)
                        Text("\(Int(pools.yes_pool ?? 0))")
                            .font(.headline.bold())
                        Text("tokens")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(TychesTheme.success.opacity(0.08))
                    .cornerRadius(10)
                    
                    // NO pool
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NO")
                            .font(.caption.weight(.bold))
                            .foregroundColor(TychesTheme.danger)
                        Text("\(Int(pools.no_pool ?? 0))")
                            .font(.headline.bold())
                        Text("tokens")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(TychesTheme.danger.opacity(0.08))
                    .cornerRadius(10)
                }
                
                // Total
                HStack {
                    Text("Total in pool:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(pools.total_pool ?? 0)) tokens")
                        .font(.subheadline.weight(.bold))
                }
            } else if let outcomes = pools.outcomes {
                VStack(spacing: 8) {
                    ForEach(outcomes) { outcome in
                        HStack {
                            Text(outcome.label)
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(outcome.pool)) tokens")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
        }
        .padding()
        .background(TychesTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - How It Works Card

struct HowItWorksCard: View {
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(TychesTheme.primary)
                    Text("How parimutuel betting works")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(TychesTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(icon: "1.circle.fill", text: "All bets go into a shared pool")
                    InfoRow(icon: "2.circle.fill", text: "When the event resolves, winners split the entire pool")
                    InfoRow(icon: "3.circle.fill", text: "Your profit comes from other people's losing bets")
                    InfoRow(icon: "4.circle.fill", text: "If you're the only bettor, there's no profit to share")
                    
                    Text("💡 The more people bet against you, the higher your potential profit!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(TychesTheme.cardBackground)
        .cornerRadius(12)
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(TychesTheme.primary)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct SideSelector: View {
    let side: String
    let percent: Int
    let isSelected: Bool
    let action: () -> Void
    
    var sideColor: Color {
        side == "YES" ? TychesTheme.success : TychesTheme.danger
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(side)
                    .font(.subheadline.weight(.bold))
                Text("\(percent)%")
                    .font(.title2.bold())
            }
            .foregroundColor(isSelected ? .white : sideColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected ?
                (side == "YES" ? TychesTheme.successGradient : TychesTheme.dangerGradient) :
                LinearGradient(colors: [sideColor.opacity(0.12)], startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : sideColor.opacity(0.3), lineWidth: 2)
            )
        }
    }
}

// MARK: - Trade Summary (Parimutuel Betting)

struct TradeSummary: View {
    let event: EventDetail
    let side: String
    let amount: Int
    
    var body: some View {
            let calculation = calculateParimutuelPayout()
        
        VStack(spacing: 12) {
            // Your bet
            HStack {
                Text("Your bet")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(amount) tokens on \(side)")
                    .font(.subheadline.weight(.semibold))
            }
            
            Divider()
            
            // Pool info
            if let pools = event.pools {
                HStack {
                    Text("Current pool")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(pools.total_pool ?? 0)) tokens total")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }
            
            // Odds
            HStack {
                Text("Your odds after bet")
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.2fx", calculation.odds))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(TychesTheme.primary)
            }
            
            Divider()
            
            // Payout if wins
            HStack {
                Text("If \(side) wins")
                    .foregroundColor(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if calculation.profit > 0 {
                        Text("+\(Int(calculation.profit)) tokens")
                            .font(.headline)
                            .foregroundColor(TychesTheme.success)
                    } else {
                        Text("\(Int(calculation.profit)) tokens")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    Text("(\(Int(calculation.payout)) total payout)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Low liquidity warning
            if calculation.isLowLiquidity {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Low liquidity: Profits depend on others betting against you")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(TychesTheme.cardBackground)
        .cornerRadius(12)
    }
    
    struct ParimutuelCalculation {
        let odds: Double
        let payout: Double
        let profit: Double
        let isLowLiquidity: Bool
    }
    
    private func calculateParimutuelPayout() -> ParimutuelCalculation {
        // Get current pool sizes
        var yourSidePool: Double = 0
        var totalPool: Double = 0
        
        if event.event_type == "binary" {
            if let pools = event.pools {
                yourSidePool = side == "YES" ? (pools.yes_pool ?? 0) : (pools.no_pool ?? 0)
                totalPool = (pools.yes_pool ?? 0) + (pools.no_pool ?? 0)
            }
        } else {
            // Multiple choice
            if let pools = event.pools,
               let outcomes = pools.outcomes,
               let outcome = outcomes.first(where: { $0.id == side }) {
                yourSidePool = outcome.pool
                totalPool = pools.total_pool ?? 0
            }
        }
        
        // Calculate after your bet is added
        let newYourSidePool = yourSidePool + Double(amount)
        let newTotalPool = totalPool + Double(amount)
        
        // Your share of the winning pool
        let yourShare = Double(amount) / newYourSidePool
        
        // Your payout = your share × total pool
        let payout = yourShare * newTotalPool
        let profit = payout - Double(amount)
        
        // Odds = total pool / your side pool (after bet)
        let odds = newTotalPool / newYourSidePool
        
        // Low liquidity if opposing pool is small
        let opposingPool = totalPool - yourSidePool
        let isLowLiquidity = opposingPool < Double(amount) * 0.1 || totalPool < 100
        
        return ParimutuelCalculation(
            odds: odds,
            payout: payout,
            profit: profit,
            isLowLiquidity: isLowLiquidity
        )
    }
}

// MARK: - Gossip Row

struct GossipRow: View {
    let message: GossipMessage
    var state: GossipDeliveryState = .sent
    var replyContext: String?
    var onRetry: (() -> Void)?
    let onReply: (GossipMessage) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Reply indent indicator
            if replyContext != nil {
                Rectangle()
                    .fill(TychesTheme.primary.opacity(0.3))
                    .frame(width: 3)
                    .cornerRadius(2)
                    .padding(.trailing, 10)
            }
            
            HStack(alignment: .top, spacing: 10) {
                UserAvatarView(
                    name: message.user_name ?? message.user_username,
                    userId: message.user_id,
                    size: .medium
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(message.user_name ?? message.user_username ?? "User")
                            .font(.subheadline.weight(.semibold))
                        Text(message.created_at.toRelativeTime())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Reply context with icon
                    if let replyContext {
                        HStack(spacing: 4) {
                            Image(systemName: "arrowshape.turn.up.left.fill")
                                .font(.caption2)
                                .foregroundColor(TychesTheme.primary.opacity(0.6))
                            Text("@\(replyContext)")
                                .font(.caption)
                                .foregroundColor(TychesTheme.primary)
                        }
                    }
                    
                    Text(message.message)
                        .font(.body)
                        .foregroundColor(TychesTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    // Action row
                    HStack(spacing: 12) {
                        Button {
                            onReply(message)
                            HapticManager.selection()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrowshape.turn.up.left")
                                    .font(.caption2)
                                Text("Reply")
                                    .font(.caption)
                            }
                            .foregroundColor(TychesTheme.primary.opacity(0.8))
                        }
                        
                        switch state {
                        case .pending:
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Sending...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        case .failed:
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(TychesTheme.danger)
                                Text("Failed")
                                    .font(.caption)
                                    .foregroundColor(TychesTheme.danger)
                                if let onRetry {
                                    Button {
                                        onRetry()
                                        HapticManager.impact(.light)
                                    } label: {
                                        Text("Retry")
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(TychesTheme.primary)
                                    }
                                }
                            }
                        default:
                            EmptyView()
                        }
                    }
                }
                
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .padding(.leading, replyContext != nil ? 0 : 0)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(replyContext != nil ? TychesTheme.primary.opacity(0.03) : TychesTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(state == .failed ? TychesTheme.danger.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .opacity(state == .pending ? 0.7 : 1)
    }
}

enum GossipDeliveryState {
    case sent
    case pending
    case failed
}

struct GossipDisplayItem: Identifiable {
    let id: String
    let message: GossipMessage
    let state: GossipDeliveryState
    let replyContext: String?
}

// MARK: - Gossip Composer

struct GossipComposer: View {
    var replyTo: GossipMessage?
    let onSend: (_ text: String, _ replyTo: GossipMessage?) async -> Result<Void, Error>
    var onCancelReply: (() -> Void)?
    @State private var message: String = ""
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var mentionQuery: String = ""
    @State private var suggestions: [TychesAPI.FriendSearchResult] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Reply indicator banner
            if let reply = replyTo {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(TychesTheme.primary)
                        .frame(width: 3)
                        .cornerRadius(2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replying to")
                            .font(.caption2)
                            .foregroundColor(TychesTheme.textTertiary)
                        Text("@\(reply.user_username ?? reply.user_name ?? "user")")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(TychesTheme.primary)
                    }
                    
                    Spacer()
                    
                    Button {
                        onCancelReply?()
                        HapticManager.selection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundColor(TychesTheme.textTertiary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(TychesTheme.primary.opacity(0.08))
                .cornerRadius(12)
            }
            
            // Message input
            HStack(spacing: 12) {
                TextField(replyPlaceholder, text: $message)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .onChange(of: message) { _, newValue in
                        handleMentions(text: newValue)
                    }
                
                Button(action: {
                    Task {
                        await postGossip()
                    }
                }) {
                    ZStack {
                        if isPosting {
                            ProgressView()
                                .tint(TychesTheme.primary)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(message.isEmpty ? .gray : TychesTheme.primary)
                        }
                    }
                }
                .disabled(message.isEmpty || isPosting)
                .padding(.trailing, 8)
            }
            .background(TychesTheme.cardBackground)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(replyTo != nil ? TychesTheme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            
            // Inline error with retry
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(TychesTheme.danger)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(TychesTheme.danger)
                    Spacer()
                    Button {
                        Task { await postGossip() }
                    } label: {
                        Text("Retry")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(TychesTheme.primary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(TychesTheme.danger.opacity(0.08))
                .cornerRadius(10)
            }
            
            // Mention suggestions dropdown
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions.prefix(5)) { suggestion in
                        Button {
                            insertMention(suggestion.username ?? suggestion.email ?? "")
                            HapticManager.selection()
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(TychesTheme.avatarGradient(for: suggestion.id))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Text(String((suggestion.name ?? suggestion.username ?? "U").prefix(1)).uppercased())
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(suggestion.name ?? suggestion.username ?? "User")
                                        .font(.subheadline)
                                        .foregroundColor(TychesTheme.textPrimary)
                                    if let username = suggestion.username {
                                        Text("@\(username)")
                                            .font(.caption)
                                            .foregroundColor(TychesTheme.textSecondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        
                        if suggestion.id != suggestions.prefix(5).last?.id {
                            Divider()
                                .padding(.leading, 50)
                        }
                    }
                }
                .background(TychesTheme.cardBackground)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    private var replyPlaceholder: String {
        if replyTo != nil {
            return "Write a reply..."
        }
        return "Drop a spicy take..."
    }
    
    private func postGossip() async {
        guard !message.isEmpty else { return }
        
        isPosting = true
        errorMessage = nil
        let result = await onSend(message, replyTo)
        await MainActor.run {
            isPosting = false
            switch result {
            case .success:
                message = ""
                errorMessage = nil
                HapticManager.notification(.success)
            case .failure:
                HapticManager.notification(.error)
                errorMessage = "Failed to send. Check connection and retry."
            }
        }
    }
    
    private func handleMentions(text: String) {
        let mentions = ChatMentionHelper.extractMentions(from: text)
        guard let last = mentions.last, last.count >= 2 else {
            suggestions = []
            return
        }
        mentionQuery = last
        Task {
            do {
                let results = try await TychesAPI.shared.searchUsers(query: last)
                await MainActor.run {
                    suggestions = results
                }
            } catch {
                await MainActor.run {
                    suggestions = []
                }
            }
        }
    }
    
    private func insertMention(_ username: String) {
        guard !username.isEmpty else { return }
        var components = message.components(separatedBy: " ")
        if !components.isEmpty {
            components.removeLast()
        }
        components.append("@\(username)")
        message = components.joined(separator: " ") + " "
        suggestions = []
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    var valueColor: Color = TychesTheme.textPrimary
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Toast View
// ToastView is now available as TychesToastView in SharedComponents
struct ToastView: View {
    let message: String
    
    var body: some View {
        let type: TychesToastView.ToastType = message.contains("success") || message.contains("🎯") ? .success : .info
        TychesToastView(message, type: type)
            .padding()
    }
}

// MARK: - Invite to Event Sheet

struct InviteToEventSheet: View {
    let event: EventDetail
    let onInviteSent: () -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionStore
    
    @State private var inviteTab: InviteTab = .friends
    @State private var friends: [TychesAPI.FriendData] = []
    @State private var selectedFriendIds: Set<Int> = []
    @State private var isLoadingFriends = false
    
    @State private var usernameSearch: String = ""
    @State private var usernameSearchResults: [TychesAPI.FriendSearchResult] = []
    @State private var selectedUsernames: Set<String> = []
    @State private var resolvedUserIds: Set<Int> = []
    
    @State private var emailInputs: [String] = [""]
    @State private var contacts: [ContactInfo] = []
    @State private var selectedContacts: Set<String> = []
    @State private var isLoadingContacts = false
    
    @State private var isInviting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showShareSheet = false
    @State private var shareLink: String = ""
    
    enum InviteTab: String, CaseIterable {
        case friends = "Friends"
        case contacts = "Contacts"
        case email = "Email"
        case share = "Share Link"
        
        var icon: String {
            switch self {
            case .friends: return "person.2.fill"
            case .contacts: return "person.crop.circle.badge.plus"
            case .email: return "envelope.fill"
            case .share: return "square.and.arrow.up"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                HStack(spacing: 0) {
                    ForEach(InviteTab.allCases, id: \.self) { tab in
                        Button {
                            inviteTab = tab
                            HapticManager.selection()
                            
                            if tab == .contacts && contacts.isEmpty {
                                Task {
                                    await loadContacts()
                                }
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 16))
                                Text(tab.rawValue)
                                    .font(.caption2)
                            }
                            .foregroundColor(inviteTab == tab ? TychesTheme.primary : TychesTheme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(inviteTab == tab ? TychesTheme.primary.opacity(0.1) : Color.clear)
                        }
                    }
                }
                .background(TychesTheme.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top)
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Invite to \(event.title)")
                            .font(.title2.bold())
                            .padding(.horizontal)
                            .padding(.top)
                        
                        // Success/Error messages
                        if let success = successMessage {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(TychesTheme.success)
                                Text(success)
                                    .font(.subheadline)
                                    .foregroundColor(TychesTheme.success)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(TychesTheme.success.opacity(0.1))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                        
                        if let error = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(TychesTheme.danger)
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(TychesTheme.danger)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(TychesTheme.danger.opacity(0.1))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                        
                        Group {
                            switch inviteTab {
                            case .friends:
                                friendsTabContent
                            case .contacts:
                                contactsTabContent
                            case .email:
                                emailTabContent
                            case .share:
                                shareTabContent
                            }
                        }
                    }
                }
            }
            .background(TychesTheme.background)
            .navigationTitle("Invite People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        sendInvites()
                    } label: {
                        if isInviting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send")
                        }
                    }
                    .disabled(isInviting || !hasSelections)
                }
            }
            .task {
                await loadFriends()
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [shareLink])
            }
        }
    }
    
    private var hasSelections: Bool {
        !selectedFriendIds.isEmpty || !selectedUsernames.isEmpty || !selectedContacts.isEmpty || emailInputs.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty && $0.contains("@") }
    }
    
    // MARK: - Friends Tab
    
    private var friendsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Username search
            VStack(alignment: .leading, spacing: 8) {
                Text("Search by username")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(TychesTheme.textTertiary)
                    
                    TextField("@username", text: $usernameSearch)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onChange(of: usernameSearch) { _, newValue in
                            if !newValue.isEmpty && newValue.count >= 2 {
                                Task {
                                    await searchUsername(newValue)
                                }
                            } else {
                                usernameSearchResults = []
                            }
                        }
                    
                    if !usernameSearch.isEmpty {
                        Button {
                            usernameSearch = ""
                            usernameSearchResults = []
                            HapticManager.selection()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(TychesTheme.textTertiary)
                        }
                    }
                }
                .padding(12)
                .background(TychesTheme.cardBackground)
                .cornerRadius(10)
                .padding(.horizontal)
                
                if !usernameSearchResults.isEmpty {
                    LazyVStack(spacing: 8) {
                        ForEach(usernameSearchResults) { result in
                            UsernameSearchResultRow(
                                result: result,
                                isSelected: selectedUsernames.contains(result.username ?? ""),
                                onToggle: {
                                    let username = result.username ?? ""
                                    if selectedUsernames.contains(username) {
                                        selectedUsernames.remove(username)
                                        if let id = result.id as? Int {
                                            resolvedUserIds.remove(id)
                                        }
                                    } else {
                                        selectedUsernames.insert(username)
                                        if let id = result.id as? Int {
                                            resolvedUserIds.insert(id)
                                        }
                                    }
                                    HapticManager.selection()
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Divider()
                .padding(.vertical, 8)
            
            if isLoadingFriends {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if friends.filter({ $0.status == "accepted" }).isEmpty && usernameSearchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 50))
                        .foregroundColor(TychesTheme.textTertiary)
                    
                    Text("No friends yet")
                        .font(.headline)
                        .foregroundColor(TychesTheme.textSecondary)
                    
                    Text("Search by username above, or invite via email/contacts")
                        .font(.subheadline)
                        .foregroundColor(TychesTheme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                let totalSelected = selectedFriendIds.count + selectedUsernames.count
                if totalSelected > 0 {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(TychesTheme.success)
                        Text("\(totalSelected) selected")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(TychesTheme.success)
                        Spacer()
                        Button("Clear") {
                            selectedFriendIds.removeAll()
                            selectedUsernames.removeAll()
                            resolvedUserIds.removeAll()
                            HapticManager.selection()
                        }
                        .font(.subheadline)
                        .foregroundColor(TychesTheme.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(TychesTheme.success.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                if !friends.filter({ $0.status == "accepted" }).isEmpty {
                    LazyVStack(spacing: 8) {
                        ForEach(friends.filter { $0.status == "accepted" }) { friend in
                            FriendSelectionRow(
                                friend: friend,
                                isSelected: selectedFriendIds.contains(friend.friend_id ?? friend.id),
                                onToggle: {
                                    let friendId = friend.friend_id ?? friend.id
                                    if selectedFriendIds.contains(friendId) {
                                        selectedFriendIds.remove(friendId)
                                    } else {
                                        selectedFriendIds.insert(friendId)
                                    }
                                    HapticManager.selection()
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Contacts Tab
    
    private var contactsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoadingContacts {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if contacts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 50))
                        .foregroundColor(TychesTheme.textTertiary)
                    
                    Text("No contacts found")
                        .font(.headline)
                        .foregroundColor(TychesTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                if !selectedContacts.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(TychesTheme.success)
                        Text("\(selectedContacts.count) selected")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(TychesTheme.success)
                        Spacer()
                        Button("Clear") {
                            selectedContacts.removeAll()
                            HapticManager.selection()
                        }
                        .font(.subheadline)
                        .foregroundColor(TychesTheme.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(TychesTheme.success.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                LazyVStack(spacing: 8) {
                    ForEach(contacts, id: \.email) { contact in
                        ContactSelectionRow(
                            contact: contact,
                            isSelected: selectedContacts.contains(contact.email),
                            onToggle: {
                                if selectedContacts.contains(contact.email) {
                                    selectedContacts.remove(contact.email)
                                } else {
                                    selectedContacts.insert(contact.email)
                                }
                                HapticManager.selection()
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Email Tab
    
    private var emailTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter email addresses")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(Array(emailInputs.enumerated()), id: \.offset) { index, email in
                    HStack(spacing: 8) {
                        TextField("friend@example.com", text: Binding(
                            get: { emailInputs[index] },
                            set: { emailInputs[index] = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(12)
                        .background(TychesTheme.cardBackground)
                        .cornerRadius(10)
                        
                        if emailInputs.count > 1 {
                            Button {
                                emailInputs.remove(at: index)
                                HapticManager.selection()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(TychesTheme.danger)
                                    .font(.title3)
                            }
                        }
                    }
                }
                
                Button {
                    emailInputs.append("")
                    HapticManager.selection()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add another email")
                    }
                    .font(.subheadline)
                    .foregroundColor(TychesTheme.primary)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Share Tab
    
    private var shareTabContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 60))
                .foregroundColor(TychesTheme.primary)
            
            Text("Share Invite Link")
                .font(.title2.bold())
            
            Text("Share a link via WhatsApp, Messages, or any app")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                shareLink = "https://www.tyches.us/event.php?id=\(event.id)"
                showShareSheet = true
                HapticManager.impact(.medium)
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Link")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(TychesTheme.primaryGradient)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Functions
    
    private func loadFriends() async {
        isLoadingFriends = true
        do {
            let response = try await TychesAPI.shared.fetchFriends()
            friends = response.friends
        } catch {
            friends = []
        }
        isLoadingFriends = false
    }
    
    private func loadContacts() async {
        isLoadingContacts = true
        let store = CNContactStore()
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
        
        do {
            try await store.requestAccess(for: .contacts)
            let request = CNContactFetchRequest(keysToFetch: keys)
            var loadedContacts: [ContactInfo] = []
            
            try store.enumerateContacts(with: request) { contact, _ in
                for email in contact.emailAddresses {
                    let emailString = email.value as String
                    if !emailString.isEmpty && emailString.contains("@") {
                        let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                        loadedContacts.append(ContactInfo(
                            name: name.isEmpty ? emailString : name,
                            email: emailString.lowercased()
                        ))
                        break
                    }
                }
            }
            
            contacts = loadedContacts.sorted { $0.name < $1.name }
        } catch {
            contacts = []
        }
        
        isLoadingContacts = false
    }
    
    private func searchUsername(_ query: String) async {
        let cleanQuery = query.trimmingCharacters(in: .whitespaces).lowercased()
        if cleanQuery.isEmpty || cleanQuery.count < 2 {
            usernameSearchResults = []
            return
        }
        
        do {
            let results = try await TychesAPI.shared.searchUsers(query: cleanQuery)
            usernameSearchResults = results
        } catch {
            usernameSearchResults = []
        }
    }
    
    private func sendInvites() {
        isInviting = true
        errorMessage = nil
        successMessage = nil
        
        // Collect all emails
        var allEmails: [String] = []
        for email in emailInputs {
            let trimmed = email.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && trimmed.contains("@") {
                allEmails.append(trimmed.lowercased())
            }
        }
        allEmails.append(contentsOf: Array(selectedContacts))
        allEmails = Array(Set(allEmails))
        
        // Combine friend IDs and resolved username IDs
        var allUserIds = Array(selectedFriendIds)
        allUserIds.append(contentsOf: Array(resolvedUserIds))
        allUserIds = Array(Set(allUserIds))
        
        Task {
            do {
                let response = try await TychesAPI.shared.inviteToEvent(
                    eventId: event.id,
                    friendIds: allUserIds.isEmpty ? nil : allUserIds,
                    emails: allEmails.isEmpty ? nil : allEmails
                )
                
                var messageParts: [String] = []
                if let invited = response.invited, invited > 0 {
                    messageParts.append("\(invited) member(s) added")
                }
                if let emailsSent = response.emails_sent, emailsSent > 0 {
                    messageParts.append("\(emailsSent) invitation(s) sent")
                }
                
                successMessage = messageParts.isEmpty ? "Invitations sent!" : messageParts.joined(separator: ", ")
                
                HapticManager.notification(.success)
                MissionTracker.track(action: .inviteSent)
                
                // Clear selections
                selectedFriendIds.removeAll()
                selectedUsernames.removeAll()
                resolvedUserIds.removeAll()
                selectedContacts.removeAll()
                emailInputs = [""]
                usernameSearch = ""
                usernameSearchResults = []
                
                // Refresh event detail
                onInviteSent()
                
                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            } catch let TychesError.server(msg) {
                errorMessage = msg
                HapticManager.notification(.error)
            } catch {
                errorMessage = "Failed to send invitations. Please try again."
                HapticManager.notification(.error)
            }
            
            isInviting = false
        }
    }
}

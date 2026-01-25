import SwiftUI
import Contacts

struct MarketDetailView: View {
    let market: MarketSummary
    @State private var marketDetail: MarketDetailResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showInviteSheet = false
    @State private var inviteMarket: MarketDetail?
    @EnvironmentObject var session: SessionStore
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                // ALWAYS SHOW INVITE BUTTON AT TOP - USING MARKET SUMMARY
                Button {
                    if let market = marketDetail?.market {
                        inviteMarket = market
                    } else {
                        // Use basic market info from summary
                        Task {
                            await loadMarketDetail()
                            if let market = marketDetail?.market {
                                inviteMarket = market
                                showInviteSheet = true
                            }
                        }
                        return
                    }
                    showInviteSheet = true
                    HapticManager.impact(.medium)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.title2)
                        Text("INVITE PEOPLE TO THIS MARKET")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(TychesTheme.primaryGradient)
                    .cornerRadius(16)
                    .shadow(color: TychesTheme.primary.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .disabled(marketDetail == nil && !isLoading)
                
                if isLoading {
                    LoadingView()
                } else if let error = errorMessage {
                    ErrorView(message: error, onRetry: {
                        Task { await loadMarketDetail() }
                    })
                } else if let detail = marketDetail {
                    marketHeader(detail.market)
                    statsSection(detail)
                    membersSection(detail.members)
                    eventsSection(detail.events)
                }
            }
            .padding()
            .padding(.bottom, 100)
        }
        .background(TychesTheme.background)
        .navigationTitle(market.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        if let market = marketDetail?.market {
                            inviteMarket = market
                            showInviteSheet = true
                            HapticManager.impact(.light)
                        }
                    } label: {
                        Label("Invite Members", systemImage: "person.badge.plus")
                    }
                    .disabled(marketDetail == nil)
                    
                    Button {
                        // Share market
                        HapticManager.impact(.light)
                    } label: {
                        Label("Share Market", systemImage: "square.and.arrow.up")
                    }
                    .disabled(marketDetail == nil)
                    
                    if let market = marketDetail?.market, market.is_owner == true {
                        Divider()
                        Button {
                            // Edit market
                        } label: {
                            Label("Edit Market", systemImage: "pencil")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(TychesTheme.primary)
                }
            }
        }
        .task {
            await loadMarketDetail()
        }
        .onAppear {
            Analytics.shared.trackScreenView("MarketDetail")
            Analytics.shared.trackMarketViewed(marketId: market.id, marketName: market.name)
        }
        .refreshable {
            await loadMarketDetail()
            await session.refreshProfile()
        }
        .sheet(isPresented: $showInviteSheet) {
            if let market = inviteMarket ?? marketDetail?.market {
                InviteToMarketSheet(market: market, onInviteSent: {
                    Task {
                        await loadMarketDetail()
                    }
                })
                .environmentObject(session)
            }
        }
    }
    
    // MARK: - Loading
    
    private func loadMarketDetail() async {
        isLoading = true
        errorMessage = nil
        do {
            marketDetail = try await TychesAPI.shared.fetchMarketDetail(id: market.id)
        } catch let TychesError.unauthorized(msg) {
            errorMessage = msg
        } catch let TychesError.server(msg) {
            errorMessage = msg
        } catch {
            errorMessage = "Failed to load market details"
        }
        isLoading = false
    }
    
    // MARK: - Header
    
    private func marketHeader(_ market: MarketDetail) -> some View {
        VStack(spacing: 16) {
            // Large avatar
            MarketAvatarView(
                emoji: market.avatar_emoji,
                color: market.avatar_color,
                size: .xxlarge,
                showShadow: true
            )
            
            // Name
            Text(market.name)
                .font(.title.bold())
            
            // Description
            if let desc = market.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Badges
            HStack(spacing: 10) {
                Badge(
                    icon: market.visibility == "public" ? "globe" : "lock.fill",
                    text: market.visibility == "public" ? "Public" : "Private",
                    color: market.visibility == "public" ? .blue : .gray
                )
                
                if market.is_owner == true {
                    Badge(icon: "crown.fill", text: "Owner", color: TychesTheme.gold)
                } else if let role = market.user_role {
                    Badge(icon: "person.fill", text: role.capitalized, color: TychesTheme.primary)
                }
            }
            
            // Invite Button - Prominent
            Button {
                inviteMarket = market
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
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - Stats Section
    
    private func statsSection(_ detail: MarketDetailResponse) -> some View {
        HStack(spacing: 12) {
            DetailStatCard(
                value: "\(detail.members.count)",
                label: "Members",
                icon: "👥"
            )
            
            DetailStatCard(
                value: "\(detail.events.count)",
                label: "Events",
                icon: "📊"
            )
            
            DetailStatCard(
                value: "\(Int.random(in: 5000...20000))",
                label: "Volume",
                icon: "🪙"
            )
        }
    }
    
    // MARK: - Members Section
    
    private func membersSection(_ members: [MarketMember]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Members")
                    .font(.title3.bold())
                
                Text("\(members.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(8)
                
                Spacer()
                
                Button {
                    if let market = marketDetail?.market {
                        inviteMarket = market
                        showInviteSheet = true
                        HapticManager.impact(.light)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Invite")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(TychesTheme.primary)
                }
                .disabled(marketDetail == nil)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(members) { member in
                        MemberCard(member: member)
                    }
                }
            }
        }
        .padding()
        .background(TychesTheme.cardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Events Section
    
    private func eventsSection(_ events: [EventSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Events")
                    .font(.title3.bold())
                
                Spacer()
                
                Button {
                    HapticManager.impact(.light)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Create")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(TychesTheme.primaryGradient)
                    .cornerRadius(20)
                }
            }
            
            if events.isEmpty {
                VStack(spacing: 12) {
                    Text("✨")
                        .font(.system(size: 40))
                    Text("No events yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Create the first event for this market")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(TychesTheme.cardBackground)
                .cornerRadius(16)
            } else {
                ForEach(events) { event in
                    NavigationLink {
                        EventDetailView(eventID: event.id)
                    } label: {
                        EventRowCompact(event: event)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }
    
}

// MARK: - Supporting Views

struct Badge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .cornerRadius(8)
    }
}

struct DetailStatCard: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(icon)
                .font(.title2)
            
            Text(value)
                .font(.title2.bold())
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(TychesTheme.cardBackground)
        .cornerRadius(16)
    }
}

struct MemberCard: View {
    let member: MarketMember
    
    var body: some View {
        VStack(spacing: 8) {
            // Avatar using shared component
            ZStack {
                UserAvatarView(
                    name: member.name,
                    username: member.username,
                    userId: member.id,
                    size: .medium
                )
                
                // Role badge for owner
                if member.role == "owner" {
                    Circle()
                        .fill(TychesTheme.gold)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Image(systemName: "crown.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.white)
                        )
                        .offset(x: 18, y: -18)
                }
            }
            
            // Name
            Text(member.name ?? member.username ?? "Member")
                .font(.caption.weight(.medium))
                .lineLimit(1)
            
            // Username
            if let username = member.username {
                Text("@\(username)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 80)
    }
}

// MemberAvatar is replaced by UserAvatarView from SharedComponents

struct EventRowCompact: View {
    let event: EventSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                StatusBadge(status: event.status, closesAt: event.closes_at)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(event.traders_count)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            // Title
            Text(event.title)
                .font(.headline)
                .foregroundColor(TychesTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Odds
            if event.event_type == "binary" {
                HStack(spacing: 10) {
                    CompactOddsPill(side: "YES", percent: event.currentYesPercent)
                    CompactOddsPill(side: "NO", percent: event.currentNoPercent)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("🪙")
                            .font(.caption2)
                        Text("\(Int(event.volume))")
                            .font(.caption.weight(.bold))
                            .foregroundColor(TychesTheme.gold)
                    }
                }
            }
        }
        .padding()
        .background(TychesTheme.cardBackground)
        .cornerRadius(16)
    }
}

struct CompactOddsPill: View {
    let side: String
    let percent: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Text(side)
                .font(.caption2.weight(.bold))
            Text("\(percent)%")
                .font(.caption.weight(.bold))
        }
        .foregroundColor(sideColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(sideColor.opacity(0.12))
        .cornerRadius(8)
    }
    
    private var sideColor: Color {
        side == "YES" ? TychesTheme.success : TychesTheme.danger
    }
}

// MARK: - Invite to Market Sheet

struct InviteToMarketSheet: View {
    let market: MarketDetail
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
                        Text("Invite to \(market.name)")
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
                                    } else {
                                        selectedUsernames.insert(username)
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
                shareLink = "https://www.tyches.us/market.php?id=\(market.id)"
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
        
        // Collect usernames
        let usernames = Array(selectedUsernames).map { $0.trimmingCharacters(in: .whitespaces).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "@")) }
        
        Task {
            do {
                let response = try await TychesAPI.shared.inviteToMarket(
                    marketId: market.id,
                    friendIds: Array(selectedFriendIds),
                    usernames: usernames.isEmpty ? nil : usernames,
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
                
                // Clear selections
                selectedFriendIds.removeAll()
                selectedUsernames.removeAll()
                selectedContacts.removeAll()
                emailInputs = [""]
                usernameSearch = ""
                usernameSearchResults = []
                
                // Refresh market detail
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

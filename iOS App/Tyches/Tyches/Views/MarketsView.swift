import SwiftUI

struct MarketsView: View {
    @EnvironmentObject var session: SessionStore
    @State private var searchText = ""
    @State private var showCreateMarket = false
    @State private var showCreateEvent = false

    var filteredMarkets: [MarketSummary] {
        guard let markets = session.profile?.markets else { return [] }
        if searchText.isEmpty {
            return markets
        }
        return markets.filter { market in
            market.name.localizedCaseInsensitiveContains(searchText) ||
            (market.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    // Stats header
                    statsHeader
                    
                    // Search bar
                    searchBar
                    
                    // Markets list
                    if filteredMarkets.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredMarkets) { market in
                                NavigationLink {
                                    MarketDetailView(market: market)
                                } label: {
                                    MarketCardFull(market: market)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(TychesTheme.background)
            .navigationTitle("Markets")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await session.refreshProfile()
            }
            .onAppear {
                Analytics.shared.trackScreenView("Markets")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showCreateMarket = true
                            HapticManager.impact(.light)
                        } label: {
                            Label("Create Market", systemImage: "person.3.fill")
                        }
                        
                        Button {
                            showCreateEvent = true
                            HapticManager.impact(.light)
                        } label: {
                            Label("Create Event", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(TychesTheme.primaryGradient)
                    }
                }
            }
            .sheet(isPresented: $showCreateMarket) {
                CreateMarketView()
            }
            .sheet(isPresented: $showCreateEvent) {
                CreateEventView()
            }
        }
    }
    
    // MARK: - Stats Header
    
    private var statsHeader: some View {
        let totalEvents = filteredMarkets.reduce(0) { $0 + ($1.events_count ?? 0) }
        let totalMembers = filteredMarkets.reduce(0) { $0 + ($1.members_count ?? 0) }
        
        return HStack(spacing: 12) {
            MarketStatCard(icon: "📊", value: "\(filteredMarkets.count)", label: "Markets")
            MarketStatCard(icon: "⚡️", value: "\(totalEvents)", label: "Events")
            MarketStatCard(icon: "👥", value: "\(totalMembers)", label: "Members")
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search markets...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    HapticManager.selection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(TychesTheme.cardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🎯")
                .font(.system(size: 60))
            
            Text(searchText.isEmpty ? "No markets yet" : "No markets found")
                .font(.title3.bold())
            
            Text(searchText.isEmpty ?
                 "Create a market to start predicting with friends" :
                 "Try a different search term")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if searchText.isEmpty {
                Button {
                    showCreateMarket = true
                    HapticManager.impact(.medium)
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Create Market")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(TychesTheme.primaryGradient)
                    .cornerRadius(24)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Market Stat Card

struct MarketStatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(icon)
                Text(value)
                    .font(.headline.bold())
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(TychesTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Market Card Full

struct MarketCardFull: View {
    let market: MarketSummary
    @State private var isAppeared = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 14) {
                // Avatar
                MarketAvatarView(
                    emoji: market.avatar_emoji,
                    color: market.avatar_color,
                    size: .large,
                    showShadow: true
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(market.name)
                        .font(.title3.bold())
                        .foregroundColor(TychesTheme.textPrimary)
                    
                    HStack(spacing: 8) {
                        Label("\(market.members_count ?? 0)", systemImage: "person.2.fill")
                        Label("\(market.events_count ?? 0) events", systemImage: "calendar")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Description if available
            if let desc = market.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Stats
            HStack(spacing: 0) {
                MarketStatPill(value: "\(Int.random(in: 1000...10000))", label: "Volume", icon: "🪙")
                
                Divider()
                    .frame(height: 24)
                
                MarketStatPill(value: "\(Int.random(in: 70...95))%", label: "Accuracy", icon: "🎯")
                
                Divider()
                    .frame(height: 24)
                
                MarketStatPill(value: market.visibility == "public" ? "Public" : "Private", label: "Access", icon: market.visibility == "public" ? "🌐" : "🔒")
            }
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
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

struct MarketStatPill: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text(icon)
                    .font(.caption)
                Text(value)
                    .font(.subheadline.weight(.bold))
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

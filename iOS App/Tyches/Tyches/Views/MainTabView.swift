import SwiftUI

// MARK: - Main Tab View (Reimagined Navigation)
// Minimal floating tab bar, immersive content

struct MainTabView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var deepLink: DeepLinkRouter
    @State private var selectedTab: Tab = .home
    @State private var showCreateSheet = false
    @State private var startWithEventCreation = false
    @State private var startWithMarketCreation = false
    @Namespace private var tabAnimation
    
    enum Tab: String, CaseIterable {
        case home = "house.fill"
        case markets = "person.3.fill"
        case activity = "bell.fill"
        case profile = "person.fill"
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case .home:
                    FeedView(
                        onCreateEvent: {
                            startWithEventCreation = true
                            showCreateSheet = true
                        },
                        onCreateMarket: {
                            startWithEventCreation = false
                            startWithMarketCreation = true
                            showCreateSheet = true
                        },
                        onBrowseMarkets: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = .markets
                            }
                        }
                    )
                case .markets:
                    MarketsListView()
                case .activity:
                    ActivityFeedView()
                case .profile:
                    ProfileDashboard()
                }
            }
            .ignoresSafeArea()
            
            // Floating Tab Bar
            floatingTabBar
        }
        .background(TychesTheme.background)
        .sheet(isPresented: $showCreateSheet) {
            CreateSheetView(startWithEventCreation: startWithEventCreation, startWithMarketCreation: startWithMarketCreation)
                .environmentObject(session)
                .environmentObject(deepLink)
        }
        .onChange(of: showCreateSheet) { _, isShowing in
            if !isShowing {
                startWithEventCreation = false
                startWithMarketCreation = false
            }
        }
        .onChange(of: deepLink.targetEventId) { _, newValue in
            if newValue != nil {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .home
                }
            }
        }
    }
    
    // MARK: - Full-Width Tab Bar (iOS style)
    
    private var floatingTabBar: some View {
        VStack(spacing: 0) {
            // Separator line
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(height: 0.5)
            
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    if tab == .markets {
                        // Regular tab
                        tabButton(tab)
                        
                        // Create button in center
                        createButton
                        
                    } else {
                        tabButton(tab)
                    }
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 16)
        }
        .background(TychesTheme.cardBackground)
    }
    
    private func tabButton(_ tab: Tab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
            HapticManager.selection()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.rawValue)
                    .font(.system(size: 22))
                    .foregroundColor(selectedTab == tab ? TychesTheme.primary : TychesTheme.textTertiary)
                    .frame(height: 22)
                
                Text(tabLabel(tab))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(selectedTab == tab ? TychesTheme.primary : TychesTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func tabLabel(_ tab: Tab) -> String {
        switch tab {
        case .home: return "Home"
        case .markets: return "Markets"
        case .activity: return "Activity"
        case .profile: return "Profile"
        }
    }
    
    private var createButton: some View {
        Button {
            showCreateSheet = true
            HapticManager.impact(.medium)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(TychesTheme.primary)
                .clipShape(Circle())
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Create Sheet View

struct CreateSheetView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionStore
    
    // Allow starting directly with event or market creation
    var startWithEventCreation: Bool = false
    var startWithMarketCreation: Bool = false
    
    @State private var showEventCreation = false
    @State private var showMarketCreation = false
    @State private var currentDetent: PresentationDetent = .medium
    
    enum CreateOption: String, CaseIterable {
        case event = "Create Prediction"
        case market = "New Market"
        
        var icon: String {
            switch self {
            case .event: return "sparkles"
            case .market: return "person.3.fill"
            }
        }
        
        var description: String {
            switch self {
            case .event: return "Ask your friends to predict something"
            case .market: return "Start a new group with friends"
            }
        }
        
        var gradient: LinearGradient {
            switch self {
            case .event: return TychesTheme.primaryGradient
            case .market: return TychesTheme.premiumGradient
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if showEventCreation {
                    CreateEventView()
                } else if showMarketCreation {
                    CreateMarketView()
                } else {
                    optionsView
                }
            }
            .background(TychesTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if showEventCreation || showMarketCreation {
                            withAnimation {
                                showEventCreation = false
                                showMarketCreation = false
                                currentDetent = .medium
                            }
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: showEventCreation || showMarketCreation ? "chevron.left" : "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(TychesTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(TychesTheme.surfaceElevated)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $currentDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(TychesTheme.background)
        .onAppear {
            if startWithEventCreation {
                showEventCreation = true
                currentDetent = .large
            } else if startWithMarketCreation {
                showMarketCreation = true
                currentDetent = .large
            }
        }
    }
    
    private var optionsView: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Create")
                    .font(.system(size: 32, weight: .bold))
                Text("What do you want to make?")
                    .font(.subheadline)
                    .foregroundColor(TychesTheme.textSecondary)
            }
            .padding(.top, 20)
            
            // Options
            VStack(spacing: 16) {
                ForEach(CreateOption.allCases, id: \.self) { option in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            currentDetent = .large
                            if option == .event {
                                showEventCreation = true
                            } else {
                                showMarketCreation = true
                            }
                        }
                        HapticManager.selection()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: option.icon)
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(option.gradient)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.rawValue)
                                    .font(.headline)
                                    .foregroundColor(TychesTheme.textPrimary)
                                Text(option.description)
                                    .font(.caption)
                                    .foregroundColor(TychesTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(TychesTheme.textTertiary)
                        }
                        .padding(16)
                        .background(TychesTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(SessionStore())
}


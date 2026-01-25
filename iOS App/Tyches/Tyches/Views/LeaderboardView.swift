import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @State private var isLoading = true
    @State private var entries: [LeaderboardEntry] = []
    @State private var userPosition: Int?
    @State private var errorMessage: String?
    
    let tabs = ["Tokens", "Accuracy", "Friends"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedTab = index
                                HapticManager.selection()
                            }
                            Task { await loadLeaderboard() }
                        } label: {
                            Text(tab)
                                .font(.subheadline.weight(selectedTab == index ? .semibold : .regular))
                                .foregroundColor(selectedTab == index ? .white : TychesTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    selectedTab == index ?
                                    TychesTheme.primaryGradient :
                                    LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(4)
                .background(TychesTheme.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Text("⚠️")
                            .font(.system(size: 50))
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("Try Again") {
                            Task { await loadLeaderboard() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                } else if entries.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Text("🏆")
                            .font(.system(size: 50))
                        Text("No entries yet")
                            .font(.headline)
                        Text("Be the first on the leaderboard!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Top 3 podium
                            if entries.count >= 3 {
                                TopThreePodium(entries: Array(entries.prefix(3)))
                                    .padding(.vertical, 24)
                            }
                            
                            // Remaining entries
                            ForEach(Array(entries.dropFirst(3).enumerated()), id: \.element.id) { index, entry in
                                LeaderboardRow(entry: entry, rank: index + 4)
                                
                                if index < entries.count - 4 {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                            
                            // Current user highlight (if not in top)
                            if let userId = session.currentUser?.id,
                               !entries.prefix(10).contains(where: { $0.userId == userId }) {
                                Divider()
                                    .padding(.vertical, 8)
                                
                                HStack(spacing: 4) {
                                    Text("•••")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                
                                if let userEntry = entries.first(where: { $0.userId == userId }) {
                                    LeaderboardRow(entry: userEntry, rank: userEntry.rank, isCurrentUser: true)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                }
            }
            .background(TychesTheme.background)
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await loadLeaderboard()
        }
        .refreshable {
            await loadLeaderboard()
        }
    }
    
    private func loadLeaderboard() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let type: String
            let scope: String
            
            switch selectedTab {
            case 0: // Tokens
                type = "tokens"
                scope = "global"
            case 1: // Accuracy
                type = "accuracy"
                scope = "global"
            case 2: // Friends
                type = "tokens"
                scope = "friends"
            default:
                type = "tokens"
                scope = "global"
            }
            
            let response = try await TychesAPI.shared.fetchLeaderboard(type: type, scope: scope, limit: 50)
            
            entries = response.leaderboard.map { entry in
                LeaderboardEntry(
                    id: entry.rank,
                    rank: entry.rank,
                    userId: entry.user_id,
                    userName: entry.displayName,
                    username: entry.username,
                    score: entry.score,
                    accuracy: entry.accuracy,
                    totalBets: entry.total_bets,
                    streak: nil
                )
            }
            userPosition = response.user_position
            
        } catch {
            errorMessage = "Failed to load leaderboard"
            print("Leaderboard error: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Top 3 Podium

struct TopThreePodium: View {
    let entries: [LeaderboardEntry]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // 2nd place
            if entries.count > 1 {
                PodiumColumn(entry: entries[1], rank: 2, height: 100)
            }
            
            // 1st place
            if entries.count > 0 {
                PodiumColumn(entry: entries[0], rank: 1, height: 130)
            }
            
            // 3rd place
            if entries.count > 2 {
                PodiumColumn(entry: entries[2], rank: 3, height: 80)
            }
        }
    }
}

struct PodiumColumn: View {
    let entry: LeaderboardEntry
    let rank: Int
    let height: CGFloat
    
    @State private var isAppeared = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Avatar
            ZStack {
                Circle()
                    .fill(TychesTheme.avatarGradient(for: entry.userId))
                    .frame(width: rank == 1 ? 70 : 56, height: rank == 1 ? 70 : 56)
                    .overlay(
                        Circle()
                            .stroke(rankColor, lineWidth: 3)
                    )
                    .shadow(color: rankColor.opacity(0.5), radius: 10)
                
                Text(String(entry.displayName.prefix(1)))
                    .font(rank == 1 ? .title : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Crown for 1st place
                if rank == 1 {
                    Text("👑")
                        .font(.system(size: 24))
                        .offset(y: -44)
                }
            }
            
            Text(entry.displayName)
                .font(rank == 1 ? .headline : .subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            Text(formatScore(entry.score))
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Podium block
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(rankGradient)
                    .frame(width: rank == 1 ? 100 : 80, height: height)
                
                Text(entry.rankEmoji)
                    .font(.system(size: rank == 1 ? 32 : 24))
            }
        }
        .scaleEffect(isAppeared ? 1 : 0.8)
        .opacity(isAppeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(rank - 1) * 0.1)) {
                isAppeared = true
            }
        }
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return TychesTheme.gold
        case 2: return Color(white: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return TychesTheme.primary
        }
    }
    
    private var rankGradient: LinearGradient {
        switch rank {
        case 1: return LinearGradient(colors: [TychesTheme.gold, TychesTheme.gold.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        case 2: return LinearGradient(colors: [Color(white: 0.85), Color(white: 0.7)], startPoint: .top, endPoint: .bottom)
        case 3: return LinearGradient(colors: [Color(red: 0.9, green: 0.6, blue: 0.3), Color(red: 0.7, green: 0.4, blue: 0.2)], startPoint: .top, endPoint: .bottom)
        default: return TychesTheme.primaryGradient
        }
    }
    
    private func formatScore(_ score: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: score)) ?? "\(Int(score))") + " pts"
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let rank: Int
    var isCurrentUser: Bool = false
    
    @State private var isAppeared = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Rank
            Text("\(rank)")
                .font(.headline.monospacedDigit())
                .foregroundColor(isCurrentUser ? TychesTheme.primary : .secondary)
                .frame(width: 30, alignment: .center)
            
            // Avatar
            Circle()
                .fill(TychesTheme.avatarGradient(for: entry.userId))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(entry.displayName.prefix(1)))
                        .font(.headline)
                        .foregroundColor(.white)
                )
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.displayName)
                        .font(.body.weight(.semibold))
                    
                    if let streak = entry.streak, streak >= 7 {
                        Text("🔥\(streak)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(TychesTheme.accent.opacity(0.15))
                            .cornerRadius(6)
                    }
                }
                
                HStack(spacing: 8) {
                    if let accuracy = entry.accuracy {
                        Text("\(Int(accuracy))% acc")
                            .font(.caption)
                            .foregroundColor(TychesTheme.success)
                    }
                    if let bets = entry.totalBets {
                        Text("\(bets) bets")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Score
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatScore(entry.score))
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(TychesTheme.primary)
                Text("tokens")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            isCurrentUser ?
            TychesTheme.primary.opacity(0.08) :
            Color.clear
        )
        .cornerRadius(12)
        .offset(x: isAppeared ? 0 : 50)
        .opacity(isAppeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(rank) * 0.05)) {
                isAppeared = true
            }
        }
    }
    
    private func formatScore(_ score: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: score)) ?? "\(Int(score))"
    }
}


import SwiftUI

// MARK: - Unified Avatar Component
// Reusable avatar for users, members, markets

/// Avatar size presets
enum AvatarSize: CGFloat {
    case small = 32
    case medium = 44
    case large = 56
    case xlarge = 72
    case xxlarge = 88
    
    var fontSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 18
        case .large: return 24
        case .xlarge: return 28
        case .xxlarge: return 36
        }
    }
}

// MARK: - User Avatar

/// Avatar for displaying a user with initials
struct UserAvatarView: View {
    let name: String?
    let username: String?
    let userId: Int
    let size: AvatarSize
    let showOnlineIndicator: Bool
    let isOnline: Bool
    
    init(
        name: String? = nil,
        username: String? = nil,
        userId: Int,
        size: AvatarSize = .medium,
        showOnlineIndicator: Bool = false,
        isOnline: Bool = false
    ) {
        self.name = name
        self.username = username
        self.userId = userId
        self.size = size
        self.showOnlineIndicator = showOnlineIndicator
        self.isOnline = isOnline
    }
    
    private var initials: String {
        let displayName = name ?? username ?? "U"
        return String(displayName.prefix(1)).uppercased()
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(TychesTheme.avatarGradient(for: userId))
                .frame(width: size.rawValue, height: size.rawValue)
            
            Text(initials)
                .font(.system(size: size.fontSize, weight: .bold))
                .foregroundColor(.white)
            
            if showOnlineIndicator && isOnline {
                Circle()
                    .fill(TychesTheme.success)
                    .frame(width: size.rawValue * 0.25, height: size.rawValue * 0.25)
                    .overlay(
                        Circle()
                            .stroke(TychesTheme.cardBackground, lineWidth: 2)
                    )
                    .offset(
                        x: size.rawValue * 0.35,
                        y: size.rawValue * 0.35
                    )
            }
        }
    }
}

// MARK: - Market Avatar

/// Avatar for displaying a market with emoji
struct MarketAvatarView: View {
    let emoji: String?
    let color: String?
    let size: AvatarSize
    let showShadow: Bool
    
    init(
        emoji: String? = nil,
        color: String? = nil,
        size: AvatarSize = .large,
        showShadow: Bool = true
    ) {
        self.emoji = emoji
        self.color = color
        self.size = size
        self.showShadow = showShadow
    }
    
    private var avatarColor: Color {
        parseHexColor(color, fallback: TychesTheme.primary)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(avatarColor)
                .frame(width: size.rawValue, height: size.rawValue)
            
            Text(emoji ?? "🎯")
                .font(.system(size: size.rawValue * 0.5))
        }
        .shadow(color: showShadow ? avatarColor.opacity(0.3) : .clear, radius: 8)
    }
}

// MARK: - Avatar Stack

/// A horizontal stack of overlapping avatars
struct AvatarStackView: View {
    let userIds: [Int]
    let userNames: [String?]
    let maxDisplay: Int
    let size: AvatarSize
    let overlap: CGFloat
    
    init(
        userIds: [Int],
        userNames: [String?] = [],
        maxDisplay: Int = 3,
        size: AvatarSize = .small,
        overlap: CGFloat = 8
    ) {
        self.userIds = userIds
        self.userNames = userNames
        self.maxDisplay = maxDisplay
        self.size = size
        self.overlap = overlap
    }
    
    var body: some View {
        HStack(spacing: -overlap) {
            ForEach(Array(userIds.prefix(maxDisplay).enumerated()), id: \.element) { index, userId in
                let name = index < userNames.count ? userNames[index] : nil
                UserAvatarView(name: name, userId: userId, size: size)
                    .overlay(
                        Circle()
                            .stroke(TychesTheme.cardBackground, lineWidth: 2)
                    )
            }
            
            if userIds.count > maxDisplay {
                ZStack {
                    Circle()
                        .fill(TychesTheme.surfaceElevated)
                        .frame(width: size.rawValue, height: size.rawValue)
                    
                    Text("+\(userIds.count - maxDisplay)")
                        .font(.system(size: size.fontSize * 0.7, weight: .bold))
                        .foregroundColor(TychesTheme.textSecondary)
                }
                .overlay(
                    Circle()
                        .stroke(TychesTheme.cardBackground, lineWidth: 2)
                )
            }
        }
    }
}

// MARK: - Rank Badge Overlay

/// A badge showing rank position (🥇, 🥈, 🥉, or number)
struct RankBadge: View {
    let rank: Int
    let size: CGFloat
    
    init(rank: Int, size: CGFloat = 18) {
        self.rank = rank
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(badgeColor)
                .frame(width: size, height: size)
            
            if rank <= 3 {
                Text(["🥇", "🥈", "🥉"][rank - 1])
                    .font(.system(size: size * 0.6))
            } else {
                Text("\(rank)")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var badgeColor: Color {
        switch rank {
        case 1: return TychesTheme.gold
        case 2: return Color.gray
        case 3: return Color.orange.opacity(0.8)
        default: return TychesTheme.primary
        }
    }
}

// MARK: - Level Badge

/// A badge showing user level
struct LevelBadge: View {
    let level: Int
    let size: CGFloat
    
    init(level: Int, size: CGFloat = 24) {
        self.level = level
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(TychesTheme.gold)
                .frame(width: size, height: size)
            
            Text("\(level)")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundColor(.black)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        Text("User Avatars").font(.headline)
        HStack(spacing: 16) {
            UserAvatarView(name: "Alice", userId: 1, size: .small)
            UserAvatarView(name: "Bob", userId: 2, size: .medium)
            UserAvatarView(name: "Charlie", userId: 3, size: .large)
            UserAvatarView(name: "Diana", userId: 4, size: .xlarge, showOnlineIndicator: true, isOnline: true)
        }
        
        Text("Market Avatars").font(.headline)
        HStack(spacing: 16) {
            MarketAvatarView(emoji: "🎯", color: "#6366F1", size: .medium)
            MarketAvatarView(emoji: "🏠", color: "#10B981", size: .large)
            MarketAvatarView(emoji: "⚽️", color: "#EF4444", size: .xlarge)
        }
        
        Text("Avatar Stack").font(.headline)
        AvatarStackView(userIds: [1, 2, 3, 4, 5, 6], maxDisplay: 4, size: .small)
        
        Text("Rank Badges").font(.headline)
        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                UserAvatarView(name: "Alice", userId: 1, size: .large)
                RankBadge(rank: 1)
                    .offset(x: 4, y: 4)
            }
            ZStack(alignment: .bottomTrailing) {
                UserAvatarView(name: "Bob", userId: 2, size: .large)
                RankBadge(rank: 2)
                    .offset(x: 4, y: 4)
            }
            ZStack(alignment: .bottomTrailing) {
                UserAvatarView(name: "Charlie", userId: 3, size: .large)
                RankBadge(rank: 5)
                    .offset(x: 4, y: 4)
            }
        }
    }
    .padding()
}


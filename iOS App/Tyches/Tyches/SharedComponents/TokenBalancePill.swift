import SwiftUI

// MARK: - Token Balance Pill

/// A pill displaying the user's token balance
struct TokenBalancePill: View {
    let balance: Double
    let style: TokenPillStyle
    
    enum TokenPillStyle {
        case standard   // Emoji + number
        case compact    // Just number with background
        case detailed   // With "tokens" label
    }
    
    init(balance: Double, style: TokenPillStyle = .standard) {
        self.balance = balance
        self.style = style
    }
    
    init(balance: Int, style: TokenPillStyle = .standard) {
        self.balance = Double(balance)
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .standard:
            standardPill
        case .compact:
            compactPill
        case .detailed:
            detailedPill
        }
    }
    
    // MARK: - Standard Pill
    
    private var standardPill: some View {
        HStack(spacing: 4) {
            Text("🪙")
                .font(.caption)
            Text(formatTokens(balance))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(TychesTheme.gold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(TychesTheme.gold.opacity(0.15))
        .cornerRadius(20)
    }
    
    // MARK: - Compact Pill
    
    private var compactPill: some View {
        HStack(spacing: 4) {
            Text("🪙")
                .font(.caption2)
            Text(formatTokens(balance))
                .font(.caption.weight(.bold))
                .foregroundColor(TychesTheme.gold)
        }
    }
    
    // MARK: - Detailed Pill
    
    private var detailedPill: some View {
        HStack(spacing: 6) {
            Text("🪙")
                .font(.callout)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(formatTokens(balance))
                    .font(.headline.bold())
                    .foregroundColor(TychesTheme.textPrimary)
                Text("tokens")
                    .font(.caption2)
                    .foregroundColor(TychesTheme.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(TychesTheme.gold.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Token Amount View

/// Display a token amount with optional sign (+/-)
struct TokenAmountView: View {
    let amount: Int
    let showSign: Bool
    let size: TokenAmountSize
    
    enum TokenAmountSize {
        case small
        case medium
        case large
        
        var fontSize: Font {
            switch self {
            case .small: return .caption
            case .medium: return .subheadline
            case .large: return .title3
            }
        }
        
        var emojiSize: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .body
            }
        }
    }
    
    init(amount: Int, showSign: Bool = false, size: TokenAmountSize = .medium) {
        self.amount = amount
        self.showSign = showSign
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text("🪙")
                .font(size.emojiSize)
            
            if showSign && amount > 0 {
                Text("+\(formatTokens(amount))")
                    .font(size.fontSize.weight(.bold))
                    .foregroundColor(TychesTheme.success)
            } else if showSign && amount < 0 {
                Text(formatTokens(amount))
                    .font(size.fontSize.weight(.bold))
                    .foregroundColor(TychesTheme.danger)
            } else {
                Text(formatTokens(amount))
                    .font(size.fontSize.weight(.bold))
                    .foregroundColor(TychesTheme.gold)
            }
        }
    }
}

// MARK: - Token Reward Badge

/// A badge showing token rewards (e.g., "+5,000 tokens")
struct TokenRewardBadge: View {
    let amount: Int
    let label: String?
    
    init(amount: Int, label: String? = nil) {
        self.amount = amount
        self.label = label
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text("🎁")
            
            VStack(alignment: .leading, spacing: 0) {
                Text("+\(formatTokens(amount))")
                    .font(.subheadline.bold())
                    .foregroundColor(TychesTheme.gold)
                
                if let label = label {
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(TychesTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(TychesTheme.gold.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Token Source Indicator

/// Shows where tokens come from (e.g., "5k/event", "2k/invite")
struct TokenSourceIndicator: View {
    let emoji: String
    let amount: String
    let source: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(emoji)
                .font(.caption)
            Text("\(amount)/\(source)")
                .font(.caption2.weight(.medium))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Payout Summary

/// A row showing potential payout/profit
struct PayoutSummaryRow: View {
    let label: String
    let amount: Int
    let isProfit: Bool
    
    init(label: String, amount: Int, isProfit: Bool = false) {
        self.label = label
        self.amount = amount
        self.isProfit = isProfit
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(TychesTheme.textSecondary)
            
            Spacer()
            
            if isProfit && amount > 0 {
                Text("+\(formatTokens(amount)) tokens")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(TychesTheme.success)
            } else {
                Text("\(formatTokens(amount)) tokens")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(TychesTheme.textPrimary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        Text("Token Pills").font(.headline)
        HStack(spacing: 12) {
            TokenBalancePill(balance: 10000, style: .standard)
            TokenBalancePill(balance: 10000, style: .compact)
        }
        TokenBalancePill(balance: 10000, style: .detailed)
        
        Text("Token Amounts").font(.headline)
        HStack(spacing: 16) {
            TokenAmountView(amount: 500, size: .small)
            TokenAmountView(amount: 500, showSign: true, size: .medium)
            TokenAmountView(amount: -200, showSign: true, size: .large)
        }
        
        Text("Token Rewards").font(.headline)
        HStack {
            TokenRewardBadge(amount: 5000, label: "for creating event")
            TokenRewardBadge(amount: 2000)
        }
        
        Text("Token Sources").font(.headline)
        HStack(spacing: 8) {
            TokenSourceIndicator(emoji: "🎯", amount: "5k", source: "event", color: TychesTheme.success)
            TokenSourceIndicator(emoji: "📮", amount: "2k", source: "invite", color: TychesTheme.primary)
            TokenSourceIndicator(emoji: "🏆", amount: "Win", source: "bets", color: TychesTheme.gold)
        }
        
        Text("Payout Summary").font(.headline)
        VStack(spacing: 8) {
            PayoutSummaryRow(label: "Your bet", amount: 100)
            PayoutSummaryRow(label: "Potential payout", amount: 250)
            PayoutSummaryRow(label: "Potential profit", amount: 150, isProfit: true)
        }
        .padding()
        .background(TychesTheme.cardBackground)
        .cornerRadius(12)
    }
    .padding()
}


import SwiftUI

// MARK: - Unified Odds Pill Component
// Consolidates OddsPill, QuickOddsPill, CompactOddsPill into one configurable component

/// Display style for the odds pill
enum OddsPillStyle {
    case standard    // Full size with vertical layout
    case compact     // Horizontal layout, smaller
    case minimal     // Just the percentage, very small
}

/// A reusable component for displaying YES/NO odds
struct OddsPillView: View {
    let side: String // "YES" or "NO"
    let percent: Int
    let odds: Double?
    let style: OddsPillStyle
    let showOdds: Bool
    
    init(
        side: String,
        percent: Int,
        odds: Double? = nil,
        style: OddsPillStyle = .standard,
        showOdds: Bool = false
    ) {
        self.side = side.uppercased()
        self.percent = percent
        self.odds = odds
        self.style = style
        self.showOdds = showOdds
    }
    
    private var sideColor: Color {
        side == "YES" ? TychesTheme.success : TychesTheme.danger
    }
    
    var body: some View {
        switch style {
        case .standard:
            standardPill
        case .compact:
            compactPill
        case .minimal:
            minimalPill
        }
    }
    
    // MARK: - Standard Style
    
    private var standardPill: some View {
        VStack(spacing: 2) {
            Text(side)
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
                .foregroundColor(sideColor)
            Text("\(percent)%")
                .font(.title3.bold())
                .foregroundColor(sideColor)
            
            if showOdds, let odds = odds {
                Text(formatOdds(odds))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(sideColor.opacity(0.12))
        .cornerRadius(10)
    }
    
    // MARK: - Compact Style
    
    private var compactPill: some View {
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
    
    // MARK: - Minimal Style
    
    private var minimalPill: some View {
        HStack(spacing: 4) {
            Text(side)
                .font(.caption2.bold())
                .foregroundColor(sideColor)
            Text("\(percent)%")
                .font(.caption.bold())
                .foregroundColor(sideColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(sideColor.opacity(0.12))
        .cornerRadius(8)
    }
}

// MARK: - Odds Row Component

/// A horizontal row showing YES and NO odds side by side
struct OddsRowView: View {
    let yesPercent: Int
    let noPercent: Int
    let yesOdds: Double?
    let noOdds: Double?
    let style: OddsPillStyle
    let showOdds: Bool
    
    init(
        yesPercent: Int,
        noPercent: Int,
        yesOdds: Double? = nil,
        noOdds: Double? = nil,
        style: OddsPillStyle = .standard,
        showOdds: Bool = false
    ) {
        self.yesPercent = yesPercent
        self.noPercent = noPercent
        self.yesOdds = yesOdds
        self.noOdds = noOdds
        self.style = style
        self.showOdds = showOdds
    }
    
    var body: some View {
        HStack(spacing: style == .standard ? 10 : 8) {
            OddsPillView(
                side: "YES",
                percent: yesPercent,
                odds: yesOdds,
                style: style,
                showOdds: showOdds
            )
            OddsPillView(
                side: "NO",
                percent: noPercent,
                odds: noOdds,
                style: style,
                showOdds: showOdds
            )
        }
    }
}

// MARK: - Bet Side Button

/// A tappable button for selecting YES or NO
struct BetSideButton: View {
    let side: String
    let percent: Int
    let odds: Double?
    let isSelected: Bool
    let action: () -> Void
    
    private var sideColor: Color {
        side.uppercased() == "YES" ? TychesTheme.success : TychesTheme.danger
    }
    
    private var sideGradient: LinearGradient {
        side.uppercased() == "YES" ? TychesTheme.successGradient : TychesTheme.dangerGradient
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(side.uppercased())
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundColor(isSelected ? .white : sideColor)
                
                Text("\(percent)%")
                    .font(.title.bold())
                    .foregroundColor(isSelected ? .white : sideColor)
                
                if let odds = odds {
                    Text(formatOdds(odds))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                isSelected
                    ? sideGradient
                    : LinearGradient(colors: [sideColor.opacity(0.08)], startPoint: .top, endPoint: .bottom)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : sideColor.opacity(0.3), lineWidth: 2)
            )
            .cornerRadius(16)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("Standard Style").font(.headline)
        OddsRowView(yesPercent: 65, noPercent: 35, style: .standard)
        
        Text("Compact Style").font(.headline)
        OddsRowView(yesPercent: 65, noPercent: 35, style: .compact)
        
        Text("Minimal Style").font(.headline)
        OddsRowView(yesPercent: 65, noPercent: 35, style: .minimal)
        
        Text("With Odds").font(.headline)
        OddsRowView(
            yesPercent: 65,
            noPercent: 35,
            yesOdds: 1.54,
            noOdds: 2.86,
            style: .standard,
            showOdds: true
        )
    }
    .padding()
}


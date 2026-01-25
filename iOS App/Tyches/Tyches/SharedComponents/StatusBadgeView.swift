import SwiftUI

// MARK: - Unified Status Badge Component
// Consolidates StatusBadge and EventStatusBadge into one component

/// Event status types
enum EventStatus: String {
    case open = "open"
    case closed = "closed"
    case resolved = "resolved"
    case cancelled = "cancelled"
    
    var displayText: String {
        switch self {
        case .open: return "LIVE"
        case .closed: return "CLOSED"
        case .resolved: return "RESOLVED"
        case .cancelled: return "CANCELLED"
        }
    }
    
    var color: Color {
        switch self {
        case .open: return .pink
        case .closed: return .gray
        case .resolved: return TychesTheme.success
        case .cancelled: return TychesTheme.danger
        }
    }
    
    var showPulse: Bool {
        self == .open
    }
    
    init(from string: String) {
        switch string.lowercased() {
        case "open": self = .open
        case "closed": self = .closed
        case "resolved": self = .resolved
        case "cancelled", "canceled": self = .cancelled
        default: self = .open
        }
    }
}

/// A reusable status badge for events
struct StatusBadgeView: View {
    let status: EventStatus
    let closesAt: String?
    let style: StatusBadgeStyle
    
    enum StatusBadgeStyle {
        case standard   // Shows status with optional time
        case compact    // Just the status text
        case pill       // Rounded pill shape
    }
    
    init(status: String, closesAt: String? = nil, style: StatusBadgeStyle = .standard) {
        self.status = EventStatus(from: status)
        self.closesAt = closesAt
        self.style = style
    }
    
    init(status: EventStatus, closesAt: String? = nil, style: StatusBadgeStyle = .standard) {
        self.status = status
        self.closesAt = closesAt
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .standard:
            standardBadge
        case .compact:
            compactBadge
        case .pill:
            pillBadge
        }
    }
    
    // MARK: - Standard Badge
    
    private var standardBadge: some View {
        HStack(spacing: 4) {
            if status.showPulse {
                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)
            }
            Text(displayText)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.12))
        .cornerRadius(6)
    }
    
    // MARK: - Compact Badge
    
    private var compactBadge: some View {
        HStack(spacing: 4) {
            if status.showPulse {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
            }
            Text(status.displayText)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
        }
        .foregroundColor(status.color)
    }
    
    // MARK: - Pill Badge
    
    private var pillBadge: some View {
        HStack(spacing: 4) {
            if status.showPulse {
                PulsingDot(color: status.color)
            }
            Text(status.displayText)
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(status.color.opacity(0.12))
        .clipShape(Capsule())
    }
    
    // MARK: - Display Text
    
    private var displayText: String {
        // If open and we have a close date, show time remaining
        if status == .open, let closeStr = closesAt, let closeDate = closeStr.toDate() {
            let remaining = closeDate.timeRemaining()
            if remaining != "Closed" {
                return remaining
            }
        }
        return status.displayText
    }
}

// MARK: - Pulsing Dot

struct PulsingDot: View {
    let color: Color
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Countdown Badge

/// A badge that shows a live countdown timer
struct CountdownBadgeView: View {
    let closesAt: String
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?
    
    var urgencyColor: Color {
        if timeRemaining < 3600 { return TychesTheme.danger } // < 1 hour
        if timeRemaining < 86400 { return TychesTheme.warning } // < 1 day
        return TychesTheme.primary
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(formatCountdown())
                .font(.system(.subheadline, design: .monospaced).bold())
                .foregroundColor(urgencyColor)
            Text("left")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(urgencyColor.opacity(0.12))
        .cornerRadius(10)
        .onAppear {
            calculateTimeRemaining()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func formatCountdown() -> String {
        guard let closeDate = closesAt.toDate() else { return "--:--" }
        return closeDate.timeRemainingVerbose()
    }
    
    private func calculateTimeRemaining() {
        if let closeDate = closesAt.toDate() {
            timeRemaining = max(0, closeDate.timeIntervalSinceNow)
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("Standard Style").font(.headline)
        HStack {
            StatusBadgeView(status: "open", style: .standard)
            StatusBadgeView(status: "closed", style: .standard)
            StatusBadgeView(status: "resolved", style: .standard)
        }
        
        Text("Compact Style").font(.headline)
        HStack {
            StatusBadgeView(status: "open", style: .compact)
            StatusBadgeView(status: "closed", style: .compact)
        }
        
        Text("Pill Style").font(.headline)
        HStack {
            StatusBadgeView(status: "open", style: .pill)
            StatusBadgeView(status: "resolved", style: .pill)
        }
        
        Text("Countdown Badge").font(.headline)
        CountdownBadgeView(closesAt: Date().addingTimeInterval(3600).toAPIString())
    }
    .padding()
}


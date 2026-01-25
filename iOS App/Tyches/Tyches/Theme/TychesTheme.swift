import SwiftUI

// MARK: - Tyches Design System v2.0
// Clean, bright, light-first design

struct TychesTheme {
    // MARK: - Core Colors (Light Theme)
    
    static let background = Color(hex: "F8F9FC")
    static let surface = Color.white
    static let surfaceElevated = Color(hex: "F1F3F8")
    static let cardBackground = Color.white
    
    // Primary - Vibrant Purple
    static let primary = Color(hex: "7C3AED")
    static let primaryLight = Color(hex: "A78BFA")
    static let primaryDark = Color(hex: "5B21B6")
    
    // Secondary - Teal
    static let secondary = Color(hex: "0891B2")
    
    // Accent - Pink
    static let accent = Color(hex: "EC4899")
    
    // Success - Green
    static let success = Color(hex: "059669")
    static let successLight = Color(hex: "10B981")
    
    // Danger - Red
    static let danger = Color(hex: "DC2626")
    static let dangerLight = Color(hex: "EF4444")
    
    // Warning - Amber
    static let warning = Color(hex: "D97706")
    
    // Gold - Premium
    static let gold = Color(hex: "CA8A04")
    
    // Text
    static let textPrimary = Color(hex: "1F2937")
    static let textSecondary = Color(hex: "6B7280")
    static let textTertiary = Color(hex: "9CA3AF")
    
    // MARK: - Gradients
    
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "7C3AED"), Color(hex: "6366F1")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let premiumGradient = LinearGradient(
        colors: [Color(hex: "EC4899"), Color(hex: "7C3AED")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let successGradient = LinearGradient(
        colors: [Color(hex: "10B981"), Color(hex: "059669")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let dangerGradient = LinearGradient(
        colors: [Color(hex: "EF4444"), Color(hex: "DC2626")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let glowGradient = LinearGradient(
        colors: [Color(hex: "7C3AED").opacity(0.2), Color.clear],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let cardGradient = LinearGradient(
        colors: [Color.white, Color(hex: "F8F9FC")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // MARK: - Glassmorphism (Light)
    
    static let glass = Color.black.opacity(0.03)
    static let glassBorder = Color.black.opacity(0.08)
    
    // MARK: - Avatar Gradients
    
    static func avatarGradient(for id: Int) -> LinearGradient {
        let gradients: [[Color]] = [
            [Color(hex: "FF6B6B"), Color(hex: "EE5A5A")],
            [Color(hex: "4ECDC4"), Color(hex: "45B7AA")],
            [Color(hex: "FFE66D"), Color(hex: "F4D35E")],
            [Color(hex: "95E1D3"), Color(hex: "7DD3C0")],
            [Color(hex: "F38181"), Color(hex: "E96D6D")],
            [Color(hex: "AA96DA"), Color(hex: "9B87CC")],
            [Color(hex: "FCBAD3"), Color(hex: "F4A7C4")],
            [Color(hex: "A8D8EA"), Color(hex: "96CDE0")],
        ]
        let colors = gradients[abs(id) % gradients.count]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    // MARK: - Spacing
    
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
    
    // MARK: - Corner Radius
    
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 24
    static let radiusFull: CGFloat = 9999
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Tyches Star Shape (Matches brand logo)

struct TychesStar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = rect.width
        let h = rect.height
        let cx = w / 2
        let cy = h / 2
        
        // 4-pointed star matching the logo
        // The star has a shorter top point, longer bottom point
        let innerRadius: CGFloat = min(w, h) * 0.18
        
        // Top point (shorter)
        let topY: CGFloat = h * 0.08
        // Bottom point (longer, more elongated)
        let bottomY: CGFloat = h * 0.95
        // Side points (centered vertically but slightly above middle)
        let sideY: CGFloat = cy * 0.9
        
        // Start from top point
        path.move(to: CGPoint(x: cx, y: topY))
        // To inner right-top
        path.addLine(to: CGPoint(x: cx + innerRadius, y: sideY - innerRadius * 0.8))
        // To right point
        path.addLine(to: CGPoint(x: w, y: sideY))
        // To inner right-bottom
        path.addLine(to: CGPoint(x: cx + innerRadius, y: sideY + innerRadius * 1.2))
        // To bottom point (elongated)
        path.addLine(to: CGPoint(x: cx, y: bottomY))
        // To inner left-bottom
        path.addLine(to: CGPoint(x: cx - innerRadius, y: sideY + innerRadius * 1.2))
        // To left point
        path.addLine(to: CGPoint(x: 0, y: sideY))
        // To inner left-top
        path.addLine(to: CGPoint(x: cx - innerRadius, y: sideY - innerRadius * 0.8))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - View Modifiers

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = TychesTheme.radiusLG
    
    func body(content: Content) -> some View {
        content
            .background(TychesTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.5), radius: radius)
            .shadow(color: color.opacity(0.3), radius: radius * 2)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = TychesTheme.radiusLG) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
    
    func glow(_ color: Color, radius: CGFloat = 10) -> some View {
        modifier(GlowEffect(color: color, radius: radius))
    }
}

// MARK: - Haptic Manager

class HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// MARK: - Scale Button Style (Legacy support)

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

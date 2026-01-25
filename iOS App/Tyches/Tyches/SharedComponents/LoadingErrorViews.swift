import SwiftUI

// MARK: - Loading View

/// A centered loading indicator with optional message
struct TychesLoadingView: View {
    let message: String
    
    init(_ message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(TychesTheme.primary)
            
            if !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(TychesTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Error View

/// A centered error message with optional retry button
struct TychesErrorView: View {
    let message: String
    let emoji: String
    let onRetry: (() -> Void)?
    
    init(
        _ message: String,
        emoji: String = "😕",
        onRetry: (() -> Void)? = nil
    ) {
        self.message = message
        self.emoji = emoji
        self.onRetry = onRetry
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text(emoji)
                .font(.system(size: 50))
            
            Text("Something went wrong")
                .font(.headline)
                .foregroundColor(TychesTheme.textPrimary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(TychesTheme.textSecondary)
                .multilineTextAlignment(.center)
            
            if let onRetry = onRetry {
                Button(action: onRetry) {
                    Text("Try Again")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(TychesTheme.primaryGradient)
                        .cornerRadius(20)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Empty State View

/// A centered empty state with customizable emoji, title, subtitle, and optional action
struct TychesEmptyStateView: View {
    let emoji: String
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        emoji: String,
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.emoji = emoji
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(TychesTheme.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Text(emoji)
                    .font(.system(size: 44))
            }
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundColor(TychesTheme.textPrimary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(TychesTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    action()
                    HapticManager.impact(.medium)
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text(actionTitle)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(TychesTheme.primaryGradient)
                    .cornerRadius(24)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Network Error View

/// Specific error view for network/connectivity issues
struct NetworkErrorView: View {
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 50))
                .foregroundColor(TychesTheme.textTertiary)
            
            Text("No Connection")
                .font(.headline)
                .foregroundColor(TychesTheme.textPrimary)
            
            Text("Check your internet connection and try again")
                .font(.subheadline)
                .foregroundColor(TychesTheme.textSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(TychesTheme.primaryGradient)
                .cornerRadius(20)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Toast View

/// A floating toast notification
struct TychesToastView: View {
    let message: String
    let type: ToastType
    
    enum ToastType {
        case success
        case error
        case info
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .success: return TychesTheme.success
            case .error: return TychesTheme.danger
            case .info: return TychesTheme.primary
            }
        }
    }
    
    init(_ message: String, type: ToastType = .info) {
        self.message = message
        self.type = type
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
            
            Text(message)
                .font(.subheadline.weight(.medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
        )
        .shadow(color: .black.opacity(0.2), radius: 10)
    }
}

// MARK: - Shimmer Loading Placeholder

/// A shimmering placeholder for loading states
struct ShimmerView: View {
    @State private var isAnimating = false
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = 8) {
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(TychesTheme.surfaceElevated)
            .opacity(isAnimating ? 0.6 : 1)
            .animation(
                .easeInOut(duration: 1).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

/// A shimmer card placeholder
struct ShimmerCardView: View {
    var body: some View {
        HStack(spacing: 14) {
            ShimmerView()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 8) {
                ShimmerView()
                    .frame(width: 150, height: 14)
                
                ShimmerView()
                    .frame(width: 100, height: 10)
            }
            
            Spacer()
        }
        .padding(14)
        .background(TychesTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 30) {
            Text("Loading").font(.headline)
            TychesLoadingView()
            
            Text("Error").font(.headline)
            TychesErrorView("Failed to load data") {
                print("Retry tapped")
            }
            
            Text("Empty State").font(.headline)
            TychesEmptyStateView(
                emoji: "🎯",
                title: "No events yet",
                subtitle: "Events you create will appear here",
                actionTitle: "Create Event"
            ) {
                print("Action tapped")
            }
            
            Text("Network Error").font(.headline)
            NetworkErrorView {
                print("Retry tapped")
            }
            
            Text("Toasts").font(.headline)
            VStack(spacing: 12) {
                TychesToastView("Bet placed successfully! 🎯", type: .success)
                TychesToastView("Something went wrong", type: .error)
                TychesToastView("New notification", type: .info)
            }
            
            Text("Shimmer").font(.headline)
            VStack(spacing: 8) {
                ShimmerCardView()
                ShimmerCardView()
            }
        }
        .padding()
    }
}


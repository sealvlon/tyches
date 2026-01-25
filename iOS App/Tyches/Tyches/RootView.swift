import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: SessionStore
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var showTutorial = false
    @State private var missionToast: MissionToastData?
    @State private var showConfetti = false
    @State private var confettiMessage: String?
    
    struct MissionToastData: Equatable {
        let message: String
        let emoji: String
    }
    
    var body: some View {
        Group {
            if session.isLoading {
                // Splash screen
                SplashView()
            } else if !hasCompletedOnboarding && !session.isAuthenticated {
                // Show onboarding for new users
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if session.isAuthenticated {
                ZStack {
                    MainTabView()
                    
                    // Tutorial overlay for first-time authenticated users
                    if showTutorial {
                        TutorialOverlay(isShowing: $showTutorial)
                            .transition(.opacity)
                    }
                    
                    // Confetti celebration
                    if showConfetti {
                        ConfettiView()
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
                .overlay(alignment: .top) {
                    if let toast = missionToast {
                        MissionCompletedToast(message: toast.message, emoji: toast.emoji)
                            .padding(.top, 50)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .onAppear {
                                HapticManager.notification(.success)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        missionToast = nil
                                    }
                                }
                            }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowConfetti"))) { notification in
                    confettiMessage = notification.userInfo?["message"] as? String
                    withAnimation(.easeIn(duration: 0.3)) {
                        showConfetti = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showConfetti = false
                            confettiMessage = nil
                        }
                    }
                }
                .onAppear {
                    if !UserDefaults.standard.bool(forKey: "hasCompletedTutorial") {
                        // Small delay before showing tutorial
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showTutorial = true
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .missionCompleted)) { notification in
                    let missionId = notification.userInfo?["mission_id"] as? String ?? ""
                    let toastData = missionToastData(for: missionId)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        missionToast = toastData
                    }
                }
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
    }
    
    private func missionToastData(for missionId: String) -> MissionToastData {
        switch missionId {
        case "bet_place":
            return MissionToastData(message: "Bet placed! Keep trading!", emoji: "📈")
        case "chat_post":
            return MissionToastData(message: "Message sent! Stay social!", emoji: "💬")
        case "invite_sent":
            return MissionToastData(message: "Invite sent! Grow your crew!", emoji: "🤝")
        case "event_create":
            return MissionToastData(message: "Event created! +5,000 tokens!", emoji: "✨")
        case "market_create":
            return MissionToastData(message: "Market created! +1,000 tokens!", emoji: "🏛️")
        default:
            return MissionToastData(message: "Mission completed!", emoji: "🎯")
        }
    }
}

// MARK: - Mission Completed Toast

struct MissionCompletedToast: View {
    let message: String
    let emoji: String
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.title2)
                .scaleEffect(isAnimating ? 1.2 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.5).repeatCount(2, autoreverses: true), value: isAnimating)
            
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "7C3AED"), Color(hex: "6366F1")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: TychesTheme.primary.opacity(0.4), radius: 12, x: 0, y: 4)
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Splash View

struct SplashView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            TychesTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Animated logo
                TychesAnimatedLogo()
                    .frame(width: 100, height: 100)
                    .scaleEffect(scale)
                
                Text("Tyches")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(TychesTheme.primaryGradient)
                
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(TychesTheme.primary)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                scale = 1
                opacity = 1
            }
        }
    }
}

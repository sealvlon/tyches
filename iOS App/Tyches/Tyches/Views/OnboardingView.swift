import SwiftUI

// MARK: - Onboarding View (Reimagined)
// Immersive, fun introduction to Tyches

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            emoji: "🎯",
            title: "Predict with Friends",
            subtitle: "Make predictions on real-life events with your friends. Will they happen? You decide.",
            color: Color(hex: "8B5CF6")
        ),
        OnboardingPage(
            emoji: "💰",
            title: "Play Money, Real Fun",
            subtitle: "Trade with virtual tokens. No real money. Just bragging rights and good times.",
            color: Color(hex: "10B981")
        ),
        OnboardingPage(
            emoji: "🏆",
            title: "Climb the Leaderboard",
            subtitle: "Track your accuracy. Earn achievements. Become the best predictor in your crew.",
            color: Color(hex: "F59E0B")
        )
    ]
    
    var body: some View {
        ZStack {
            // Background
            TychesTheme.background.ignoresSafeArea()
            
            // Animated gradient
            pages[currentPage].color.opacity(0.15)
                .blur(radius: 100)
                .offset(y: -100)
                .animation(.easeInOut(duration: 0.5), value: currentPage)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(TychesTheme.textSecondary)
                    .padding()
                }
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? pages[currentPage].color : Color.gray.opacity(0.3))
                            .frame(width: currentPage == index ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 32)
                
                // Action button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(.spring(response: 0.4)) {
                            currentPage += 1
                        }
                        HapticManager.impact(.light)
                    } else {
                        completeOnboarding()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(pages[currentPage].color)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
    
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Emoji with glow
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .blur(radius: 30)
                
                Text(page.emoji)
                    .font(.system(size: 100))
            }
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text(page.subtitle)
                    .font(.body)
                    .foregroundColor(TychesTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            Spacer()
        }
    }
    
    private func completeOnboarding() {
        HapticManager.notification(.success)
        withAnimation(.spring()) {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            hasCompletedOnboarding = true
        }
    }
}

struct OnboardingPage {
    let emoji: String
    let title: String
    let subtitle: String
    let color: Color
}

// MARK: - Tutorial Overlay (Updated)

struct TutorialOverlay: View {
    @Binding var isShowing: Bool
    @State private var currentStep = 0
    
    let steps = [
        TutorialStep(
            title: "Swipe to Predict",
            description: "Swipe right for YES, left for NO. It's that simple!",
            emoji: "👆",
            position: .middle
        ),
        TutorialStep(
            title: "Your Markets",
            description: "Your friend groups live here. Tap to see their predictions.",
            emoji: "👥",
            position: .middle
        ),
        TutorialStep(
            title: "Keep Your Streak",
            description: "Visit daily to build your streak and earn bonus XP!",
            emoji: "🔥",
            position: .top
        )
    ]
    
    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    advanceOrDismiss()
                }
            
            // Tutorial card
            VStack(spacing: 24) {
                Text(steps[currentStep].emoji)
                    .font(.system(size: 60))
                
                VStack(spacing: 8) {
                    Text(steps[currentStep].title)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text(steps[currentStep].description)
                        .font(.body)
                        .foregroundColor(TychesTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // Progress dots
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(currentStep == index ? TychesTheme.primary : Color.gray.opacity(0.4))
                            .frame(width: 8, height: 8)
                    }
                }
                
                // Tap hint
                Text("Tap to continue")
                    .font(.caption)
                    .foregroundColor(TychesTheme.textTertiary)
            }
            .padding(32)
            .background(TychesTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 40)
            .offset(y: yOffsetForStep(steps[currentStep].position))
            .animation(.spring(response: 0.4), value: currentStep)
        }
        .opacity(isShowing ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isShowing)
    }
    
    private func advanceOrDismiss() {
        HapticManager.selection()
        if currentStep < steps.count - 1 {
            currentStep += 1
        } else {
            UserDefaults.standard.set(true, forKey: "hasCompletedTutorial")
            isShowing = false
        }
    }
    
    private func yOffsetForStep(_ position: TutorialPosition) -> CGFloat {
        switch position {
        case .top: return -150
        case .middle: return 0
        case .bottom: return 150
        }
    }
}

struct TutorialStep {
    let title: String
    let description: String
    let emoji: String
    let position: TutorialPosition
}

enum TutorialPosition {
    case top, middle, bottom
}

// MARK: - Confetti View

// ConfettiView is now in SharedComponents/ConfettiView.swift

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}


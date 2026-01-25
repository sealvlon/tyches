import Foundation
import SwiftUI

/// Real-time social pulse tracker - shows live activity from friends
@MainActor
class SocialPulse: ObservableObject {
    static let shared = SocialPulse()
    
    @Published var liveBets: [LiveBet] = []
    @Published var friendActivity: [FriendActivity] = []
    @Published var trendingEvents: Set<Int> = []
    
    private var updateTask: Task<Void, Never>?
    
    struct LiveBet: Identifiable {
        let id: Int
        let eventId: Int
        let userName: String
        let side: String?
        let amount: Double
        let timestamp: Date
    }
    
    struct FriendActivity: Identifiable {
        let id: String
        let userId: Int
        let userName: String
        let action: String
        let eventId: Int?
        let timestamp: Date
    }
    
    func start() {
        stop()
        updateTask = Task {
            while !Task.isCancelled {
                await updateLiveActivity()
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s updates
            }
        }
    }
    
    func stop() {
        updateTask?.cancel()
        updateTask = nil
    }
    
    private func updateLiveActivity() async {
        // Fetch recent activity from multiple events in parallel
        // This creates a "live feed" feeling
    }
}


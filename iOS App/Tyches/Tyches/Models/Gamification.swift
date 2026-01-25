import Foundation
import SwiftUI

// MARK: - Streak System

struct StreakData: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var lastActivityDate: Date?
    var totalDaysActive: Int
    var weeklyActivity: [Bool] // Last 7 days
    
    init() {
        currentStreak = 0
        longestStreak = 0
        lastActivityDate = nil
        totalDaysActive = 0
        weeklyActivity = Array(repeating: false, count: 7)
    }
    
    var isActiveToday: Bool {
        guard let lastDate = lastActivityDate else { return false }
        return Calendar.current.isDateInToday(lastDate)
    }
    
    var streakEmoji: String {
        if currentStreak >= 30 { return "🔥🔥🔥" }
        if currentStreak >= 14 { return "🔥🔥" }
        if currentStreak >= 7 { return "🔥" }
        if currentStreak >= 3 { return "✨" }
        return "⚡️"
    }
    
    var streakMessage: String {
        if currentStreak >= 30 { return "Legendary streak!" }
        if currentStreak >= 14 { return "On fire!" }
        if currentStreak >= 7 { return "Hot streak!" }
        if currentStreak >= 3 { return "Keep it up!" }
        if currentStreak == 0 { return "Start your streak!" }
        return "Building momentum!"
    }
}

// MARK: - Achievement System

enum AchievementCategory: String, Codable, CaseIterable {
    case trading = "Trading"
    case social = "Social"
    case prediction = "Prediction"
    case streak = "Streak"
    case special = "Special"
}

struct Achievement: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let emoji: String
    let category: AchievementCategory
    let requirement: Int
    var progress: Int
    var unlockedAt: Date?
    
    var isUnlocked: Bool { unlockedAt != nil }
    var progressPercent: Double { min(Double(progress) / Double(requirement), 1.0) }
    
    static let allAchievements: [Achievement] = [
        // Trading achievements
        Achievement(id: "first_bet", name: "First Bet", description: "Place your first bet", emoji: "🎯", category: .trading, requirement: 1, progress: 0),
        Achievement(id: "high_roller", name: "High Roller", description: "Place 50 bets", emoji: "🎰", category: .trading, requirement: 50, progress: 0),
        Achievement(id: "whale", name: "Whale", description: "Bet 10,000 tokens total", emoji: "🐋", category: .trading, requirement: 10000, progress: 0),
        Achievement(id: "diversified", name: "Diversified", description: "Bet on 10 different events", emoji: "📊", category: .trading, requirement: 10, progress: 0),
        
        // Prediction achievements
        Achievement(id: "oracle", name: "Oracle", description: "Win 10 predictions", emoji: "🔮", category: .prediction, requirement: 10, progress: 0),
        Achievement(id: "fortune_teller", name: "Fortune Teller", description: "Win 5 in a row", emoji: "🌟", category: .prediction, requirement: 5, progress: 0),
        Achievement(id: "psychic", name: "Psychic", description: "Achieve 80% accuracy", emoji: "🧠", category: .prediction, requirement: 80, progress: 0),
        
        // Social achievements
        Achievement(id: "social_butterfly", name: "Social Butterfly", description: "Add 5 friends", emoji: "🦋", category: .social, requirement: 5, progress: 0),
        Achievement(id: "gossip_queen", name: "Gossip Queen", description: "Post 20 gossip messages", emoji: "💬", category: .social, requirement: 20, progress: 0),
        Achievement(id: "event_creator", name: "Event Creator", description: "Create your first event", emoji: "✨", category: .social, requirement: 1, progress: 0),
        Achievement(id: "market_maker", name: "Market Maker", description: "Create a market", emoji: "🏛️", category: .social, requirement: 1, progress: 0),
        
        // Streak achievements
        Achievement(id: "week_warrior", name: "Week Warrior", description: "7 day streak", emoji: "🗓️", category: .streak, requirement: 7, progress: 0),
        Achievement(id: "monthly_master", name: "Monthly Master", description: "30 day streak", emoji: "📅", category: .streak, requirement: 30, progress: 0),
        Achievement(id: "year_legend", name: "Year Legend", description: "365 day streak", emoji: "🏆", category: .streak, requirement: 365, progress: 0),
        
        // Special achievements
        Achievement(id: "early_adopter", name: "Early Adopter", description: "Join Tyches in 2024", emoji: "🚀", category: .special, requirement: 1, progress: 0),
        Achievement(id: "perfect_week", name: "Perfect Week", description: "Bet every day for a week", emoji: "💎", category: .special, requirement: 7, progress: 0),
    ]
}

// MARK: - Leaderboard Entry

struct LeaderboardEntry: Identifiable, Codable {
    let id: Int
    let rank: Int
    let userId: Int
    let userName: String
    let username: String?
    let score: Double
    let accuracy: Double?
    let totalBets: Int?
    let streak: Int?
    
    var displayName: String {
        userName.isEmpty ? (username ?? "User") : userName
    }
    
    var rankEmoji: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return ""
        }
    }
}

// MARK: - Daily Challenge

struct DailyChallenge: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let emoji: String
    let reward: Int
    var progress: Int
    let target: Int
    var completedAt: Date?
    
    var isCompleted: Bool { completedAt != nil }
    var progressPercent: Double { min(Double(progress) / Double(target), 1.0) }
    
    static let dailyChallenges: [DailyChallenge] = [
        DailyChallenge(id: "daily_bet", title: "Daily Trader", description: "Place 3 bets today", emoji: "📈", reward: 100, progress: 0, target: 3),
        DailyChallenge(id: "daily_gossip", title: "Chatterbox", description: "Post 2 gossip messages", emoji: "💬", reward: 50, progress: 0, target: 2),
        DailyChallenge(id: "daily_explore", title: "Explorer", description: "View 5 different events", emoji: "🔍", reward: 50, progress: 0, target: 5),
    ]
}

// MARK: - Gamification Manager

@MainActor
class GamificationManager: ObservableObject {
    static let shared = GamificationManager()
    
    @Published var streak: StreakData
    @Published var achievements: [Achievement]
    @Published var dailyChallenges: [DailyChallenge]
    @Published var xp: Int = 0
    @Published var level: Int = 1
    @Published var isLoading = false
    @Published var lastSynced: Date?
    
    private let streakKey = "tyches_streak_data"
    private let achievementsKey = "tyches_achievements"
    private let xpKey = "tyches_xp"
    
    var xpForNextLevel: Int { level * 500 }
    var xpProgress: Double { Double(xp) / Double(xpForNextLevel) }
    
    var levelTitle: String {
        switch level {
        case 1...5: return "Novice Trader"
        case 6...10: return "Market Watcher"
        case 11...20: return "Odds Master"
        case 21...30: return "Prediction Pro"
        case 31...50: return "Oracle"
        case 51...75: return "Market Sage"
        case 76...99: return "Legend"
        default: return "Tyches God"
        }
    }
    
    private init() {
        streak = StreakData()
        achievements = Achievement.allAchievements
        dailyChallenges = DailyChallenge.dailyChallenges
        loadLocalData()
    }
    
    // MARK: - Sync with Backend
    
    func syncWithBackend() async {
        isLoading = true
        
        // Sync all data in parallel
        async let streakTask: () = syncStreak()
        async let achievementsTask: () = syncAchievements()
        async let challengesTask: () = syncDailyChallenges()
        
        _ = await (streakTask, achievementsTask, challengesTask)
        
        lastSynced = Date()
        isLoading = false
    }
    
    private func syncStreak() async {
        do {
            let response = try await TychesAPI.shared.fetchStreak()
            streak.currentStreak = response.current_streak
            streak.longestStreak = response.longest_streak
            streak.totalDaysActive = response.total_days_active
            streak.weeklyActivity = response.weekly_activity
            
            if let dateStr = response.last_activity_date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                streak.lastActivityDate = formatter.date(from: dateStr)
            }
            
            saveLocalData()
        } catch {
            // Fall back to local data
            print("Failed to sync streak: \(error)")
        }
    }
    
    private func syncAchievements() async {
        do {
            let response = try await TychesAPI.shared.fetchAchievements()
            
            // Update local achievements with backend data (backend calculates from database)
            for backendAchievement in response.achievements {
                if let index = achievements.firstIndex(where: { $0.id == backendAchievement.id }) {
                    // Always use backend progress as source of truth
                    achievements[index].progress = backendAchievement.progress
                    
                    // Update unlock status
                    if backendAchievement.is_unlocked {
                        if achievements[index].unlockedAt == nil {
                            // Just unlocked - play haptic
                            HapticManager.notification(.success)
                        }
                        if let unlockedStr = backendAchievement.unlocked_at {
                            // Try multiple date formats
                            let isoFormatter = ISO8601DateFormatter()
                            let mysqlFormatter = DateFormatter()
                            mysqlFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                            
                            achievements[index].unlockedAt = isoFormatter.date(from: unlockedStr) 
                                ?? mysqlFormatter.date(from: unlockedStr)
                                ?? Date()
                        } else {
                            achievements[index].unlockedAt = Date()
                        }
                    }
                }
            }
            
            saveLocalData()
            print("[Gamification] Synced \(response.achievements.count) achievements, \(response.unlocked) unlocked")
        } catch {
            print("[Gamification] Failed to sync achievements: \(error)")
        }
    }
    
    private func syncDailyChallenges() async {
        do {
            let response = try await TychesAPI.shared.fetchDailyChallenges()
            
            // Update local challenges with backend data
            for backendChallenge in response.challenges {
                if let index = dailyChallenges.firstIndex(where: { $0.id == backendChallenge.id }) {
                    dailyChallenges[index].progress = backendChallenge.progress
                    if backendChallenge.is_completed, let completedStr = backendChallenge.completed_at {
                        let formatter = ISO8601DateFormatter()
                        dailyChallenges[index].completedAt = formatter.date(from: completedStr)
                    }
                }
            }
            
            saveLocalData()
        } catch {
            print("Failed to sync daily challenges: \(error)")
        }
    }
    
    // MARK: - Record Activity (syncs to backend)
    
    func recordActivity() async {
        // Optimistic local update
        let now = Date()
        let calendar = Calendar.current
        
        if let lastDate = streak.lastActivityDate {
            if !calendar.isDateInToday(lastDate) {
                if calendar.isDateInYesterday(lastDate) {
                    streak.currentStreak += 1
                } else {
                    streak.currentStreak = 1
                }
            }
        } else {
            streak.currentStreak = 1
        }
        
        streak.lastActivityDate = now
        streak.longestStreak = max(streak.longestStreak, streak.currentStreak)
        updateWeeklyActivity()
        
        // Sync to backend
        do {
            let response = try await TychesAPI.shared.recordDailyActivity()
            streak.currentStreak = response.current_streak
            streak.longestStreak = response.longest_streak
            
            if response.is_new_day && response.xp_awarded > 0 {
                addXP(response.xp_awarded)
            }
        } catch {
            print("Failed to record activity: \(error)")
        }
        
        saveLocalData()
    }
    
    func recordBet(amount: Int) {
        checkAchievement("first_bet", progress: 1)
        incrementAchievement("high_roller")
        incrementAchievement("whale", by: amount)
        incrementDailyChallenge("daily_bet")
        addXP(5)
        saveLocalData()
        
        // Async backend update
        Task {
            _ = try? await TychesAPI.shared.updateAchievement(id: "high_roller")
        }
    }
    
    func recordGossip() {
        incrementAchievement("gossip_queen")
        incrementDailyChallenge("daily_gossip")
        addXP(2)
        saveLocalData()
        
        Task {
            _ = try? await TychesAPI.shared.updateAchievement(id: "gossip_queen")
        }
    }
    
    func recordEventView() {
        incrementDailyChallenge("daily_explore")
        saveLocalData()
    }
    
    func recordWin() {
        incrementAchievement("oracle")
        addXP(20)
        HapticManager.notification(.success)
        saveLocalData()
        
        Task {
            _ = try? await TychesAPI.shared.updateAchievement(id: "oracle")
        }
    }
    
    func addXP(_ amount: Int) {
        xp += amount
        while xp >= xpForNextLevel {
            xp -= xpForNextLevel
            level += 1
            HapticManager.notification(.success)
            Analytics.shared.trackLevelUp(level: level, title: levelTitle)
        }
    }
    
    private func checkAchievement(_ id: String, progress: Int) {
        if let index = achievements.firstIndex(where: { $0.id == id }) {
            achievements[index].progress = progress
            if achievements[index].progress >= achievements[index].requirement && achievements[index].unlockedAt == nil {
                achievements[index].unlockedAt = Date()
                HapticManager.notification(.success)
                Analytics.shared.trackAchievementUnlocked(achievementId: id, achievementName: achievements[index].name)
            }
        }
    }
    
    private func incrementAchievement(_ id: String, by amount: Int = 1) {
        if let index = achievements.firstIndex(where: { $0.id == id }) {
            achievements[index].progress += amount
            if achievements[index].progress >= achievements[index].requirement && achievements[index].unlockedAt == nil {
                achievements[index].unlockedAt = Date()
                HapticManager.notification(.success)
                Analytics.shared.trackAchievementUnlocked(achievementId: id, achievementName: achievements[index].name)
            }
        }
    }
    
    private func incrementDailyChallenge(_ id: String) {
        if let index = dailyChallenges.firstIndex(where: { $0.id == id }) {
            dailyChallenges[index].progress += 1
            if dailyChallenges[index].progress >= dailyChallenges[index].target && dailyChallenges[index].completedAt == nil {
                dailyChallenges[index].completedAt = Date()
                addXP(dailyChallenges[index].reward)
                HapticManager.notification(.success)
                Analytics.shared.trackDailyChallengeCompleted(challengeId: id, reward: dailyChallenges[index].reward)
            }
        }
    }
    
    private func updateWeeklyActivity() {
        streak.weeklyActivity = Array(streak.weeklyActivity.dropFirst()) + [true]
    }
    
    // MARK: - Local Persistence
    
    private func loadLocalData() {
        if let data = UserDefaults.standard.data(forKey: streakKey),
           let decoded = try? JSONDecoder().decode(StreakData.self, from: data) {
            streak = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: achievementsKey),
           let decoded = try? JSONDecoder().decode([Achievement].self, from: data) {
            achievements = decoded
        }
        
        xp = UserDefaults.standard.integer(forKey: xpKey)
        level = max(1, xp / 500 + 1)
    }
    
    private func saveLocalData() {
        if let encoded = try? JSONEncoder().encode(streak) {
            UserDefaults.standard.set(encoded, forKey: streakKey)
        }
        
        if let encoded = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(encoded, forKey: achievementsKey)
        }
        
        UserDefaults.standard.set(xp, forKey: xpKey)
    }
}


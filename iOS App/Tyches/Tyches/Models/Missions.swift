import Foundation

struct Mission: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let reward: Int
    let target: Int
    let progress: Int
    let type: String // e.g., "daily" or "weekly"
    
    var isCompleted: Bool { progress >= target }
    var progressPercent: Double { min(1.0, Double(progress) / Double(target)) }
}


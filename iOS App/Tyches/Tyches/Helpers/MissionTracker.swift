import Foundation

/// Fire-and-forget mission progress updates for core actions.
enum MissionTracker {
    static func track(action: Action) {
        Task {
            do {
                switch action {
                case .betPlaced:
                    let response = try await TychesAPI.shared.updateMission(id: "bet_place", increment: 1)
                    notifyIfCompleted(response)
                case .chatPosted:
                    let response = try await TychesAPI.shared.updateMission(id: "chat_post", increment: 1)
                    notifyIfCompleted(response)
                case .inviteSent:
                    let response = try await TychesAPI.shared.updateMission(id: "invite_sent", increment: 1)
                    notifyIfCompleted(response)
                case .eventCreated:
                    let response = try await TychesAPI.shared.updateMission(id: "event_create", increment: 1)
                    notifyIfCompleted(response)
                case .marketCreated:
                    let response = try await TychesAPI.shared.updateMission(id: "market_create", increment: 1)
                    notifyIfCompleted(response)
                }
            } catch {
                // Ignore failures; missions are best-effort.
            }
        }
    }
    
    private static func notifyIfCompleted(_ response: TychesAPI.MissionProgressResponse) {
        if response.completed {
            NotificationCenter.default.post(
                name: .missionCompleted,
                object: nil,
                userInfo: ["mission_id": response.mission_id]
            )
        }
    }
    
    enum Action {
        case betPlaced
        case chatPosted
        case inviteSent
        case eventCreated
        case marketCreated
    }
}

extension Notification.Name {
    static let missionCompleted = Notification.Name("MissionCompleted")
}

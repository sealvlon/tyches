import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var notifications: [TychesAPI.NotificationData] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var unreadCount = 0
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if notifications.isEmpty {
                    emptyState
                } else {
                    notificationsList
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if unreadCount > 0 {
                        Button("Mark All Read") {
                            markAllRead()
                        }
                    }
                }
            }
            .task {
                await loadNotifications()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🔔")
                .font(.system(size: 60))
            Text("No notifications")
                .font(.headline)
            Text("You're all caught up!")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var notificationsList: some View {
        List {
            ForEach(notifications) { notification in
                NotificationRow(notification: notification)
                    .onTapGesture {
                        handleTap(notification)
                    }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await loadNotifications()
        }
    }
    
    private func loadNotifications() async {
        do {
            let response = try await TychesAPI.shared.fetchNotifications()
            notifications = response.notifications
            unreadCount = response.unread_count
        } catch {
            errorMessage = "Failed to load notifications"
        }
        isLoading = false
    }
    
    private func markAllRead() {
        Task {
            do {
                _ = try await TychesAPI.shared.markNotificationsRead()
                await loadNotifications()
            } catch {
                // Handle error
            }
        }
    }
    
    private func handleTap(_ notification: TychesAPI.NotificationData) {
        // Mark as read
        if !notification.is_read {
            Task {
                _ = try? await TychesAPI.shared.markNotificationsRead(ids: [notification.id])
                await loadNotifications()
            }
        }
        
        // Navigate based on notification type
        // This would integrate with navigation state in a full implementation
    }
}

struct NotificationRow: View {
    let notification: TychesAPI.NotificationData
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.subheadline.weight(notification.is_read ? .regular : .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(notification.time_ago)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let body = notification.body, !body.isEmpty {
                    Text(body)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            // Unread indicator
            if !notification.is_read {
                Circle()
                    .fill(TychesTheme.primary)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
        .opacity(notification.is_read ? 0.7 : 1)
    }
    
    private var iconName: String {
        switch notification.type {
        case "bet_placed": return "chart.line.uptrend.xyaxis"
        case "bet_won": return "trophy.fill"
        case "bet_lost": return "xmark.circle"
        case "event_created": return "sparkles"
        case "event_closing": return "clock.badge.exclamationmark"
        case "event_resolved": return "checkmark.seal.fill"
        case "gossip_mention": return "at"
        case "gossip_reply": return "bubble.left.and.bubble.right"
        case "friend_request": return "person.badge.plus"
        case "friend_accepted": return "person.2.fill"
        case "market_invite": return "person.3.fill"
        case "streak_reminder": return "flame"
        case "achievement_unlocked": return "medal.fill"
        case "challenge_completed": return "star.fill"
        default: return "bell.fill"
        }
    }
    
    private var iconColor: Color {
        switch notification.type {
        case "bet_won", "event_resolved", "challenge_completed": return TychesTheme.success
        case "bet_lost": return TychesTheme.danger
        case "streak_reminder": return .orange
        case "achievement_unlocked": return TychesTheme.gold
        case "friend_request", "friend_accepted", "market_invite": return TychesTheme.primary
        case "event_closing": return TychesTheme.warning
        default: return .secondary
        }
    }
}

#Preview {
    NotificationsView()
}


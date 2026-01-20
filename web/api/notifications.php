<?php
/**
 * Notifications API
 * GET: Fetch user's notifications (paginated)
 * POST: Mark notifications as read
 */

declare(strict_types=1);

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/security.php';
require_once __DIR__ . '/helpers.php';

header('Content-Type: application/json');

tyches_start_session();

// Require authentication
if (empty($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['error' => 'Authentication required']);
    exit;
}

$userId = (int) $_SESSION['user_id'];
$method = $_SERVER['REQUEST_METHOD'];

try {
    // Get database connection
    $pdo = get_pdo();
    
    // Ensure notifications table exists
    ensureNotificationsTable($pdo);
} catch (Exception $e) {
    error_log('Notifications DB error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Database connection error']);
    exit;
}

if ($method === 'GET') {
    try {
        $page = max(1, (int) ($_GET['page'] ?? 1));
        $limit = min(50, max(10, (int) ($_GET['limit'] ?? 20)));
        $offset = ($page - 1) * $limit;
        $unreadOnly = isset($_GET['unread']) && $_GET['unread'] === '1';
        
        $whereClause = $unreadOnly ? "AND is_read = 0" : "";
        
        // Fetch notifications - use string interpolation for LIMIT/OFFSET since they're already integers
        $sql = "
            SELECT 
                id,
                type,
                title,
                message,
                url,
                is_read,
                created_at
            FROM notifications
            WHERE user_id = ? {$whereClause}
            ORDER BY created_at DESC
            LIMIT {$limit} OFFSET {$offset}
        ";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([$userId]);
        $notifications = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Count unread
        $stmt = $pdo->prepare("SELECT COUNT(*) FROM notifications WHERE user_id = ? AND is_read = 0");
        $stmt->execute([$userId]);
        $unreadCount = (int) $stmt->fetchColumn();
        
        // Count total
        $stmt = $pdo->prepare("SELECT COUNT(*) FROM notifications WHERE user_id = ?");
        $stmt->execute([$userId]);
        $totalCount = (int) $stmt->fetchColumn();
        
        // If user has no notifications, create a welcome notification
        if (empty($notifications) && $page === 1) {
            createWelcomeNotification($pdo, $userId);
            // Re-fetch after creating welcome notification
            $stmt = $pdo->prepare($sql);
            $stmt->execute([$userId]);
            $notifications = $stmt->fetchAll(PDO::FETCH_ASSOC);
        }
        
        // Format notifications
        $formatted = array_map(function($n) {
            return [
                'id' => (int) $n['id'],
                'type' => $n['type'],
                'title' => $n['title'],
                'message' => $n['message'] ?? '',
                'url' => $n['url'] ?? null,
                'is_read' => (bool) $n['is_read'],
                'created_at' => $n['created_at'],
                'time_ago' => timeAgo($n['created_at'])
            ];
        }, $notifications);
        
        echo json_encode([
            'notifications' => $formatted,
            'unread_count' => $unreadCount,
            'total_count' => $totalCount,
            'page' => $page,
            'has_more' => ($offset + $limit) < $totalCount
        ]);
        exit;
    } catch (Exception $e) {
        error_log('Notifications fetch error: ' . $e->getMessage());
        http_response_code(500);
        echo json_encode(['error' => 'Failed to fetch notifications', 'debug' => $e->getMessage()]);
        exit;
    }
}

if ($method === 'POST') {
    try {
        $input = json_decode(file_get_contents('php://input'), true);
        $action = $input['action'] ?? 'mark_read';
        
    if ($action === 'mark_all_read') {
        // Mark all as read
        $stmt = $pdo->prepare("UPDATE notifications SET is_read = 1 WHERE user_id = ? AND is_read = 0");
        $stmt->execute([$userId]);
        $affected = $stmt->rowCount();
        
        echo json_encode(['ok' => true, 'marked_read' => $affected]);
        exit;
    }
    
    if ($action === 'mark_read') {
        // Mark specific notification(s) as read
        $ids = $input['ids'] ?? [];
        $notificationId = $input['notification_id'] ?? null;
        
        // Support single notification_id or array of ids
        if ($notificationId !== null) {
            $ids = [(int)$notificationId];
        }
        
        if (empty($ids)) {
            // Mark all as read (fallback)
            $stmt = $pdo->prepare("UPDATE notifications SET is_read = 1 WHERE user_id = ? AND is_read = 0");
            $stmt->execute([$userId]);
            $affected = $stmt->rowCount();
        } else {
            // Mark specific IDs
            $placeholders = implode(',', array_fill(0, count($ids), '?'));
            $stmt = $pdo->prepare("UPDATE notifications SET is_read = 1 WHERE user_id = ? AND id IN ({$placeholders}) AND is_read = 0");
            $stmt->execute(array_merge([$userId], $ids));
            $affected = $stmt->rowCount();
        }
        
        echo json_encode(['ok' => true, 'marked_read' => $affected]);
        exit;
    }
        
        if ($action === 'delete') {
            $ids = $input['ids'] ?? [];
            
            if (!empty($ids)) {
                $placeholders = implode(',', array_fill(0, count($ids), '?'));
                $stmt = $pdo->prepare("DELETE FROM notifications WHERE user_id = ? AND id IN ({$placeholders})");
                $stmt->execute(array_merge([$userId], $ids));
                $affected = $stmt->rowCount();
                
                echo json_encode(['ok' => true, 'deleted' => $affected]);
                exit;
            }
        }
        
        http_response_code(400);
        echo json_encode(['error' => 'Invalid action']);
        exit;
    } catch (Exception $e) {
        error_log('Notifications POST error: ' . $e->getMessage());
        http_response_code(500);
        echo json_encode(['error' => 'Failed to update notifications']);
        exit;
    }
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);

// Helper functions
function ensureNotificationsTable(PDO $pdo): void {
    // Table should already exist - this is now a no-op
    // The table was created/fixed by test-notification.php
}

function timeAgo(string $datetime): string {
    $time = strtotime($datetime);
    $diff = time() - $time;
    
    if ($diff < 60) return 'just now';
    if ($diff < 3600) return floor($diff / 60) . 'm ago';
    if ($diff < 86400) return floor($diff / 3600) . 'h ago';
    if ($diff < 604800) return floor($diff / 86400) . 'd ago';
    return date('M j', $time);
}

/**
 * Helper function to create a notification (call from other API endpoints)
 */
function createNotification(PDO $pdo, int $userId, string $type, string $title, string $message, ?string $url = null): int {
    $stmt = $pdo->prepare("
        INSERT INTO notifications (user_id, type, title, message, url)
        VALUES (?, ?, ?, ?, ?)
    ");
    $stmt->execute([$userId, $type, $title, $message, $url]);
    return (int) $pdo->lastInsertId();
}

/**
 * Create welcome notifications for new users
 */
function createWelcomeNotification(PDO $pdo, int $userId): void {
    try {
        // Check if welcome notification already exists
        $stmt = $pdo->prepare("SELECT id FROM notifications WHERE user_id = ? AND type = 'welcome' LIMIT 1");
        $stmt->execute([$userId]);
        if ($stmt->fetch()) {
            return; // Already has welcome notification
        }
        
        // Create welcome notification
        $stmt = $pdo->prepare("
            INSERT INTO notifications (user_id, type, title, message, created_at)
            VALUES (?, 'welcome', 'Welcome to Tyches! 🎉', 'Start by joining a market or creating your own. Make predictions with friends and see who knows the future!', NOW())
        ");
        $stmt->execute([$userId]);
        
        // Add a tip notification
        $stmt = $pdo->prepare("
            INSERT INTO notifications (user_id, type, title, message, created_at)
            VALUES (?, 'tip', '💡 Pro Tip', 'Create a market and invite your friends to start making predictions together!', DATE_SUB(NOW(), INTERVAL 1 MINUTE))
        ");
        $stmt->execute([$userId]);
    } catch (Exception $e) {
        error_log('createWelcomeNotification error: ' . $e->getMessage());
    }
}

/**
 * Notification types:
 * - bet_placed: Someone bet on an event you're in
 * - bet_won: You won a bet
 * - bet_lost: You lost a bet
 * - event_created: New event in your market
 * - event_closing: Event closing soon
 * - event_resolved: Event was resolved
 * - gossip_mention: Someone mentioned you in gossip
 * - gossip_reply: Someone replied to your gossip
 * - friend_request: Someone sent you a friend request
 * - friend_accepted: Someone accepted your friend request
 * - market_invite: Invited to join a market
 * - streak_reminder: Don't lose your streak
 * - achievement_unlocked: You unlocked an achievement
 * - challenge_completed: You completed a daily challenge
 */

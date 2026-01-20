<?php
// api/event-activity.php
// Activity feed for events and global feed across user's markets.

declare(strict_types=1);

require_once __DIR__ . '/security.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method !== 'GET') {
    json_response(['error' => 'Method not allowed'], 405);
}

try {
    handle_get_event_activity();
} catch (Throwable $e) {
    error_log('event-activity.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    json_response(['error' => 'Server error'], 500);
}

/**
 * GET /api/event-activity.php?event_id=123  → Activity for specific event
 * GET /api/event-activity.php?limit=10      → Global activity feed across user's markets
 */
function handle_get_event_activity(): void {
    $uid = require_auth();
    $pdo = get_pdo();

    $eventId = isset($_GET['event_id']) ? (int)$_GET['event_id'] : 0;
    $limit = isset($_GET['limit']) ? min((int)$_GET['limit'], 50) : 20;
    
    // If no event_id, return global activity feed
    if ($eventId <= 0) {
        handle_global_activity_feed($pdo, $uid, $limit);
        return;
    }

    // Ensure the current user is allowed to see this event via membership
    // in the underlying market.
    $stmtEvent = $pdo->prepare(
        'SELECT e.id, e.market_id
         FROM events e
         INNER JOIN market_members mm
           ON mm.market_id = e.market_id
          AND mm.user_id = :uid
        WHERE e.id = :eid
        LIMIT 1'
    );
    $stmtEvent->execute([
        ':uid' => $uid,
        ':eid' => $eventId,
    ]);
    $eventRow = $stmtEvent->fetch();
    if (!$eventRow) {
        json_response(['error' => 'Event not found or not accessible'], 404);
    }

    // Fetch a capped, ordered list of recent bets for this event.
    $stmt = $pdo->prepare(
        'SELECT b.id,
                b.side,
                b.outcome_id,
                b.shares,
                b.price,
                b.notional,
                b.created_at,
                u.name AS user_name,
                u.username AS user_username
         FROM bets b
         INNER JOIN users u ON u.id = b.user_id
         WHERE b.event_id = :eid
         ORDER BY b.created_at ASC, b.id ASC
         LIMIT 120'
    );
    $stmt->execute([':eid' => $eventId]);
    $rows = $stmt->fetchAll() ?: [];

    $bets = [];
    foreach ($rows as $row) {
        $name = (string)($row['user_name'] ?? '');
        $username = (string)($row['user_username'] ?? '');
        $display = $name !== '' ? $name : $username;
        $initial = $display !== '' ? mb_strtoupper(mb_substr(trim($display), 0, 1)) : 'U';

        $createdAt = (string)$row['created_at'];
        // Convert to an ISO-like string; leave as-is if parsing fails.
        $ts = null;
        try {
            $dt = new DateTime($createdAt);
            $ts = $dt->format(DateTime::ATOM);
        } catch (Throwable $e) {
            $ts = $createdAt;
        }

        $bets[] = [
            'id'            => (int)$row['id'],
            'timestamp'     => $ts,
            'side'          => $row['side'],
            'outcome_id'    => $row['outcome_id'],
            'shares'        => (int)$row['shares'],
            'price'         => (int)$row['price'],
            'notional'      => (float)$row['notional'],
            'user_name'     => $name !== '' ? $name : null,
            'user_username' => $username !== '' ? $username : null,
            'user_initial'  => $initial,
        ];
    }

    json_response(['bets' => $bets]);
}

/**
 * Global activity feed across all markets the user belongs to.
 * Shows: bets, new events, resolved events, new members
 */
function handle_global_activity_feed(PDO $pdo, int $uid, int $limit): void {
    $activities = [];
    
    // Note: Using string interpolation for LIMIT as PDO bindValue doesn't work reliably with LIMIT
    $limitSafe = (int)$limit; // Already validated, but extra safe
    
    try {
        // 1. Recent bets from user's markets (excluding own bets)
        $stmtBets = $pdo->prepare(
            "SELECT b.id, b.side, b.outcome_id, b.shares, b.price, b.created_at,
                    u.name AS user_name, u.username AS user_username,
                    e.title AS event_title, e.id AS event_id,
                    m.name AS market_name, m.avatar_emoji
             FROM bets b
             INNER JOIN users u ON u.id = b.user_id
             INNER JOIN events e ON e.id = b.event_id
             INNER JOIN markets m ON m.id = e.market_id
             INNER JOIN market_members mm ON mm.market_id = m.id AND mm.user_id = :uid
             WHERE b.user_id != :uid2
             ORDER BY b.created_at DESC
             LIMIT {$limitSafe}"
        );
        $stmtBets->execute([':uid' => $uid, ':uid2' => $uid]);
        $bets = $stmtBets->fetchAll() ?: [];
        
        foreach ($bets as $row) {
            $userName = $row['user_name'] ?: $row['user_username'] ?: 'Someone';
            $side = $row['side'] ?: $row['outcome_id'] ?: 'an outcome';
            $activities[] = [
                'type' => 'bet',
                'user_name' => $userName,
                'description' => "bet on {$side} for \"{$row['event_title']}\"",
                'event_id' => (int)$row['event_id'],
                'market_name' => $row['market_name'],
                'market_emoji' => $row['avatar_emoji'] ?: '🎯',
                'created_at' => $row['created_at'],
            ];
        }
    } catch (Throwable $e) {
        error_log('Activity feed - bets error: ' . $e->getMessage());
    }
    
    try {
        // 2. Recently created events in user's markets
        $stmtEvents = $pdo->prepare(
            "SELECT e.id, e.title, e.created_at,
                    u.name AS creator_name, u.username AS creator_username,
                    m.name AS market_name, m.avatar_emoji
             FROM events e
             INNER JOIN users u ON u.id = e.creator_id
             INNER JOIN markets m ON m.id = e.market_id
             INNER JOIN market_members mm ON mm.market_id = m.id AND mm.user_id = :uid
             WHERE e.creator_id != :uid2
             ORDER BY e.created_at DESC
             LIMIT {$limitSafe}"
        );
        $stmtEvents->execute([':uid' => $uid, ':uid2' => $uid]);
        $events = $stmtEvents->fetchAll() ?: [];
        
        foreach ($events as $row) {
            $userName = $row['creator_name'] ?: $row['creator_username'] ?: 'Someone';
            $activities[] = [
                'type' => 'event_created',
                'user_name' => $userName,
                'description' => "created a new event: \"{$row['title']}\"",
                'event_id' => (int)$row['id'],
                'market_name' => $row['market_name'],
                'market_emoji' => $row['avatar_emoji'] ?: '🎯',
                'created_at' => $row['created_at'],
            ];
        }
    } catch (Throwable $e) {
        error_log('Activity feed - events error: ' . $e->getMessage());
    }
    
    try {
        // 3. Recently resolved events
        $stmtResolved = $pdo->prepare(
            "SELECT e.id, e.title, e.resolved_at, e.outcome,
                    r.name AS resolver_name, r.username AS resolver_username,
                    m.name AS market_name, m.avatar_emoji
             FROM events e
             INNER JOIN markets m ON m.id = e.market_id
             INNER JOIN market_members mm ON mm.market_id = m.id AND mm.user_id = :uid
             LEFT JOIN users r ON r.id = e.resolver_id
             WHERE e.status = 'resolved' AND e.resolved_at IS NOT NULL
             ORDER BY e.resolved_at DESC
             LIMIT {$limitSafe}"
        );
        $stmtResolved->execute([':uid' => $uid]);
        $resolved = $stmtResolved->fetchAll() ?: [];
        
        foreach ($resolved as $row) {
            $resolverName = $row['resolver_name'] ?: $row['resolver_username'] ?: 'The resolver';
            $outcome = $row['outcome'] ?: 'an outcome';
            $activities[] = [
                'type' => 'event_resolved',
                'user_name' => $resolverName,
                'description' => "resolved \"{$row['title']}\" as {$outcome}",
                'event_id' => (int)$row['id'],
                'market_name' => $row['market_name'],
                'market_emoji' => $row['avatar_emoji'] ?: '🎯',
                'created_at' => $row['resolved_at'],
            ];
        }
    } catch (Throwable $e) {
        error_log('Activity feed - resolved error: ' . $e->getMessage());
    }
    
    try {
        // 4. New members joining user's markets (excluding self)
        // Use mm.id as a proxy for join order since joined_at might not exist
        $stmtMembers = $pdo->prepare(
            "SELECT mm.id AS mm_id,
                    u.name AS user_name, u.username AS user_username, u.created_at AS user_created,
                    m.id AS market_id, m.name AS market_name, m.avatar_emoji
             FROM market_members mm
             INNER JOIN users u ON u.id = mm.user_id
             INNER JOIN markets m ON m.id = mm.market_id
             WHERE mm.market_id IN (SELECT market_id FROM market_members WHERE user_id = :uid)
               AND mm.user_id != :uid2
             ORDER BY mm.id DESC
             LIMIT {$limitSafe}"
        );
        $stmtMembers->execute([':uid' => $uid, ':uid2' => $uid]);
        $members = $stmtMembers->fetchAll() ?: [];
        
        foreach ($members as $row) {
            $userName = $row['user_name'] ?: $row['user_username'] ?: 'Someone';
            $activities[] = [
                'type' => 'member_joined',
                'user_name' => $userName,
                'description' => "joined \"{$row['market_name']}\"",
                'market_id' => (int)$row['market_id'],
                'market_name' => $row['market_name'],
                'market_emoji' => $row['avatar_emoji'] ?: '🎯',
                'created_at' => $row['user_created'] ?? date('Y-m-d H:i:s'),
            ];
        }
    } catch (Throwable $e) {
        error_log('Activity feed - members error: ' . $e->getMessage());
    }
    
    try {
        // 5. Recent gossip/comments from user's markets (excluding own comments)
        $stmtGossip = $pdo->prepare(
            "SELECT g.id, g.message, g.created_at,
                    u.name AS user_name, u.username AS user_username,
                    e.id AS event_id, e.title AS event_title,
                    m.name AS market_name, m.avatar_emoji
             FROM gossip g
             INNER JOIN users u ON u.id = g.user_id
             INNER JOIN events e ON e.id = g.event_id
             INNER JOIN markets m ON m.id = e.market_id
             INNER JOIN market_members mm ON mm.market_id = m.id AND mm.user_id = :uid
             WHERE g.user_id != :uid2
             ORDER BY g.created_at DESC
             LIMIT {$limitSafe}"
        );
        $stmtGossip->execute([':uid' => $uid, ':uid2' => $uid]);
        $gossips = $stmtGossip->fetchAll() ?: [];
        
        foreach ($gossips as $row) {
            $userName = $row['user_name'] ?: $row['user_username'] ?: 'Someone';
            // Truncate long messages for the feed
            $message = mb_strlen($row['message']) > 80 
                ? mb_substr($row['message'], 0, 80) . '...' 
                : $row['message'];
            $activities[] = [
                'type' => 'gossip',
                'user_name' => $userName,
                'description' => "commented on \"{$row['event_title']}\": \"{$message}\"",
                'event_id' => (int)$row['event_id'],
                'market_name' => $row['market_name'],
                'market_emoji' => $row['avatar_emoji'] ?: '💬',
                'created_at' => $row['created_at'],
            ];
        }
    } catch (Throwable $e) {
        error_log('Activity feed - gossip error: ' . $e->getMessage());
    }
    
    // Sort all activities by date (most recent first)
    usort($activities, function($a, $b) {
        return strtotime($b['created_at'] ?? '') - strtotime($a['created_at'] ?? '');
    });
    
    // Limit to requested count
    $activities = array_slice($activities, 0, $limit);
    
    json_response(['activities' => $activities]);
}



<?php
// api/poll.php
// Polling fallback endpoint for real-time updates

declare(strict_types=1);

require_once __DIR__ . '/helpers.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['error' => 'Method not allowed'], 405);
}

$userId = require_auth();
$pdo = get_pdo();

// Get requested event IDs
$eventIdsParam = $_GET['event_ids'] ?? '';
$eventIds = array_filter(array_map('intval', explode(',', $eventIdsParam)));

// Get since timestamp
$since = $_GET['since'] ?? null;
$sinceTime = $since ? date('Y-m-d H:i:s', (int)$since) : date('Y-m-d H:i:s', strtotime('-30 seconds'));

// Verify user has access to these events
if (!empty($eventIds)) {
    $placeholders = implode(',', array_fill(0, count($eventIds), '?'));
    
    $stmt = $pdo->prepare("
        SELECT DISTINCT e.id
        FROM events e
        INNER JOIN market_members mm ON mm.market_id = e.market_id
        WHERE mm.user_id = ? AND e.id IN ({$placeholders})
    ");
    
    $stmt->execute(array_merge([$userId], $eventIds));
    $allowedIds = array_column($stmt->fetchAll(), 'id');
    $eventIds = array_intersect($eventIds, $allowedIds);
}

$updates = [];

if (!empty($eventIds)) {
    $placeholders = implode(',', array_fill(0, count($eventIds), '?'));
    
    // Get new bets
    $stmt = $pdo->prepare("
        SELECT b.*, u.name AS user_name, u.username AS user_username,
               e.yes_percent, e.no_percent
        FROM bets b
        INNER JOIN users u ON u.id = b.user_id
        INNER JOIN events e ON e.id = b.event_id
        WHERE b.event_id IN ({$placeholders})
          AND b.created_at > ?
        ORDER BY b.created_at DESC
        LIMIT 20
    ");
    $stmt->execute(array_merge($eventIds, [$sinceTime]));
    $bets = $stmt->fetchAll();
    
    foreach ($bets as $bet) {
        $updates[] = [
            'id' => (string)strtotime($bet['created_at']) . '-bet-' . $bet['id'],
            'type' => 'bet',
            'event_id' => (int)$bet['event_id'],
            'user_name' => $bet['user_name'],
            'user_initial' => strtoupper(substr($bet['user_name'] ?: $bet['user_username'] ?: '?', 0, 1)),
            'side' => $bet['side'],
            'shares' => (int)$bet['shares'],
            'price' => (int)$bet['price'],
            'yes_percent' => (int)($bet['yes_percent'] ?? 50),
            'no_percent' => (int)($bet['no_percent'] ?? 50),
            'created_at' => $bet['created_at'],
        ];
    }
    
    // Get new gossip
    $stmt = $pdo->prepare("
        SELECT g.*, u.name AS user_name, u.username AS user_username
        FROM gossip g
        INNER JOIN users u ON u.id = g.user_id
        WHERE g.event_id IN ({$placeholders})
          AND g.created_at > ?
        ORDER BY g.created_at DESC
        LIMIT 20
    ");
    $stmt->execute(array_merge($eventIds, [$sinceTime]));
    $gossipMessages = $stmt->fetchAll();
    
    foreach ($gossipMessages as $msg) {
        $updates[] = [
            'id' => (string)strtotime($msg['created_at']) . '-gossip-' . $msg['id'],
            'type' => 'gossip',
            'event_id' => (int)$msg['event_id'],
            'user_name' => $msg['user_name'],
            'message' => $msg['message'],
            'created_at' => $msg['created_at'],
        ];
    }
}

// Sort by timestamp
usort($updates, function($a, $b) {
    return strtotime($a['created_at']) - strtotime($b['created_at']);
});

json_response([
    'updates' => $updates,
    'lastEventId' => (string)time(),
]);


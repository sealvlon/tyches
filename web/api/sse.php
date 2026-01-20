<?php
// api/sse.php
// Server-Sent Events endpoint for real-time updates

declare(strict_types=1);

require_once __DIR__ . '/helpers.php';

// Disable output buffering
if (ob_get_level()) {
    ob_end_clean();
}

// Set SSE headers
header('Content-Type: text/event-stream');
header('Cache-Control: no-cache');
header('Connection: keep-alive');
header('X-Accel-Buffering: no'); // Disable nginx buffering

// Require authentication
$userId = require_auth();
$pdo = get_pdo();

// Get last event ID from client
$lastEventId = $_GET['lastEventId'] ?? $_SERVER['HTTP_LAST_EVENT_ID'] ?? null;

// Helper to send SSE event
function sendEvent(string $event, array $data, ?string $id = null): void {
    if ($id) {
        echo "id: {$id}\n";
    }
    echo "event: {$event}\n";
    echo "data: " . json_encode($data) . "\n\n";
    
    if (ob_get_level()) {
        ob_flush();
    }
    flush();
}

// Send heartbeat to keep connection alive
function sendHeartbeat(): void {
    echo ": heartbeat\n\n";
    if (ob_get_level()) {
        ob_flush();
    }
    flush();
}

// Get user's subscribed event IDs (events in their markets)
function getUserEventIds(PDO $pdo, int $userId): array {
    $stmt = $pdo->prepare('
        SELECT DISTINCT e.id
        FROM events e
        INNER JOIN market_members mm ON mm.market_id = e.market_id
        WHERE mm.user_id = :uid
        ORDER BY e.created_at DESC
        LIMIT 50
    ');
    $stmt->execute([':uid' => $userId]);
    return array_column($stmt->fetchAll(), 'id');
}

// Check for new bets since last check
function getNewBets(PDO $pdo, array $eventIds, ?string $since): array {
    if (empty($eventIds)) {
        return [];
    }
    
    $placeholders = implode(',', array_fill(0, count($eventIds), '?'));
    
    $sql = "
        SELECT b.*, u.name AS user_name, u.username AS user_username,
               e.title AS event_title, e.yes_percent, e.no_percent
        FROM bets b
        INNER JOIN users u ON u.id = b.user_id
        INNER JOIN events e ON e.id = b.event_id
        WHERE b.event_id IN ({$placeholders})
    ";
    
    $params = $eventIds;
    
    if ($since) {
        $sql .= " AND b.created_at > ?";
        $params[] = $since;
    } else {
        // Only get bets from last 30 seconds on initial connection
        $sql .= " AND b.created_at > DATE_SUB(NOW(), INTERVAL 30 SECOND)";
    }
    
    $sql .= " ORDER BY b.created_at DESC LIMIT 10";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    
    return $stmt->fetchAll();
}

// Check for new gossip messages
function getNewGossip(PDO $pdo, array $eventIds, ?string $since): array {
    if (empty($eventIds)) {
        return [];
    }
    
    $placeholders = implode(',', array_fill(0, count($eventIds), '?'));
    
    $sql = "
        SELECT g.*, u.name AS user_name, u.username AS user_username
        FROM gossip g
        INNER JOIN users u ON u.id = g.user_id
        WHERE g.event_id IN ({$placeholders})
    ";
    
    $params = $eventIds;
    
    if ($since) {
        $sql .= " AND g.created_at > ?";
        $params[] = $since;
    } else {
        $sql .= " AND g.created_at > DATE_SUB(NOW(), INTERVAL 30 SECOND)";
    }
    
    $sql .= " ORDER BY g.created_at DESC LIMIT 10";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    
    return $stmt->fetchAll();
}

// Main SSE loop
$eventIds = getUserEventIds($pdo, $userId);
$lastCheck = $lastEventId ? date('Y-m-d H:i:s', (int)$lastEventId) : null;
$startTime = time();
$maxRuntime = 30; // Maximum runtime in seconds (shared hosting friendly)

// Send initial connection message
sendEvent('connected', ['status' => 'ok', 'events' => count($eventIds)]);

while (true) {
    // Check connection
    if (connection_aborted()) {
        break;
    }
    
    // Respect max runtime for shared hosting
    if (time() - $startTime > $maxRuntime) {
        sendEvent('reconnect', ['reason' => 'timeout']);
        break;
    }
    
    try {
        // Check for new bets
        $newBets = getNewBets($pdo, $eventIds, $lastCheck);
        foreach ($newBets as $bet) {
            sendEvent('bet', [
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
            ], (string)strtotime($bet['created_at']));
        }
        
        // Check for new gossip
        $newGossip = getNewGossip($pdo, $eventIds, $lastCheck);
        foreach ($newGossip as $msg) {
            sendEvent('gossip', [
                'type' => 'gossip',
                'event_id' => (int)$msg['event_id'],
                'user_name' => $msg['user_name'],
                'message' => $msg['message'],
                'created_at' => $msg['created_at'],
            ], (string)strtotime($msg['created_at']));
        }
        
        $lastCheck = date('Y-m-d H:i:s');
        
    } catch (Throwable $e) {
        error_log('SSE error: ' . $e->getMessage());
    }
    
    // Send heartbeat
    sendHeartbeat();
    
    // Sleep before next check
    sleep(2);
}


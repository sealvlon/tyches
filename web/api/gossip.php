<?php
// api/gossip.php
// Event-level gossip (comments).

declare(strict_types=1);

require_once __DIR__ . '/security.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

try {
    if ($method === 'GET') {
        handle_get_gossip();
    } elseif ($method === 'POST') {
        handle_create_gossip();
    } else {
        json_response(['error' => 'Method not allowed'], 405);
    }
} catch (Throwable $e) {
    error_log('gossip.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    json_response(['error' => 'Server error'], 500);
}

/**
 * GET /api/gossip.php?event_id=...
 */
function handle_get_gossip(): void {
    $uid = require_auth(); // We require login to read comments (keeps it private).
    $pdo = get_pdo();

    $eventId = isset($_GET['event_id']) ? (int)$_GET['event_id'] : 0;
    if ($eventId <= 0) {
        json_response(['error' => 'event_id is required'], 400);
    }

    // Ensure user can see this event (member of its market)
    $stmtCheck = $pdo->prepare(
        'SELECT 1
         FROM events e
         INNER JOIN market_members mm ON mm.market_id = e.market_id AND mm.user_id = :uid
         WHERE e.id = :eid
         LIMIT 1'
    );
    $stmtCheck->execute([':uid' => $uid, ':eid' => $eventId]);
    if (!$stmtCheck->fetch()) {
        json_response(['error' => 'Not allowed to view this gossip'], 403);
    }

    $stmt = $pdo->prepare(
        'SELECT g.id, g.message, g.created_at,
                u.id   AS user_id,
                u.name AS user_name,
                u.username AS user_username
         FROM gossip g
         INNER JOIN users u ON u.id = g.user_id
         WHERE g.event_id = :eid
         ORDER BY g.created_at ASC
         LIMIT 200'
    );
    $stmt->execute([':eid' => $eventId]);
    $rows = $stmt->fetchAll() ?: [];

    json_response(['messages' => $rows]);
}

/**
 * POST /api/gossip.php
 * { event_id, message }
 */
function handle_create_gossip(): void {
    $uid = require_auth();
    $pdo = get_pdo();

    // CSRF protection for gossip POST
    tyches_require_csrf();

    // Prevent spam: limit gossip posts per user
    tyches_require_rate_limit('gossip_post:user:' . $uid, 60, 300); // 60 messages / 5 minutes

    $raw  = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        $data = $_POST;
    }

    $eventId = isset($data['event_id']) ? (int)$data['event_id'] : 0;
    $message = sanitize_string($data['message'] ?? '', 2000);

    if ($eventId <= 0 || $message === '') {
        json_response(['error' => 'event_id and message are required'], 400);
    }

    if (mb_strlen($message) > 1000) {
        json_response(['error' => 'Message is too long'], 400);
    }

    // Ensure membership in this event's market
    $stmtCheck = $pdo->prepare(
        'SELECT 1
         FROM events e
         INNER JOIN market_members mm ON mm.market_id = e.market_id AND mm.user_id = :uid
         WHERE e.id = :eid
         LIMIT 1'
    );
    $stmtCheck->execute([':uid' => $uid, ':eid' => $eventId]);
    if (!$stmtCheck->fetch()) {
        json_response(['error' => 'Not allowed to post gossip here'], 403);
    }

    $stmt = $pdo->prepare(
        'INSERT INTO gossip (event_id, user_id, message)
         VALUES (:eid, :uid, :message)'
    );
    $stmt->execute([
        ':eid'     => $eventId,
        ':uid'     => $uid,
        ':message' => $message,
    ]);

    $id = (int)$pdo->lastInsertId();

    json_response([
        'id'        => $id,
        'event_id'  => $eventId,
        'user_id'   => $uid,
        'message'   => $message,
        'created_at'=> date('Y-m-d H:i:s'),
    ], 201);
}





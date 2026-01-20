<?php
/**
 * api/admin-gossip.php
 * Admin-only gossip/chat moderation
 */

declare(strict_types=1);

require_once __DIR__ . '/security.php';
require_once __DIR__ . '/admin-audit.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

try {
    $pdo = get_pdo();
    $admin = require_admin($pdo);

    if ($method === 'GET') {
        handle_admin_gossip_list($pdo);
    } elseif ($method === 'POST') {
        handle_admin_gossip_mutation($pdo, $admin);
    } else {
        json_response(['error' => 'Method not allowed'], 405);
    }
} catch (Throwable $e) {
    error_log('admin-gossip.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    json_response(['error' => 'Server error'], 500);
}

/**
 * GET /api/admin-gossip.php
 * List gossip messages with search and pagination
 */
function handle_admin_gossip_list(PDO $pdo): void {
    $page = max(1, (int)($_GET['page'] ?? 1));
    $pageSize = 50;
    $offset = ($page - 1) * $pageSize;

    $q = sanitize_string($_GET['q'] ?? '', 255);
    $eventId = isset($_GET['event_id']) ? (int)$_GET['event_id'] : 0;
    $userId = isset($_GET['user_id']) ? (int)$_GET['user_id'] : 0;

    // Build query
    $where = [];
    $params = [];

    if ($q !== '') {
        $where[] = 'g.message LIKE :q';
        $params[':q'] = '%' . $q . '%';
    }

    if ($eventId > 0) {
        $where[] = 'g.event_id = :event_id';
        $params[':event_id'] = $eventId;
    }

    if ($userId > 0) {
        $where[] = 'g.user_id = :user_id';
        $params[':user_id'] = $userId;
    }

    $whereClause = $where ? 'WHERE ' . implode(' AND ', $where) : '';

    // Count
    $sqlCount = 'SELECT COUNT(*) FROM gossip g ' . $whereClause;
    $stmtCount = $pdo->prepare($sqlCount);
    foreach ($params as $key => $val) {
        $stmtCount->bindValue($key, $val);
    }
    $stmtCount->execute();
    $total = (int)$stmtCount->fetchColumn();

    // Fetch messages
    $sql = '
        SELECT g.*,
               u.username,
               u.name AS user_name,
               e.title AS event_title,
               m.name AS market_name
        FROM gossip g
        INNER JOIN users u ON u.id = g.user_id
        INNER JOIN events e ON e.id = g.event_id
        INNER JOIN markets m ON m.id = e.market_id
        ' . $whereClause . '
        ORDER BY g.created_at DESC
        LIMIT :limit OFFSET :offset
    ';

    $stmt = $pdo->prepare($sql);
    foreach ($params as $key => $val) {
        $stmt->bindValue($key, $val);
    }
    $stmt->bindValue(':limit', $pageSize, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();

    $messages = [];
    foreach ($stmt->fetchAll() ?: [] as $row) {
        $messages[] = [
            'id' => (int)$row['id'],
            'event_id' => (int)$row['event_id'],
            'event_title' => $row['event_title'],
            'market_name' => $row['market_name'],
            'user_id' => (int)$row['user_id'],
            'username' => $row['username'],
            'user_name' => $row['user_name'],
            'message' => $row['message'],
            'created_at' => $row['created_at'],
        ];
    }

    json_response([
        'messages' => $messages,
        'pagination' => [
            'page' => $page,
            'page_size' => $pageSize,
            'total' => $total,
        ],
    ]);
}

/**
 * POST /api/admin-gossip.php
 * Actions: delete, delete_all_by_user
 */
function handle_admin_gossip_mutation(PDO $pdo, array $admin): void {
    tyches_require_csrf();

    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        $data = $_POST;
    }

    $action = sanitize_string($data['action'] ?? '', 32);

    switch ($action) {
        case 'delete':
            $gossipId = isset($data['gossip_id']) ? (int)$data['gossip_id'] : 0;
            if ($gossipId <= 0) {
                json_response(['error' => 'gossip_id is required'], 400);
            }

            $stmt = $pdo->prepare('DELETE FROM gossip WHERE id = :id');
            $stmt->execute([':id' => $gossipId]);
            
            logAdminAction($pdo, 'gossip_delete', 'gossip', (string)$gossipId, 'Deleted single message');
            json_response(['success' => true, 'message' => 'Message deleted']);
            break;

        case 'delete_all_by_user':
            $userId = isset($data['user_id']) ? (int)$data['user_id'] : 0;
            if ($userId <= 0) {
                json_response(['error' => 'user_id is required'], 400);
            }

            $stmt = $pdo->prepare('DELETE FROM gossip WHERE user_id = :user_id');
            $stmt->execute([':user_id' => $userId]);
            $deleted = $stmt->rowCount();
            
            logAdminAction($pdo, 'gossip_delete_bulk', 'user', (string)$userId, "Deleted {$deleted} messages from user");
            json_response(['success' => true, 'deleted_count' => $deleted]);
            break;

        case 'delete_by_event':
            $eventId = isset($data['event_id']) ? (int)$data['event_id'] : 0;
            if ($eventId <= 0) {
                json_response(['error' => 'event_id is required'], 400);
            }

            $stmt = $pdo->prepare('DELETE FROM gossip WHERE event_id = :event_id');
            $stmt->execute([':event_id' => $eventId]);
            $deleted = $stmt->rowCount();
            
            logAdminAction($pdo, 'gossip_delete_bulk', 'event', (string)$eventId, "Deleted {$deleted} messages from event");
            json_response(['success' => true, 'deleted_count' => $deleted]);
            break;

        default:
            json_response(['error' => 'Unsupported action'], 400);
    }
}


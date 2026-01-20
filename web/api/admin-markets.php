<?php
/**
 * api/admin-markets.php
 * Admin-only market management: list, view, edit markets
 */

declare(strict_types=1);

require_once __DIR__ . '/security.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

try {
    $pdo = get_pdo();
    $admin = require_admin($pdo);

    if ($method === 'GET') {
        handle_admin_markets_list($pdo);
    } elseif ($method === 'POST') {
        handle_admin_markets_mutation($pdo, $admin);
    } else {
        json_response(['error' => 'Method not allowed'], 405);
    }
} catch (Throwable $e) {
    error_log('admin-markets.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    json_response(['error' => 'Server error'], 500);
}

/**
 * GET /api/admin-markets.php
 * List markets with search, pagination, and stats
 */
function handle_admin_markets_list(PDO $pdo): void {
    $page = max(1, (int)($_GET['page'] ?? 1));
    $pageSize = 25;
    $offset = ($page - 1) * $pageSize;

    $q = sanitize_string($_GET['q'] ?? '', 255);
    $visibility = sanitize_string($_GET['visibility'] ?? '', 32);
    $marketId = isset($_GET['market_id']) ? (int)$_GET['market_id'] : 0;

    // Single market detail
    if ($marketId > 0) {
        $stmt = $pdo->prepare('
            SELECT m.*,
                   u.username AS owner_username,
                   u.name AS owner_name,
                   (SELECT COUNT(*) FROM market_members mm WHERE mm.market_id = m.id) AS members_count,
                   (SELECT COUNT(*) FROM events e WHERE e.market_id = m.id) AS events_count,
                   (SELECT COALESCE(SUM(e.volume), 0) FROM events e WHERE e.market_id = m.id) AS total_volume
            FROM markets m
            INNER JOIN users u ON u.id = m.owner_id
            WHERE m.id = :id
        ');
        $stmt->execute([':id' => $marketId]);
        $market = $stmt->fetch();

        if (!$market) {
            json_response(['error' => 'Market not found'], 404);
        }

        json_response(['market' => normalize_market($market)]);
    }

    // Build query
    $where = [];
    $params = [];

    if ($q !== '') {
        $where[] = '(m.name LIKE :q OR m.description LIKE :q)';
        $params[':q'] = '%' . $q . '%';
    }

    if ($visibility !== '' && in_array($visibility, ['private', 'invite_only', 'link_only'], true)) {
        $where[] = 'm.visibility = :visibility';
        $params[':visibility'] = $visibility;
    }

    $whereClause = $where ? 'WHERE ' . implode(' AND ', $where) : '';

    // Count
    $sqlCount = 'SELECT COUNT(*) FROM markets m ' . $whereClause;
    $stmtCount = $pdo->prepare($sqlCount);
    foreach ($params as $key => $val) {
        $stmtCount->bindValue($key, $val);
    }
    $stmtCount->execute();
    $total = (int)$stmtCount->fetchColumn();

    // Fetch markets
    $sql = '
        SELECT m.*,
               u.username AS owner_username,
               u.name AS owner_name,
               (SELECT COUNT(*) FROM market_members mm WHERE mm.market_id = m.id) AS members_count,
               (SELECT COUNT(*) FROM events e WHERE e.market_id = m.id) AS events_count,
               (SELECT COALESCE(SUM(e.volume), 0) FROM events e WHERE e.market_id = m.id) AS total_volume
        FROM markets m
        INNER JOIN users u ON u.id = m.owner_id
        ' . $whereClause . '
        ORDER BY m.created_at DESC
        LIMIT :limit OFFSET :offset
    ';

    $stmt = $pdo->prepare($sql);
    foreach ($params as $key => $val) {
        $stmt->bindValue($key, $val);
    }
    $stmt->bindValue(':limit', $pageSize, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();

    $markets = [];
    foreach ($stmt->fetchAll() ?: [] as $row) {
        $markets[] = normalize_market($row);
    }

    json_response([
        'markets' => $markets,
        'pagination' => [
            'page' => $page,
            'page_size' => $pageSize,
            'total' => $total,
        ],
    ]);
}

/**
 * POST /api/admin-markets.php
 * Actions: delete, update_visibility, transfer_ownership
 */
function handle_admin_markets_mutation(PDO $pdo, array $admin): void {
    tyches_require_csrf();

    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        $data = $_POST;
    }

    $action = sanitize_string($data['action'] ?? '', 32);
    $marketId = isset($data['market_id']) ? (int)$data['market_id'] : 0;

    if ($marketId <= 0) {
        json_response(['error' => 'market_id is required'], 400);
    }

    switch ($action) {
        case 'delete':
            $stmt = $pdo->prepare('DELETE FROM markets WHERE id = :id');
            $stmt->execute([':id' => $marketId]);
            json_response(['success' => true, 'message' => 'Market deleted']);
            break;

        case 'update_visibility':
            $visibility = sanitize_string($data['visibility'] ?? '', 32);
            $allowed = ['private', 'invite_only', 'link_only'];
            if (!in_array($visibility, $allowed, true)) {
                json_response(['error' => 'Invalid visibility'], 400);
            }

            $stmt = $pdo->prepare('UPDATE markets SET visibility = :visibility WHERE id = :id');
            $stmt->execute([':visibility' => $visibility, ':id' => $marketId]);
            json_response(['success' => true, 'visibility' => $visibility]);
            break;

        case 'transfer_ownership':
            $newOwnerId = isset($data['new_owner_id']) ? (int)$data['new_owner_id'] : 0;
            if ($newOwnerId <= 0) {
                json_response(['error' => 'new_owner_id is required'], 400);
            }

            // Verify new owner exists
            $stmt = $pdo->prepare('SELECT id FROM users WHERE id = :id');
            $stmt->execute([':id' => $newOwnerId]);
            if (!$stmt->fetch()) {
                json_response(['error' => 'New owner not found'], 404);
            }

            $stmt = $pdo->prepare('UPDATE markets SET owner_id = :owner_id WHERE id = :id');
            $stmt->execute([':owner_id' => $newOwnerId, ':id' => $marketId]);

            // Ensure new owner is a member
            $stmt = $pdo->prepare('
                INSERT IGNORE INTO market_members (market_id, user_id, role)
                VALUES (:market_id, :user_id, "owner")
            ');
            $stmt->execute([':market_id' => $marketId, ':user_id' => $newOwnerId]);

            json_response(['success' => true, 'new_owner_id' => $newOwnerId]);
            break;

        default:
            json_response(['error' => 'Unsupported action'], 400);
    }
}

function normalize_market(array $row): array {
    return [
        'id' => (int)$row['id'],
        'name' => $row['name'],
        'description' => $row['description'],
        'visibility' => $row['visibility'],
        'avatar_emoji' => $row['avatar_emoji'],
        'avatar_color' => $row['avatar_color'],
        'owner_id' => (int)$row['owner_id'],
        'owner_username' => $row['owner_username'] ?? null,
        'owner_name' => $row['owner_name'] ?? null,
        'members_count' => (int)($row['members_count'] ?? 0),
        'events_count' => (int)($row['events_count'] ?? 0),
        'total_volume' => (float)($row['total_volume'] ?? 0),
        'created_at' => $row['created_at'],
    ];
}


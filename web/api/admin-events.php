<?php
/**
 * api/admin-events.php
 * Admin-only event management: list, view, resolve, delete events
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
        handle_admin_events_list($pdo);
    } elseif ($method === 'POST') {
        handle_admin_events_mutation($pdo, $admin);
    } else {
        json_response(['error' => 'Method not allowed'], 405);
    }
} catch (Throwable $e) {
    error_log('admin-events.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    json_response(['error' => 'Server error'], 500);
}

/**
 * GET /api/admin-events.php
 * List events with search, filters, and pagination
 */
function handle_admin_events_list(PDO $pdo): void {
    $page = max(1, (int)($_GET['page'] ?? 1));
    $pageSize = 25;
    $offset = ($page - 1) * $pageSize;

    $q = sanitize_string($_GET['q'] ?? '', 255);
    $status = sanitize_string($_GET['status'] ?? '', 32);
    $type = sanitize_string($_GET['type'] ?? '', 32);
    $marketId = isset($_GET['market_id']) ? (int)$_GET['market_id'] : 0;
    $eventId = isset($_GET['event_id']) ? (int)$_GET['event_id'] : 0;

    // Single event detail
    if ($eventId > 0) {
        $stmt = $pdo->prepare('
            SELECT e.*,
                   m.name AS market_name,
                   m.avatar_emoji AS market_emoji,
                   u.username AS creator_username,
                   u.name AS creator_name
            FROM events e
            INNER JOIN markets m ON m.id = e.market_id
            INNER JOIN users u ON u.id = e.creator_id
            WHERE e.id = :id
        ');
        $stmt->execute([':id' => $eventId]);
        $event = $stmt->fetch();

        if (!$event) {
            json_response(['error' => 'Event not found'], 404);
        }

        // Get bets summary
        $stmtBets = $pdo->prepare('
            SELECT side, outcome_id, COUNT(*) as bet_count, SUM(shares) as total_shares, SUM(notional) as total_notional
            FROM bets
            WHERE event_id = :event_id
            GROUP BY side, outcome_id
        ');
        $stmtBets->execute([':event_id' => $eventId]);
        $betsSummary = $stmtBets->fetchAll() ?: [];

        json_response([
            'event' => normalize_event($event),
            'bets_summary' => $betsSummary,
        ]);
    }

    // Build query
    $where = [];
    $params = [];

    if ($q !== '') {
        $where[] = '(e.title LIKE :q OR e.description LIKE :q)';
        $params[':q'] = '%' . $q . '%';
    }

    if ($status !== '' && in_array($status, ['open', 'closed', 'resolved'], true)) {
        $where[] = 'e.status = :status';
        $params[':status'] = $status;
    }

    if ($type !== '' && in_array($type, ['binary', 'multiple'], true)) {
        $where[] = 'e.event_type = :type';
        $params[':type'] = $type;
    }

    if ($marketId > 0) {
        $where[] = 'e.market_id = :market_id';
        $params[':market_id'] = $marketId;
    }

    $whereClause = $where ? 'WHERE ' . implode(' AND ', $where) : '';

    // Count
    $sqlCount = 'SELECT COUNT(*) FROM events e ' . $whereClause;
    $stmtCount = $pdo->prepare($sqlCount);
    foreach ($params as $key => $val) {
        $stmtCount->bindValue($key, $val);
    }
    $stmtCount->execute();
    $total = (int)$stmtCount->fetchColumn();

    // Fetch events
    $sql = '
        SELECT e.*,
               m.name AS market_name,
               m.avatar_emoji AS market_emoji,
               u.username AS creator_username
        FROM events e
        INNER JOIN markets m ON m.id = e.market_id
        INNER JOIN users u ON u.id = e.creator_id
        ' . $whereClause . '
        ORDER BY e.created_at DESC
        LIMIT :limit OFFSET :offset
    ';

    $stmt = $pdo->prepare($sql);
    foreach ($params as $key => $val) {
        $stmt->bindValue($key, $val);
    }
    $stmt->bindValue(':limit', $pageSize, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();

    $events = [];
    foreach ($stmt->fetchAll() ?: [] as $row) {
        $events[] = normalize_event($row);
    }

    json_response([
        'events' => $events,
        'pagination' => [
            'page' => $page,
            'page_size' => $pageSize,
            'total' => $total,
        ],
    ]);
}

/**
 * POST /api/admin-events.php
 * Actions: resolve, close, reopen, delete
 */
function handle_admin_events_mutation(PDO $pdo, array $admin): void {
    tyches_require_csrf();

    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        $data = $_POST;
    }

    $action = sanitize_string($data['action'] ?? '', 32);
    $eventId = isset($data['event_id']) ? (int)$data['event_id'] : 0;

    if ($eventId <= 0) {
        json_response(['error' => 'event_id is required'], 400);
    }

    // Get event
    $stmt = $pdo->prepare('SELECT * FROM events WHERE id = :id');
    $stmt->execute([':id' => $eventId]);
    $event = $stmt->fetch();

    if (!$event) {
        json_response(['error' => 'Event not found'], 404);
    }

    switch ($action) {
        case 'close':
            if ($event['status'] !== 'open') {
                json_response(['error' => 'Event is not open'], 400);
            }

            $stmt = $pdo->prepare('UPDATE events SET status = "closed" WHERE id = :id');
            $stmt->execute([':id' => $eventId]);
            json_response(['success' => true, 'status' => 'closed']);
            break;

        case 'reopen':
            if ($event['status'] === 'resolved') {
                json_response(['error' => 'Cannot reopen resolved event'], 400);
            }

            $stmt = $pdo->prepare('UPDATE events SET status = "open" WHERE id = :id');
            $stmt->execute([':id' => $eventId]);
            json_response(['success' => true, 'status' => 'open']);
            break;

        case 'resolve':
            $winningSide = sanitize_string($data['winning_side'] ?? '', 3);
            $winningOutcome = sanitize_string($data['winning_outcome_id'] ?? '', 64);

            if ($event['event_type'] === 'binary') {
                if (!in_array($winningSide, ['YES', 'NO'], true)) {
                    json_response(['error' => 'winning_side must be YES or NO'], 400);
                }

                $stmt = $pdo->prepare('
                    UPDATE events 
                    SET status = "resolved", winning_side = :side 
                    WHERE id = :id
                ');
                $stmt->execute([':side' => $winningSide, ':id' => $eventId]);
            } else {
                if ($winningOutcome === '') {
                    json_response(['error' => 'winning_outcome_id is required'], 400);
                }

                $stmt = $pdo->prepare('
                    UPDATE events 
                    SET status = "resolved", winning_outcome_id = :outcome 
                    WHERE id = :id
                ');
                $stmt->execute([':outcome' => $winningOutcome, ':id' => $eventId]);
            }

            // Settle tokens
            settle_event($pdo, $eventId);

            json_response([
                'success' => true,
                'status' => 'resolved',
                'winning_side' => $winningSide ?: null,
                'winning_outcome_id' => $winningOutcome ?: null,
            ]);
            break;

        case 'delete':
            // Don't allow deleting resolved events with bets
            if ($event['status'] === 'resolved') {
                $stmtBets = $pdo->prepare('SELECT COUNT(*) FROM bets WHERE event_id = :id');
                $stmtBets->execute([':id' => $eventId]);
                if ((int)$stmtBets->fetchColumn() > 0) {
                    json_response(['error' => 'Cannot delete resolved event with bets'], 400);
                }
            }

            $stmt = $pdo->prepare('DELETE FROM events WHERE id = :id');
            $stmt->execute([':id' => $eventId]);
            json_response(['success' => true, 'message' => 'Event deleted']);
            break;

        case 'extend':
            $newClosesAt = sanitize_string($data['closes_at'] ?? '', 32);
            if ($newClosesAt === '') {
                json_response(['error' => 'closes_at is required'], 400);
            }

            $stmt = $pdo->prepare('UPDATE events SET closes_at = :closes_at WHERE id = :id');
            $stmt->execute([':closes_at' => $newClosesAt, ':id' => $eventId]);
            json_response(['success' => true, 'closes_at' => $newClosesAt]);
            break;

        default:
            json_response(['error' => 'Unsupported action'], 400);
    }
}

/**
 * Settle event - pay out winners using parimutuel system
 * 
 * In parimutuel betting:
 * - Total pool = sum of all bets
 * - Winning pool = sum of bets on winning side
 * - Each winner gets: (their_bet / winning_pool) * total_pool
 */
function settle_event(PDO $pdo, int $eventId): void {
    $stmt = $pdo->prepare('SELECT * FROM events WHERE id = :id FOR UPDATE');
    $stmt->execute([':id' => $eventId]);
    $event = $stmt->fetch();

    if (!$event || $event['status'] !== 'resolved') {
        return;
    }

    if ($event['settled_at'] !== null) {
        return; // Already settled
    }

    $eventType = $event['event_type'];
    $winningSide = $event['winning_side'] ?? null;
    $winningOutcome = $event['winning_outcome_id'] ?? null;

    // Calculate total pool
    $stmtTotalPool = $pdo->prepare('SELECT COALESCE(SUM(notional), 0) FROM bets WHERE event_id = :eid');
    $stmtTotalPool->execute([':eid' => $eventId]);
    $totalPool = (float)$stmtTotalPool->fetchColumn();

    if ($totalPool <= 0) {
        // No bets to settle
        $stmtSettled = $pdo->prepare('UPDATE events SET settled_at = NOW() WHERE id = :id');
        $stmtSettled->execute([':id' => $eventId]);
        return;
    }

    // Get winning bets and calculate winning pool
    if ($eventType === 'binary') {
        if (!in_array($winningSide, ['YES', 'NO'], true)) {
            return;
        }

        // Get winning pool total
        $stmtWinningPool = $pdo->prepare('
            SELECT COALESCE(SUM(notional), 0) FROM bets 
            WHERE event_id = :eid AND side = :side
        ');
        $stmtWinningPool->execute([':eid' => $eventId, ':side' => $winningSide]);
        $winningPool = (float)$stmtWinningPool->fetchColumn();

        // Get individual winners
        $stmtWinners = $pdo->prepare('
            SELECT user_id, SUM(notional) AS total_bet
            FROM bets
            WHERE event_id = :eid AND side = :side
            GROUP BY user_id
        ');
        $stmtWinners->execute([':eid' => $eventId, ':side' => $winningSide]);
    } else {
        if ($winningOutcome === null || $winningOutcome === '') {
            return;
        }

        // Get winning pool total
        $stmtWinningPool = $pdo->prepare('
            SELECT COALESCE(SUM(notional), 0) FROM bets 
            WHERE event_id = :eid AND outcome_id = :outcome_id
        ');
        $stmtWinningPool->execute([':eid' => $eventId, ':outcome_id' => $winningOutcome]);
        $winningPool = (float)$stmtWinningPool->fetchColumn();

        // Get individual winners
        $stmtWinners = $pdo->prepare('
            SELECT user_id, SUM(notional) AS total_bet
            FROM bets
            WHERE event_id = :eid AND outcome_id = :outcome_id
            GROUP BY user_id
        ');
        $stmtWinners->execute([':eid' => $eventId, ':outcome_id' => $winningOutcome]);
    }

    $winners = $stmtWinners->fetchAll() ?: [];

    // Edge case: no winners
    if (empty($winners) || $winningPool <= 0) {
        // No one bet on the winning side - pool is lost
        $stmtSettled = $pdo->prepare('UPDATE events SET settled_at = NOW() WHERE id = :id');
        $stmtSettled->execute([':id' => $eventId]);
        return;
    }

    // Calculate multiplier: if winning pool = total pool, everyone just gets their bet back
    $multiplier = $totalPool / $winningPool;

    $stmtCredit = $pdo->prepare('
        UPDATE users
        SET tokens_balance = tokens_balance + :amount
        WHERE id = :uid
    ');

    foreach ($winners as $row) {
        $betAmount = (float)$row['total_bet'];
        if ($betAmount <= 0) continue;

        // Parimutuel payout: bet_amount * (total_pool / winning_pool)
        $payout = round($betAmount * $multiplier, 2);
        $stmtCredit->execute([':amount' => $payout, ':uid' => (int)$row['user_id']]);
    }

    // Mark as settled
    $stmtSettled = $pdo->prepare('UPDATE events SET settled_at = NOW() WHERE id = :id');
    $stmtSettled->execute([':id' => $eventId]);
}

function normalize_event(array $row): array {
    return [
        'id' => (int)$row['id'],
        'market_id' => (int)$row['market_id'],
        'market_name' => $row['market_name'] ?? null,
        'market_emoji' => $row['market_emoji'] ?? null,
        'creator_id' => (int)$row['creator_id'],
        'creator_username' => $row['creator_username'] ?? null,
        'creator_name' => $row['creator_name'] ?? null,
        'title' => $row['title'],
        'description' => $row['description'],
        'event_type' => $row['event_type'],
        'status' => $row['status'],
        'closes_at' => $row['closes_at'],
        'yes_price' => isset($row['yes_price']) ? (int)$row['yes_price'] : null,
        'no_price' => isset($row['no_price']) ? (int)$row['no_price'] : null,
        'yes_percent' => isset($row['yes_percent']) ? (int)$row['yes_percent'] : null,
        'no_percent' => isset($row['no_percent']) ? (int)$row['no_percent'] : null,
        'outcomes_json' => $row['outcomes_json'],
        'volume' => (float)$row['volume'],
        'traders_count' => (int)$row['traders_count'],
        'winning_side' => $row['winning_side'],
        'winning_outcome_id' => $row['winning_outcome_id'],
        'settled_at' => $row['settled_at'],
        'created_at' => $row['created_at'],
    ];
}


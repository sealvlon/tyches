<?php
/**
 * api/admin-disputes.php
 * Admin-only dispute management for event resolutions
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
        handle_admin_disputes_list($pdo);
    } elseif ($method === 'POST') {
        handle_admin_disputes_mutation($pdo, $admin);
    } else {
        json_response(['error' => 'Method not allowed'], 405);
    }
} catch (Throwable $e) {
    error_log('admin-disputes.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    json_response(['error' => 'Server error'], 500);
}

/**
 * GET /api/admin-disputes.php
 * List resolution disputes with filters
 */
function handle_admin_disputes_list(PDO $pdo): void {
    $page = max(1, (int)($_GET['page'] ?? 1));
    $pageSize = 25;
    $offset = ($page - 1) * $pageSize;

    $status = sanitize_string($_GET['status'] ?? '', 32);
    $eventId = isset($_GET['event_id']) ? (int)$_GET['event_id'] : 0;

    // Build query
    $where = [];
    $params = [];

    if ($status !== '' && in_array($status, ['pending', 'reviewed', 'resolved', 'rejected'], true)) {
        $where[] = 'd.status = :status';
        $params[':status'] = $status;
    }

    if ($eventId > 0) {
        $where[] = 'd.event_id = :event_id';
        $params[':event_id'] = $eventId;
    }

    $whereClause = $where ? 'WHERE ' . implode(' AND ', $where) : '';

    // Count
    $sqlCount = 'SELECT COUNT(*) FROM resolution_disputes d ' . $whereClause;
    $stmtCount = $pdo->prepare($sqlCount);
    foreach ($params as $key => $val) {
        $stmtCount->bindValue($key, $val);
    }
    $stmtCount->execute();
    $total = (int)$stmtCount->fetchColumn();

    // Fetch disputes
    $sql = '
        SELECT d.*,
               u.username,
               u.name AS user_name,
               e.title AS event_title,
               e.status AS event_status,
               e.winning_side,
               e.winning_outcome_id,
               m.name AS market_name
        FROM resolution_disputes d
        INNER JOIN users u ON u.id = d.user_id
        INNER JOIN events e ON e.id = d.event_id
        INNER JOIN markets m ON m.id = e.market_id
        ' . $whereClause . '
        ORDER BY 
            CASE d.status WHEN "pending" THEN 0 ELSE 1 END,
            d.created_at DESC
        LIMIT :limit OFFSET :offset
    ';

    $stmt = $pdo->prepare($sql);
    foreach ($params as $key => $val) {
        $stmt->bindValue($key, $val);
    }
    $stmt->bindValue(':limit', $pageSize, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();

    $disputes = [];
    foreach ($stmt->fetchAll() ?: [] as $row) {
        $disputes[] = [
            'id' => (int)$row['id'],
            'event_id' => (int)$row['event_id'],
            'event_title' => $row['event_title'],
            'event_status' => $row['event_status'],
            'winning_side' => $row['winning_side'],
            'winning_outcome_id' => $row['winning_outcome_id'],
            'market_name' => $row['market_name'],
            'user_id' => (int)$row['user_id'],
            'username' => $row['username'],
            'user_name' => $row['user_name'],
            'reason' => $row['reason'],
            'status' => $row['status'],
            'admin_notes' => $row['admin_notes'],
            'resolved_at' => $row['resolved_at'],
            'created_at' => $row['created_at'],
        ];
    }

    json_response([
        'disputes' => $disputes,
        'pagination' => [
            'page' => $page,
            'page_size' => $pageSize,
            'total' => $total,
        ],
    ]);
}

/**
 * POST /api/admin-disputes.php
 * Actions: review, resolve, reject
 */
function handle_admin_disputes_mutation(PDO $pdo, array $admin): void {
    tyches_require_csrf();

    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        $data = $_POST;
    }

    $action = sanitize_string($data['action'] ?? '', 32);
    $disputeId = isset($data['dispute_id']) ? (int)$data['dispute_id'] : 0;

    if ($disputeId <= 0) {
        json_response(['error' => 'dispute_id is required'], 400);
    }

    // Get dispute
    $stmt = $pdo->prepare('SELECT * FROM resolution_disputes WHERE id = :id');
    $stmt->execute([':id' => $disputeId]);
    $dispute = $stmt->fetch();

    if (!$dispute) {
        json_response(['error' => 'Dispute not found'], 404);
    }

    $adminNotes = sanitize_string($data['admin_notes'] ?? '', 2000);

    switch ($action) {
        case 'review':
            $stmt = $pdo->prepare('
                UPDATE resolution_disputes 
                SET status = "reviewed", admin_notes = :notes
                WHERE id = :id
            ');
            $stmt->execute([':notes' => $adminNotes, ':id' => $disputeId]);
            json_response(['success' => true, 'status' => 'reviewed']);
            break;

        case 'resolve':
            // Mark dispute as resolved and potentially update event
            $newOutcome = sanitize_string($data['new_outcome'] ?? '', 64);
            
            $pdo->beginTransaction();
            try {
                // Update dispute
                $stmt = $pdo->prepare('
                    UPDATE resolution_disputes 
                    SET status = "resolved", admin_notes = :notes, resolved_at = NOW()
                    WHERE id = :id
                ');
                $stmt->execute([':notes' => $adminNotes, ':id' => $disputeId]);

                // If new outcome provided, update event (reversal)
                if ($newOutcome !== '') {
                    $eventId = (int)$dispute['event_id'];
                    
                    // Check event type
                    $stmtEvent = $pdo->prepare('SELECT event_type FROM events WHERE id = :id');
                    $stmtEvent->execute([':id' => $eventId]);
                    $event = $stmtEvent->fetch();

                    if ($event) {
                        if ($event['event_type'] === 'binary' && in_array($newOutcome, ['YES', 'NO'], true)) {
                            $stmt = $pdo->prepare('
                                UPDATE events 
                                SET winning_side = :side, settled_at = NULL
                                WHERE id = :id
                            ');
                            $stmt->execute([':side' => $newOutcome, ':id' => $eventId]);
                        } elseif ($event['event_type'] !== 'binary') {
                            $stmt = $pdo->prepare('
                                UPDATE events 
                                SET winning_outcome_id = :outcome, settled_at = NULL
                                WHERE id = :id
                            ');
                            $stmt->execute([':outcome' => $newOutcome, ':id' => $eventId]);
                        }
                    }
                }

                $pdo->commit();
                json_response(['success' => true, 'status' => 'resolved']);
            } catch (Throwable $e) {
                $pdo->rollBack();
                throw $e;
            }
            break;

        case 'reject':
            $stmt = $pdo->prepare('
                UPDATE resolution_disputes 
                SET status = "rejected", admin_notes = :notes, resolved_at = NOW()
                WHERE id = :id
            ');
            $stmt->execute([':notes' => $adminNotes, ':id' => $disputeId]);
            json_response(['success' => true, 'status' => 'rejected']);
            break;

        default:
            json_response(['error' => 'Unsupported action'], 400);
    }
}


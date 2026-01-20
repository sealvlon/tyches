<?php
/**
 * Resolution API - Event resolution with parimutuel payouts
 * 
 * Parimutuel Payout System:
 * - All bets go into pools (YES pool, NO pool, or outcome pools)
 * - When resolved, winners split the ENTIRE pool proportionally
 * - Each winner gets: (their_bet / winning_pool) * total_pool
 * 
 * Example:
 *   YES pool: 1000, NO pool: 500, Total: 1500
 *   YES wins. Each YES token gets 1500/1000 = 1.5 tokens back
 *   User bet 100 on YES → gets 150 tokens (profit: 50)
 * 
 * GET: Get resolution status and votes
 * POST: Vote, resolve, dispute, or close event
 */

declare(strict_types=1);

require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/security.php';
require_once __DIR__ . '/mailer.php';
require_once __DIR__ . '/pools.php';
require_once __DIR__ . '/admin-audit.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

try {
    if ($method === 'GET') {
        handle_get_resolution();
    } elseif ($method === 'POST') {
        handle_resolution_action();
    } else {
        json_response(['error' => 'Method not allowed'], 405);
    }
} catch (Throwable $e) {
    error_log('[Tyches] resolution.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    error_log('[Tyches] Stack trace: ' . $e->getTraceAsString());
    json_response(['error' => 'Server error: ' . $e->getMessage()], 500);
}

function handle_get_resolution(): void {
    $userId = require_auth();
    $pdo = get_pdo();
    
    $eventId = isset($_GET['event_id']) ? (int)$_GET['event_id'] : 0;
    
    if (!$eventId) {
        json_response(['error' => 'Event ID required'], 400);
    }
    
    // Get event details
    $stmt = $pdo->prepare('
        SELECT e.*, m.name AS market_name, m.owner_id AS market_owner_id
        FROM events e
        INNER JOIN markets m ON m.id = e.market_id
        INNER JOIN market_members mm ON mm.market_id = e.market_id AND mm.user_id = :uid
        WHERE e.id = :event_id
    ');
    $stmt->execute([':event_id' => $eventId, ':uid' => $userId]);
    $event = $stmt->fetch();
    
    if (!$event) {
        json_response(['error' => 'Event not found or access denied'], 404);
    }
    
    // Get current pool data
    $poolData = calculate_event_odds($pdo, $eventId);
    
    // Get resolution votes
    $stmt = $pdo->prepare('
        SELECT rv.*, u.name AS user_name, u.username AS user_username
        FROM resolution_votes rv
        INNER JOIN users u ON u.id = rv.user_id
        WHERE rv.event_id = :event_id
        ORDER BY rv.created_at DESC
    ');
    $stmt->execute([':event_id' => $eventId]);
    $votes = $stmt->fetchAll();
    
    // Count votes by outcome
    $voteCounts = [];
    foreach ($votes as $vote) {
        $outcome = $vote['voted_outcome'];
        if (!isset($voteCounts[$outcome])) {
            $voteCounts[$outcome] = 0;
        }
        $voteCounts[$outcome]++;
    }
    
    // Get total participants
    $stmt = $pdo->prepare('
        SELECT COUNT(DISTINCT user_id) AS count
        FROM bets
        WHERE event_id = :event_id
    ');
    $stmt->execute([':event_id' => $eventId]);
    $participantCount = (int)$stmt->fetchColumn();
    
    // Check if user has voted
    $userVote = null;
    foreach ($votes as $vote) {
        if ((int)$vote['user_id'] === $userId) {
            $userVote = $vote['voted_outcome'];
            break;
        }
    }
    
    // Check permissions
    $isCreator = (int)$event['creator_id'] === $userId;
    $isMarketOwner = (int)$event['market_owner_id'] === $userId;
    $canFinalize = ($event['status'] === 'closed' && ($isCreator || $isMarketOwner));
    
    json_response([
        'event' => [
            'id' => (int)$event['id'],
            'title' => $event['title'],
            'status' => $event['status'],
            'event_type' => $event['event_type'],
            'closes_at' => $event['closes_at'],
            'winning_side' => $event['winning_side'],
            'winning_outcome_id' => $event['winning_outcome_id'],
            'settled_at' => $event['settled_at'],
        ],
        'pools' => $poolData,
        'votes' => array_map(function($v) {
            return [
                'user_id' => (int)$v['user_id'],
                'user_name' => $v['user_name'],
                'voted_outcome' => $v['voted_outcome'],
                'reason' => $v['reason'],
                'created_at' => $v['created_at'],
            ];
        }, $votes),
        'vote_counts' => $voteCounts,
        'participant_count' => $participantCount,
        'user_vote' => $userVote,
        'can_finalize' => $canFinalize,
        'is_creator' => $isCreator,
        'is_market_owner' => $isMarketOwner,
    ]);
}

function handle_resolution_action(): void {
    // CSRF check
    tyches_require_csrf();
    
    $userId = require_auth();
    if (!$userId) {
        json_response(['error' => 'Authentication required'], 401);
    }
    
    $pdo = get_pdo();
    
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    
    if (!is_array($data)) {
        json_response(['error' => 'Invalid request data'], 400);
    }
    
    $action = $data['action'] ?? '';
    $eventId = (int)($data['event_id'] ?? 0);
    
    if (!$eventId) {
        json_response(['error' => 'Event ID required'], 400);
    }
    
    if (!$action) {
        json_response(['error' => 'Action required'], 400);
    }
    
    // Get event and verify access
    $stmt = $pdo->prepare('
        SELECT e.*, m.owner_id AS market_owner_id
        FROM events e
        INNER JOIN markets m ON m.id = e.market_id
        INNER JOIN market_members mm ON mm.market_id = e.market_id AND mm.user_id = :uid
        WHERE e.id = :event_id
    ');
    $stmt->execute([':event_id' => $eventId, ':uid' => $userId]);
    $event = $stmt->fetch();
    
    if (!$event) {
        json_response(['error' => 'Event not found or access denied'], 404);
    }
    
    switch ($action) {
        case 'vote':
            handleVote($pdo, $userId, $event, $data);
            break;
        case 'dispute':
            handleDispute($pdo, $userId, $event, $data);
            break;
        case 'resolve':
            handleResolve($pdo, $userId, $event, $data);
            break;
        case 'close':
            handleClose($pdo, $userId, $event);
            break;
        case 'reopen':
            handleReopen($pdo, $userId, $event);
            break;
        default:
            json_response(['error' => 'Invalid action'], 400);
    }
}

function handleVote(PDO $pdo, int $userId, array $event, array $data): void {
    if ($event['status'] !== 'closed') {
        json_response(['error' => 'Event must be closed before voting on resolution'], 400);
    }
    
    if ($event['settled_at'] !== null) {
        json_response(['error' => 'Event is already resolved'], 400);
    }
    
    $votedOutcome = sanitize_string($data['outcome'] ?? '', 64);
    $reason = sanitize_string($data['reason'] ?? '', 500);
    
    if ($votedOutcome === '') {
        json_response(['error' => 'Outcome is required'], 400);
    }
    
    // Verify user has bet on this event
    $stmt = $pdo->prepare('SELECT id FROM bets WHERE event_id = :event_id AND user_id = :uid LIMIT 1');
    $stmt->execute([':event_id' => $event['id'], ':uid' => $userId]);
    if (!$stmt->fetch()) {
        json_response(['error' => 'Only participants can vote on resolution'], 403);
    }
    
    // Insert or update vote
    $stmt = $pdo->prepare('
        INSERT INTO resolution_votes (event_id, user_id, voted_outcome, reason)
        VALUES (:event_id, :user_id, :outcome, :reason)
        ON DUPLICATE KEY UPDATE 
            voted_outcome = VALUES(voted_outcome),
            reason = VALUES(reason),
            created_at = NOW()
    ');
    $stmt->execute([
        ':event_id' => $event['id'],
        ':user_id' => $userId,
        ':outcome' => $votedOutcome,
        ':reason' => $reason ?: null,
    ]);
    
    json_response(['ok' => true, 'message' => 'Vote recorded']);
}

function handleDispute(PDO $pdo, int $userId, array $event, array $data): void {
    if ($event['status'] !== 'resolved') {
        json_response(['error' => 'Can only dispute resolved events'], 400);
    }
    
    $reason = sanitize_string($data['reason'] ?? '', 1000);
    
    if (strlen($reason) < 10) {
        json_response(['error' => 'Please provide a detailed reason for the dispute'], 400);
    }
    
    // Create dispute record
    $stmt = $pdo->prepare('
        INSERT INTO resolution_disputes (event_id, user_id, reason)
        VALUES (:event_id, :user_id, :reason)
    ');
    $stmt->execute([
        ':event_id' => $event['id'],
        ':user_id' => $userId,
        ':reason' => $reason,
    ]);
    
    // Reopen event for voting
    $stmt = $pdo->prepare('
        UPDATE events 
        SET status = \'closed\', winning_side = NULL, winning_outcome_id = NULL, settled_at = NULL
        WHERE id = :event_id
    ');
    $stmt->execute([':event_id' => $event['id']]);
    
    json_response(['ok' => true, 'message' => 'Dispute filed. Event reopened for voting.']);
}

/**
 * Check if user is a host for this event
 */
function isEventHost(PDO $pdo, int $eventId, int $userId): bool {
    try {
        // First check if table exists
        $stmt = $pdo->query("SHOW TABLES LIKE 'event_hosts'");
        if (!$stmt->fetch()) {
            return false; // Table doesn't exist
        }
        
        $stmt = $pdo->prepare('SELECT 1 FROM event_hosts WHERE event_id = :event_id AND user_id = :user_id LIMIT 1');
        $stmt->execute([':event_id' => $eventId, ':user_id' => $userId]);
        return (bool)$stmt->fetch();
    } catch (Throwable $e) {
        // Any error - just return false
        return false;
    }
}

/**
 * Check if user can manage the event (close/reopen)
 * Only: Creator, Hosts, Market Owner
 * NOT: Regular attendees, NOT: Resolver (resolver only resolves)
 */
function canManageEvent(PDO $pdo, int $eventId, int $userId, array $event): bool {
    $isCreator = (int)$event['creator_id'] === $userId;
    $isMarketOwner = (int)$event['market_owner_id'] === $userId;
    $isHost = isEventHost($pdo, $eventId, $userId);
    
    return $isCreator || $isMarketOwner || $isHost;
}

/**
 * Check if user can resolve the event
 * Only: Creator, Resolver, Hosts, Market Owner
 */
function canResolveEvent(PDO $pdo, int $eventId, int $userId, array $event): bool {
    $isCreator = (int)$event['creator_id'] === $userId;
    $isResolver = (int)($event['resolver_id'] ?? 0) === $userId;
    $isMarketOwner = (int)$event['market_owner_id'] === $userId;
    $isHost = isEventHost($pdo, $eventId, $userId);
    
    return $isCreator || $isResolver || $isMarketOwner || $isHost;
}

function handleClose(PDO $pdo, int $userId, array $event): void {
    if (!canManageEvent($pdo, (int)$event['id'], $userId, $event)) {
        json_response(['error' => 'Only the creator, hosts, or market owner can close this event'], 403);
    }
    
    if ($event['status'] !== 'open') {
        json_response(['error' => 'Event is not open'], 400);
    }
    
    $stmt = $pdo->prepare('UPDATE events SET status = \'closed\' WHERE id = :event_id');
    $stmt->execute([':event_id' => $event['id']]);
    
    json_response(['ok' => true, 'message' => 'Event closed for trading. Ready for resolution.']);
}

function handleReopen(PDO $pdo, int $userId, array $event): void {
    if (!canManageEvent($pdo, (int)$event['id'], $userId, $event)) {
        json_response(['error' => 'Only the creator, hosts, or market owner can reopen this event'], 403);
    }
    
    if ($event['status'] !== 'closed') {
        json_response(['error' => 'Event must be closed to reopen'], 400);
    }
    
    if ($event['settled_at'] !== null) {
        json_response(['error' => 'Cannot reopen a resolved event'], 400);
    }
    
    $stmt = $pdo->prepare('UPDATE events SET status = \'open\' WHERE id = :event_id');
    $stmt->execute([':event_id' => $event['id']]);
    
    json_response(['ok' => true, 'message' => 'Event reopened for trading.']);
}

function handleResolve(PDO $pdo, int $userId, array $event, array $data): void {
    if (!canResolveEvent($pdo, (int)$event['id'], $userId, $event)) {
        json_response(['error' => 'Only the creator, resolver, hosts, or market owner can resolve this event'], 403);
    }
    
    if ($event['status'] !== 'closed') {
        json_response(['error' => 'Event must be closed before resolving'], 400);
    }
    
    $winningOutcome = sanitize_string($data['outcome'] ?? '', 64);
    
    if ($winningOutcome === '') {
        json_response(['error' => 'Winning outcome is required'], 400);
    }
    
    // Validate outcome
    if ($event['event_type'] === 'binary') {
        if (!in_array($winningOutcome, ['YES', 'NO'])) {
            json_response(['error' => 'Invalid outcome. Must be YES or NO.'], 400);
        }
        
        $stmt = $pdo->prepare('
            UPDATE events 
            SET status = \'resolved\', winning_side = :outcome, settled_at = NOW()
            WHERE id = :event_id
        ');
        $stmt->execute([':outcome' => $winningOutcome, ':event_id' => $event['id']]);
    } else {
        $outcomes = json_decode($event['outcomes_json'] ?? '[]', true);
        $validOutcomes = array_column($outcomes ?: [], 'id');
        
        if (!in_array($winningOutcome, $validOutcomes)) {
            json_response(['error' => 'Invalid outcome ID'], 400);
        }
        
        $stmt = $pdo->prepare('
            UPDATE events 
            SET status = \'resolved\', winning_outcome_id = :outcome, settled_at = NOW()
            WHERE id = :event_id
        ');
        $stmt->execute([':outcome' => $winningOutcome, ':event_id' => $event['id']]);
    }
    
    // Settle payouts using parimutuel system
    $payoutSummary = settleParimutuelPayouts($pdo, $event['id'], $event['event_type'], $winningOutcome);
    
    // Log the resolution action (if admin)
    $stmt = $pdo->prepare('SELECT is_admin FROM users WHERE id = ?');
    $stmt->execute([$userId]);
    $isAdmin = (int)$stmt->fetchColumn() === 1;
    
    if ($isAdmin) {
        logAdminAction($pdo, 'event_resolve', 'event', (string)$event['id'], 
            "Resolved event '{$event['title']}' with outcome: {$winningOutcome}");
    }
    
    json_response([
        'ok' => true, 
        'message' => 'Event resolved. Payouts distributed.',
        'payout_summary' => $payoutSummary,
    ]);
}

/**
 * Settle payouts using parimutuel system
 * 
 * Winners split the entire pool proportionally to their bet size
 */
function settleParimutuelPayouts(PDO $pdo, int $eventId, string $eventType, string $winningOutcome): array {
    // Get all bets
    $stmt = $pdo->prepare('
        SELECT b.*, u.name AS user_name, u.email AS user_email
        FROM bets b
        INNER JOIN users u ON u.id = b.user_id
        WHERE b.event_id = :event_id
    ');
    $stmt->execute([':event_id' => $eventId]);
    $bets = $stmt->fetchAll();
    
    // Get event title
    $stmt = $pdo->prepare('SELECT title FROM events WHERE id = :event_id');
    $stmt->execute([':event_id' => $eventId]);
    $eventTitle = $stmt->fetchColumn();
    
    // Calculate pool totals
    $totalPool = 0;
    $winningPool = 0;
    $winningBets = [];
    $losingBets = [];
    
    foreach ($bets as $bet) {
        $betAmount = (float) $bet['notional'];
        $totalPool += $betAmount;
        
        $isWinner = false;
        if ($eventType === 'binary') {
            $isWinner = $bet['side'] === $winningOutcome;
        } else {
            $isWinner = $bet['outcome_id'] === $winningOutcome;
        }
        
        if ($isWinner) {
            $winningPool += $betAmount;
            $winningBets[] = $bet;
        } else {
            $losingBets[] = $bet;
        }
    }
    
    $totalWinners = count($winningBets);
    $totalLosers = count($losingBets);
    $totalPaidOut = 0;
    
    // Edge case: no winners (everyone loses)
    if ($winningPool <= 0) {
        // Losers don't get anything back - already deducted
        return [
            'total_pool' => $totalPool,
            'winning_pool' => 0,
            'losing_pool' => $totalPool,
            'winners' => 0,
            'losers' => $totalLosers,
            'total_paid_out' => 0,
            'outcome' => $winningOutcome,
            'message' => 'No winners - all bets were on the losing side.',
        ];
    }
    
    // Edge case: no losers (everyone wins, just return their bets)
    if ($totalPool == $winningPool) {
        // Return original bets to winners
        foreach ($winningBets as $bet) {
            $payout = (float) $bet['notional'];
            
            $stmt = $pdo->prepare('
                UPDATE users SET tokens_balance = tokens_balance + :payout WHERE id = :user_id
            ');
            $stmt->execute([':payout' => $payout, ':user_id' => $bet['user_id']]);
            $totalPaidOut += $payout;
            
            // Notify
            send_event_resolved_email(
                $bet['user_email'],
                $bet['user_name'],
                $eventTitle,
                $winningOutcome,
                $payout
            );
        }
        
        return [
            'total_pool' => $totalPool,
            'winning_pool' => $winningPool,
            'losing_pool' => 0,
            'winners' => $totalWinners,
            'losers' => 0,
            'total_paid_out' => $totalPaidOut,
            'outcome' => $winningOutcome,
            'message' => 'All bets were on the winning side - original stakes returned.',
        ];
    }
    
    // Normal case: distribute total pool to winners proportionally
    // Payout = (user_bet / winning_pool) * total_pool
    $multiplier = $totalPool / $winningPool;
    
    foreach ($winningBets as $bet) {
        $betAmount = (float) $bet['notional'];
        $payout = round($betAmount * $multiplier, 2);
        $profit = $payout - $betAmount;
        
        $stmt = $pdo->prepare('
            UPDATE users SET tokens_balance = tokens_balance + :payout WHERE id = :user_id
        ');
        $stmt->execute([':payout' => $payout, ':user_id' => $bet['user_id']]);
        $totalPaidOut += $payout;
        
        // Send notification email
        send_event_resolved_email(
            $bet['user_email'],
            $bet['user_name'],
            $eventTitle,
            $winningOutcome,
            $payout
        );
        
        // Create notification
        try {
            $stmt = $pdo->prepare('
                INSERT INTO notifications (user_id, type, title, body, data)
                VALUES (:user_id, :type, :title, :body, :data)
            ');
            $stmt->execute([
                ':user_id' => $bet['user_id'],
                ':type' => 'bet_won',
                ':title' => 'You won!',
                ':body' => "You won " . number_format($payout, 0) . " tokens on \"" . substr($eventTitle, 0, 50) . "\"",
                ':data' => json_encode(['event_id' => $eventId, 'payout' => $payout, 'profit' => $profit]),
            ]);
        } catch (Exception $e) {
            // Notifications table might not exist, ignore
        }
    }
    
    // Notify losers
    foreach ($losingBets as $bet) {
        try {
            $stmt = $pdo->prepare('
                INSERT INTO notifications (user_id, type, title, body, data)
                VALUES (:user_id, :type, :title, :body, :data)
            ');
            $stmt->execute([
                ':user_id' => $bet['user_id'],
                ':type' => 'bet_lost',
                ':title' => 'Better luck next time',
                ':body' => "Your bet on \"" . substr($eventTitle, 0, 50) . "\" didn't win.",
                ':data' => json_encode(['event_id' => $eventId, 'lost' => $bet['notional']]),
            ]);
        } catch (Exception $e) {
            // Ignore
        }
    }
    
    return [
        'total_pool' => $totalPool,
        'winning_pool' => $winningPool,
        'losing_pool' => $totalPool - $winningPool,
        'multiplier' => round($multiplier, 2),
        'winners' => $totalWinners,
        'losers' => $totalLosers,
        'total_paid_out' => $totalPaidOut,
        'outcome' => $winningOutcome,
    ];
}

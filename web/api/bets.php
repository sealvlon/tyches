<?php
/**
 * Bets API - Parimutuel Pool Betting System
 * 
 * How it works:
 * - User bets X tokens on a side (YES/NO) or outcome
 * - Tokens go into the pool for that side
 * - Odds are determined by pool sizes, not fixed prices
 * - When event resolves, winners split all pools proportionally
 * 
 * POST: Place a bet
 * GET: Get user's bets on an event
 */

declare(strict_types=1);

require_once __DIR__ . '/security.php';
require_once __DIR__ . '/pools.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

try {
    if ($method === 'POST') {
        handle_place_bet();
    } elseif ($method === 'GET') {
        handle_get_bets();
    } else {
        json_response(['error' => 'Method not allowed'], 405);
    }
} catch (Throwable $e) {
    error_log('bets.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    json_response(['error' => 'Server error'], 500);
}

/**
 * GET /api/bets.php?event_id=X
 * Get user's position on an event with current odds
 */
function handle_get_bets(): void {
    $uid = require_auth();
    $pdo = get_pdo();
    
    $eventId = isset($_GET['event_id']) ? (int)$_GET['event_id'] : 0;
    
    if ($eventId <= 0) {
        json_response(['error' => 'event_id required'], 400);
    }
    
    // Get user's potential payout
    $position = get_potential_payout($pdo, $eventId, $uid);
    
    // Get current odds
    $odds = calculate_event_odds($pdo, $eventId);
    
    json_response([
        'event_id' => $eventId,
        'position' => $position,
        'odds' => $odds,
    ]);
}

/**
 * POST /api/bets.php
 * Place a bet on an event
 * 
 * Binary events:  { event_id, side: "YES"|"NO", amount }
 * Multiple choice: { event_id, outcome_id, amount }
 */
function handle_place_bet(): void {
    $uid = require_verified_auth(); // Requires email verification
    $pdo = get_pdo();

    // CSRF protection
    tyches_require_csrf();

    // Rate limiting
    tyches_require_rate_limit('bet_place:user:' . $uid, 60, 60);

    $raw  = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        $data = $_POST;
    }

    $eventId   = isset($data['event_id']) ? (int)$data['event_id'] : 0;
    $side      = strtoupper(sanitize_string($data['side'] ?? '', 3));
    $outcomeId = sanitize_string($data['outcome_id'] ?? '', 64);
    $amount    = isset($data['amount']) ? (float)$data['amount'] : 0;
    
    // Legacy support: if 'shares' is provided instead of 'amount', use shares
    if ($amount <= 0 && isset($data['shares'])) {
        $amount = (float)$data['shares'];
    }

    // Validation
    if ($eventId <= 0) {
        json_response(['error' => 'Invalid event_id'], 400);
    }
    
    if ($amount <= 0) {
        json_response(['error' => 'Amount must be greater than 0'], 400);
    }
    
    // Minimum bet
    if ($amount < 1) {
        json_response(['error' => 'Minimum bet is 1 token'], 400);
    }

    // Load event and ensure user is allowed to trade
    $stmt = $pdo->prepare(
        'SELECT e.*, m.id AS market_id
         FROM events e
         INNER JOIN markets m ON m.id = e.market_id
         INNER JOIN market_members mm ON mm.market_id = m.id AND mm.user_id = :uid
         WHERE e.id = :eid
         LIMIT 1'
    );
    $stmt->execute([':uid' => $uid, ':eid' => $eventId]);
    $event = $stmt->fetch();
    
    if (!$event) {
        json_response(['error' => 'Event not found or not accessible'], 404);
    }

    if ($event['status'] !== 'open') {
        json_response(['error' => 'Event is not open for trading'], 400);
    }

    // Validate side/outcome based on event type
    if ($event['event_type'] === 'binary') {
        if (!in_array($side, ['YES', 'NO'], true)) {
            json_response(['error' => 'Binary bets must specify side: YES or NO'], 400);
        }
        $outcomeId = null;
    } else {
        if ($outcomeId === '') {
            json_response(['error' => 'Multiple-choice bets must specify outcome_id'], 400);
        }
        $side = null;

        // Verify outcome exists
        if (!empty($event['outcomes_json'])) {
            $outcomes = json_decode((string)$event['outcomes_json'], true);
            $validIds = [];
            if (is_array($outcomes)) {
                foreach ($outcomes as $o) {
                    if (!empty($o['id'])) {
                        $validIds[] = (string)$o['id'];
                    }
                }
            }
            if (!in_array($outcomeId, $validIds, true)) {
                json_response(['error' => 'Unknown outcome_id for this event'], 400);
            }
        }
    }

    $pdo->beginTransaction();

    try {
        // Lock user row and check balance
        $stmtUser = $pdo->prepare(
            'SELECT tokens_balance FROM users WHERE id = :id FOR UPDATE'
        );
        $stmtUser->execute([':id' => $uid]);
        $userRow = $stmtUser->fetch();
        
        if (!$userRow) {
            throw new RuntimeException('User not found');
        }
        
        $balance = (float)$userRow['tokens_balance'];
        if ($balance < $amount) {
            $pdo->rollBack();
            json_response(['error' => 'Insufficient token balance. You have ' . number_format($balance, 0) . ' tokens.'], 400);
        }

        // Get current odds BEFORE the bet (for display)
        $oddsBefore = calculate_event_odds($pdo, $eventId);

        // Insert bet
        $stmtBet = $pdo->prepare(
            'INSERT INTO bets (user_id, event_id, side, outcome_id, shares, price, notional)
             VALUES (:uid, :eid, :side, :outcome_id, :shares, :price, :notional)'
        );
        $stmtBet->execute([
            ':uid'        => $uid,
            ':eid'        => $eventId,
            ':side'       => $side,
            ':outcome_id' => $outcomeId,
            ':shares'     => $amount, // In parimutuel, shares = amount bet
            ':price'      => 100,     // Price is always 100 (1 token = 1 share)
            ':notional'   => $amount, // Notional = amount bet
        ]);

        // Debit tokens from user
        $stmtUserUpd = $pdo->prepare(
            'UPDATE users SET tokens_balance = tokens_balance - :amount WHERE id = :id'
        );
        $stmtUserUpd->execute([
            ':amount' => $amount,
            ':id'     => $uid,
        ]);

        // Update event volume and trader count
        // Check if this is user's first bet on this event
        $stmtFirstBet = $pdo->prepare(
            'SELECT COUNT(*) FROM bets WHERE event_id = :eid AND user_id = :uid'
        );
        $stmtFirstBet->execute([':eid' => $eventId, ':uid' => $uid]);
        $betCount = (int)$stmtFirstBet->fetchColumn();
        
        $traderIncrement = ($betCount === 1) ? 1 : 0; // Only increment on first bet
        
        $stmtUpd = $pdo->prepare(
            'UPDATE events
             SET volume = volume + :amount,
                 traders_count = traders_count + :trader_inc
             WHERE id = :id'
        );
        $stmtUpd->execute([
            ':amount' => $amount,
            ':trader_inc' => $traderIncrement,
            ':id' => $eventId,
        ]);

        $pdo->commit();
        
        // Get new odds AFTER the bet
        $oddsAfter = calculate_event_odds($pdo, $eventId);
        
        // Calculate potential payout
        $selectedSide = $side ?? $outcomeId;
        if ($event['event_type'] === 'binary') {
            $potentialReturn = $amount * ($selectedSide === 'YES' ? $oddsAfter['yes_odds'] : $oddsAfter['no_odds']);
        } else {
            $potentialReturn = $amount;
            foreach ($oddsAfter['outcomes'] as $o) {
                if ($o['id'] === $selectedSide) {
                    $potentialReturn = $amount * $o['odds'];
                    break;
                }
            }
        }

        // Notify event creator about the new bet
        notifyAboutBet($pdo, $eventId, (int)$event['creator_id'], $uid, $amount);
        
        json_response([
            'ok' => true,
            'event_id' => $eventId,
            'side' => $side,
            'outcome_id' => $outcomeId,
            'amount' => $amount,
            'potential_return' => round($potentialReturn, 2),
            'potential_profit' => round($potentialReturn - $amount, 2),
            'odds_before' => $oddsBefore,
            'odds_after' => $oddsAfter,
            'new_balance' => $balance - $amount,
        ], 201);
        
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        throw $e;
    }
}

/**
 * Notify event creator about a new bet
 */
function notifyAboutBet(PDO $pdo, int $eventId, int $creatorId, int $bettorId, $amount): void {
    // Don't notify yourself
    if ($creatorId === $bettorId) return;
    
    $amount = (int)$amount;
    
    try {
        $stmt = $pdo->prepare("
            INSERT INTO notifications (user_id, type, title, message)
            VALUES (?, 'bet_placed', 'New bet on your event! 💰', ?)
        ");
        $stmt->execute([
            $creatorId,
            "Someone bet {$amount} tokens on your event"
        ]);
    } catch (Throwable $e) {
        // Silently fail - don't break the bet
    }
}

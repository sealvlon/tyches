<?php
/**
 * Pool Mechanics Helper Functions
 * 
 * Parimutuel betting system for Tyches:
 * - All bets go into pools (YES pool, NO pool, or outcome pools)
 * - Odds are determined by pool sizes
 * - Winners split the losing pools proportionally
 * 
 * Example Binary:
 *   YES pool: 1000 tokens, NO pool: 500 tokens
 *   Total pool: 1500 tokens
 *   YES odds: 1500/1000 = 1.5x (if you bet 100, you get 150 if YES wins)
 *   NO odds: 1500/500 = 3x (if you bet 100, you get 300 if NO wins)
 *   Implied probability: YES = 1000/1500 = 66.7%, NO = 500/1500 = 33.3%
 * 
 * Example Multi-Choice:
 *   Pool A: 400, Pool B: 300, Pool C: 300
 *   Total: 1000 tokens
 *   A odds: 1000/400 = 2.5x
 *   B odds: 1000/300 = 3.33x
 *   C odds: 1000/300 = 3.33x
 */

declare(strict_types=1);

/**
 * Calculate current odds and implied probabilities for an event
 */
function calculate_event_odds(PDO $pdo, int $eventId): array {
    // Get event type
    $stmt = $pdo->prepare('SELECT event_type, outcomes_json FROM events WHERE id = ?');
    $stmt->execute([$eventId]);
    $event = $stmt->fetch();
    
    if (!$event) {
        return ['error' => 'Event not found'];
    }
    
    if ($event['event_type'] === 'binary') {
        return calculate_binary_odds($pdo, $eventId);
    } else {
        return calculate_multi_odds($pdo, $eventId, json_decode($event['outcomes_json'], true) ?: []);
    }
}

/**
 * Calculate odds for binary (YES/NO) events
 * 
 * IMPORTANT: In parimutuel betting, odds are REAL - they reflect actual pool sizes.
 * If there's no money on the opposing side, your profit is ZERO.
 * We do NOT use phantom/virtual pools to create fake returns.
 */
function calculate_binary_odds(PDO $pdo, int $eventId): array {
    // Sum up all bets by side
    $stmt = $pdo->prepare("
        SELECT 
            COALESCE(SUM(CASE WHEN side = 'YES' THEN notional ELSE 0 END), 0) as yes_pool,
            COALESCE(SUM(CASE WHEN side = 'NO' THEN notional ELSE 0 END), 0) as no_pool
        FROM bets 
        WHERE event_id = ?
    ");
    $stmt->execute([$eventId]);
    $pools = $stmt->fetch();
    
    $yesPool = (float) $pools['yes_pool'];
    $noPool = (float) $pools['no_pool'];
    $totalPool = $yesPool + $noPool;
    
    // Handle edge cases honestly
    if ($totalPool == 0) {
        // No bets yet - return neutral display values
        // In reality, if you bet alone, you get NO profit
        return [
            'yes_pool' => 0,
            'no_pool' => 0,
            'total_pool' => 0,
            'yes_odds' => 1.0,  // 1x = no profit (you only get your bet back)
            'no_odds' => 1.0,
            'yes_percent' => 50,
            'no_percent' => 50,
            'yes_potential_return' => 1.0,
            'no_potential_return' => 1.0,
            'low_liquidity' => true,
            'liquidity_warning' => 'No bets yet. Your profit depends on others betting against you.',
        ];
    }
    
    // Calculate REAL odds without phantom pools
    // If one side is empty, odds for that side = infinity (you'd get everything)
    // But for the populated side, odds = 1x (you only get your money back)
    
    $yesOdds = $yesPool > 0 ? $totalPool / $yesPool : 0;
    $noOdds = $noPool > 0 ? $totalPool / $noPool : 0;
    
    // Calculate implied probabilities from real pools
    if ($totalPool > 0) {
        $yesPercent = round(($yesPool / $totalPool) * 100);
        $noPercent = 100 - $yesPercent;
    } else {
        $yesPercent = 50;
        $noPercent = 50;
    }
    
    // Detect low liquidity situations
    $lowLiquidity = ($yesPool == 0 || $noPool == 0 || $totalPool < 100);
    $liquidityWarning = null;
    if ($yesPool == 0) {
        $liquidityWarning = 'No YES bets yet. If you bet YES and no one bets NO, profit is $0.';
    } elseif ($noPool == 0) {
        $liquidityWarning = 'No NO bets yet. If you bet NO and no one bets YES, profit is $0.';
    } elseif ($totalPool < 100) {
        $liquidityWarning = 'Low activity. Your final odds depend on future bets.';
    }
    
    return [
        'yes_pool' => $yesPool,
        'no_pool' => $noPool,
        'total_pool' => $totalPool,
        'yes_odds' => round($yesOdds, 2),
        'no_odds' => round($noOdds, 2),
        'yes_percent' => (int) $yesPercent,
        'no_percent' => (int) $noPercent,
        'yes_potential_return' => round($yesOdds, 2),
        'no_potential_return' => round($noOdds, 2),
        'low_liquidity' => $lowLiquidity,
        'liquidity_warning' => $liquidityWarning,
    ];
}

/**
 * Calculate odds for multi-choice events
 * 
 * IMPORTANT: In parimutuel betting, if your outcome's pool is the only one,
 * your profit is ZERO. You need OTHER outcomes to have bets to win anything.
 */
function calculate_multi_odds(PDO $pdo, int $eventId, array $outcomes): array {
    // Sum up all bets by outcome
    $stmt = $pdo->prepare("
        SELECT outcome_id, COALESCE(SUM(notional), 0) as pool
        FROM bets 
        WHERE event_id = ?
        GROUP BY outcome_id
    ");
    $stmt->execute([$eventId]);
    $poolRows = $stmt->fetchAll(PDO::FETCH_KEY_PAIR);
    
    // Build outcome data
    $totalPool = 0;
    $outcomeData = [];
    $outcomesWithBets = 0;
    
    foreach ($outcomes as $outcome) {
        $id = $outcome['id'];
        $pool = (float) ($poolRows[$id] ?? 0);
        $totalPool += $pool;
        if ($pool > 0) $outcomesWithBets++;
        $outcomeData[$id] = [
            'id' => $id,
            'label' => $outcome['label'],
            'pool' => $pool,
        ];
    }
    
    // Calculate REAL odds and probabilities (no phantom pools)
    $lowLiquidity = ($totalPool < 100 || $outcomesWithBets < 2);
    
    foreach ($outcomeData as $id => &$data) {
        if ($totalPool == 0) {
            // No bets - show equal split as placeholder, but odds are 1x (no profit)
            $data['odds'] = 1.0;
            $data['percent'] = round(100 / count($outcomes));
        } else if ($data['pool'] == 0) {
            // No bets on this outcome - if you bet here and win, you get EVERYTHING
            // Odds = infinity, but cap at 100x for display
            $data['odds'] = $totalPool > 0 ? 100.0 : 1.0;
            $data['percent'] = 0;
        } else {
            // Normal calculation
            $data['odds'] = round($totalPool / $data['pool'], 2);
            $data['percent'] = round(($data['pool'] / $totalPool) * 100);
        }
        
        $data['potential_return'] = $data['odds'];
    }
    
    // Generate warning
    $liquidityWarning = null;
    if ($totalPool == 0) {
        $liquidityWarning = 'No bets yet. Your profit depends on others betting on losing outcomes.';
    } elseif ($outcomesWithBets < 2) {
        $liquidityWarning = 'Only one outcome has bets. If it wins, everyone just gets their money back.';
    } elseif ($totalPool < 100) {
        $liquidityWarning = 'Low activity. Your final odds depend on future bets.';
    }
    
    return [
        'total_pool' => $totalPool,
        'outcomes' => array_values($outcomeData),
        'low_liquidity' => $lowLiquidity,
        'liquidity_warning' => $liquidityWarning,
    ];
}

/**
 * Calculate payout for a winning bet
 * 
 * @param float $betAmount The amount the user bet
 * @param float $userSidePool Total pool for the winning side
 * @param float $totalPool Total pool across all sides
 * @return float The payout amount
 */
function calculate_payout(float $betAmount, float $userSidePool, float $totalPool): float {
    if ($userSidePool <= 0) {
        return $betAmount; // Edge case: return original bet
    }
    
    // User's share of the winning pool
    $shareOfPool = $betAmount / $userSidePool;
    
    // Total payout = share of entire pool
    $payout = $shareOfPool * $totalPool;
    
    return round($payout, 2);
}

/**
 * Get a user's potential payout if their side wins
 */
function get_potential_payout(PDO $pdo, int $eventId, int $userId): array {
    // Get user's bets on this event
    $stmt = $pdo->prepare("
        SELECT side, outcome_id, SUM(notional) as total_bet
        FROM bets 
        WHERE event_id = ? AND user_id = ?
        GROUP BY side, outcome_id
    ");
    $stmt->execute([$eventId, $userId]);
    $userBets = $stmt->fetchAll();
    
    if (empty($userBets)) {
        return ['has_position' => false];
    }
    
    // Get current odds
    $odds = calculate_event_odds($pdo, $eventId);
    
    $positions = [];
    foreach ($userBets as $bet) {
        $side = $bet['side'] ?? $bet['outcome_id'];
        $amount = (float) $bet['total_bet'];
        
        if (isset($odds['yes_odds'])) {
            // Binary
            $multiplier = $side === 'YES' ? $odds['yes_odds'] : $odds['no_odds'];
        } else {
            // Multi-choice
            $multiplier = 1;
            foreach ($odds['outcomes'] as $o) {
                if ($o['id'] === $side) {
                    $multiplier = $o['odds'];
                    break;
                }
            }
        }
        
        $positions[] = [
            'side' => $side,
            'amount' => $amount,
            'potential_payout' => round($amount * $multiplier, 2),
            'potential_profit' => round($amount * ($multiplier - 1), 2),
        ];
    }
    
    return [
        'has_position' => true,
        'positions' => $positions,
        'odds' => $odds,
    ];
}


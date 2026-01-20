<?php
// api/analytics.php
// User analytics dashboard data

declare(strict_types=1);

require_once __DIR__ . '/helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['error' => 'Method not allowed'], 405);
}

try {
    handle_analytics();
} catch (Throwable $e) {
    error_log('analytics.php error: ' . $e->getMessage());
    json_response(['error' => 'Server error'], 500);
}

function handle_analytics(): void {
    $userId = require_auth();
    $pdo = get_pdo();
    
    $period = $_GET['period'] ?? '30'; // days
    $periodDays = min(max((int)$period, 7), 365);
    
    // Get basic stats
    $stats = getBasicStats($pdo, $userId);
    
    // Get betting history chart data
    $bettingHistory = getBettingHistory($pdo, $userId, $periodDays);
    
    // Get performance by market
    $marketPerformance = getMarketPerformance($pdo, $userId);
    
    // Get win/loss breakdown
    $outcomes = getOutcomeBreakdown($pdo, $userId);
    
    // Get recent activity
    $recentActivity = getRecentActivity($pdo, $userId);
    
    // Get prediction accuracy over time
    $accuracyTrend = getAccuracyTrend($pdo, $userId, $periodDays);
    
    // Get token balance history
    $balanceHistory = getBalanceHistory($pdo, $userId, $periodDays);
    
    json_response([
        'stats' => $stats,
        'betting_history' => $bettingHistory,
        'market_performance' => $marketPerformance,
        'outcomes' => $outcomes,
        'recent_activity' => $recentActivity,
        'accuracy_trend' => $accuracyTrend,
        'balance_history' => $balanceHistory,
        'period_days' => $periodDays,
    ]);
}

function getBasicStats(PDO $pdo, int $userId): array {
    // Total bets and volume
    $stmt = $pdo->prepare('
        SELECT 
            COUNT(*) AS total_bets,
            COALESCE(SUM(notional), 0) AS total_volume,
            COUNT(DISTINCT event_id) AS events_participated
        FROM bets
        WHERE user_id = :uid
    ');
    $stmt->execute([':uid' => $userId]);
    $betsStats = $stmt->fetch();
    
    // Wins and losses from resolved events
    $stmt = $pdo->prepare('
        SELECT 
            SUM(CASE 
                WHEN (e.event_type = \'binary\' AND b.side = e.winning_side) 
                  OR (e.event_type = \'multiple\' AND b.outcome_id = e.winning_outcome_id) 
                THEN 1 ELSE 0 
            END) AS wins,
            SUM(CASE 
                WHEN e.status = \'resolved\' AND (
                    (e.event_type = \'binary\' AND b.side != e.winning_side) 
                    OR (e.event_type = \'multiple\' AND b.outcome_id != e.winning_outcome_id)
                )
                THEN 1 ELSE 0 
            END) AS losses,
            COUNT(CASE WHEN e.status = \'resolved\' THEN 1 END) AS resolved_bets
        FROM bets b
        INNER JOIN events e ON e.id = b.event_id
        WHERE b.user_id = :uid
    ');
    $stmt->execute([':uid' => $userId]);
    $outcomeStats = $stmt->fetch();
    
    // Calculate profit/loss
    $stmt = $pdo->prepare('
        SELECT 
            COALESCE(SUM(
                CASE 
                    WHEN (e.event_type = \'binary\' AND b.side = e.winning_side) 
                      OR (e.event_type = \'multiple\' AND b.outcome_id = e.winning_outcome_id)
                    THEN b.shares * (100 - b.price) / 100
                    WHEN e.status = \'resolved\'
                    THEN -b.notional
                    ELSE 0
                END
            ), 0) AS net_profit
        FROM bets b
        INNER JOIN events e ON e.id = b.event_id
        WHERE b.user_id = :uid
    ');
    $stmt->execute([':uid' => $userId]);
    $profitStats = $stmt->fetch();
    
    // Get current balance
    $stmt = $pdo->prepare('SELECT tokens_balance FROM users WHERE id = :uid');
    $stmt->execute([':uid' => $userId]);
    $balance = (float)$stmt->fetchColumn();
    
    $wins = (int)($outcomeStats['wins'] ?? 0);
    $losses = (int)($outcomeStats['losses'] ?? 0);
    $resolvedBets = (int)($outcomeStats['resolved_bets'] ?? 0);
    
    return [
        'total_bets' => (int)($betsStats['total_bets'] ?? 0),
        'total_volume' => (float)($betsStats['total_volume'] ?? 0),
        'events_participated' => (int)($betsStats['events_participated'] ?? 0),
        'wins' => $wins,
        'losses' => $losses,
        'pending' => (int)($betsStats['total_bets'] ?? 0) - $resolvedBets,
        'win_rate' => $resolvedBets > 0 ? round(($wins / $resolvedBets) * 100, 1) : 0,
        'net_profit' => (float)($profitStats['net_profit'] ?? 0),
        'tokens_balance' => $balance,
        'avg_bet_size' => $betsStats['total_bets'] > 0 
            ? round($betsStats['total_volume'] / $betsStats['total_bets'], 2) 
            : 0,
    ];
}

function getBettingHistory(PDO $pdo, int $userId, int $days): array {
    $stmt = $pdo->prepare('
        SELECT 
            DATE(created_at) AS date,
            COUNT(*) AS bets,
            SUM(notional) AS volume
        FROM bets
        WHERE user_id = :uid
          AND created_at >= DATE_SUB(CURDATE(), INTERVAL :days DAY)
        GROUP BY DATE(created_at)
        ORDER BY date ASC
    ');
    $stmt->execute([':uid' => $userId, ':days' => $days]);
    
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

function getMarketPerformance(PDO $pdo, int $userId): array {
    $stmt = $pdo->prepare('
        SELECT 
            m.id,
            m.name,
            m.avatar_emoji,
            COUNT(b.id) AS total_bets,
            SUM(b.notional) AS volume,
            SUM(CASE 
                WHEN (e.event_type = \'binary\' AND b.side = e.winning_side) 
                  OR (e.event_type = \'multiple\' AND b.outcome_id = e.winning_outcome_id)
                THEN 1 ELSE 0 
            END) AS wins,
            SUM(CASE WHEN e.status = \'resolved\' THEN 1 ELSE 0 END) AS resolved
        FROM bets b
        INNER JOIN events e ON e.id = b.event_id
        INNER JOIN markets m ON m.id = e.market_id
        WHERE b.user_id = :uid
        GROUP BY m.id
        ORDER BY volume DESC
        LIMIT 10
    ');
    $stmt->execute([':uid' => $userId]);
    $rows = $stmt->fetchAll();
    
    return array_map(function($row) {
        $resolved = (int)$row['resolved'];
        $wins = (int)$row['wins'];
        return [
            'market_id' => (int)$row['id'],
            'name' => $row['name'],
            'emoji' => $row['avatar_emoji'] ?? '🎯',
            'total_bets' => (int)$row['total_bets'],
            'volume' => (float)$row['volume'],
            'wins' => $wins,
            'resolved' => $resolved,
            'win_rate' => $resolved > 0 ? round(($wins / $resolved) * 100, 1) : 0,
        ];
    }, $rows);
}

function getOutcomeBreakdown(PDO $pdo, int $userId): array {
    $stmt = $pdo->prepare('
        SELECT 
            CASE 
                WHEN e.status != \'resolved\' THEN \'pending\'
                WHEN (e.event_type = \'binary\' AND b.side = e.winning_side) 
                  OR (e.event_type = \'multiple\' AND b.outcome_id = e.winning_outcome_id)
                THEN \'won\'
                ELSE \'lost\'
            END AS outcome,
            COUNT(*) AS count,
            SUM(b.notional) AS volume
        FROM bets b
        INNER JOIN events e ON e.id = b.event_id
        WHERE b.user_id = :uid
        GROUP BY outcome
    ');
    $stmt->execute([':uid' => $userId]);
    
    $results = ['won' => 0, 'lost' => 0, 'pending' => 0];
    foreach ($stmt->fetchAll() as $row) {
        $results[$row['outcome']] = [
            'count' => (int)$row['count'],
            'volume' => (float)$row['volume'],
        ];
    }
    
    return $results;
}

function getRecentActivity(PDO $pdo, int $userId): array {
    $stmt = $pdo->prepare('
        SELECT 
            b.id,
            b.side,
            b.outcome_id,
            b.shares,
            b.price,
            b.notional,
            b.created_at,
            e.id AS event_id,
            e.title AS event_title,
            e.status AS event_status,
            e.winning_side,
            e.winning_outcome_id,
            m.name AS market_name
        FROM bets b
        INNER JOIN events e ON e.id = b.event_id
        INNER JOIN markets m ON m.id = e.market_id
        WHERE b.user_id = :uid
        ORDER BY b.created_at DESC
        LIMIT 20
    ');
    $stmt->execute([':uid' => $userId]);
    
    return array_map(function($row) {
        $outcome = 'pending';
        if ($row['event_status'] === 'resolved') {
            $isWin = ($row['side'] && $row['side'] === $row['winning_side']) ||
                     ($row['outcome_id'] && $row['outcome_id'] === $row['winning_outcome_id']);
            $outcome = $isWin ? 'won' : 'lost';
        }
        
        return [
            'id' => (int)$row['id'],
            'event_id' => (int)$row['event_id'],
            'event_title' => $row['event_title'],
            'market_name' => $row['market_name'],
            'side' => $row['side'] ?? $row['outcome_id'],
            'shares' => (int)$row['shares'],
            'price' => (int)$row['price'],
            'notional' => (float)$row['notional'],
            'outcome' => $outcome,
            'created_at' => $row['created_at'],
        ];
    }, $stmt->fetchAll());
}

function getAccuracyTrend(PDO $pdo, int $userId, int $days): array {
    $stmt = $pdo->prepare('
        SELECT 
            DATE(e.settled_at) AS date,
            SUM(CASE 
                WHEN (e.event_type = \'binary\' AND b.side = e.winning_side) 
                  OR (e.event_type = \'multiple\' AND b.outcome_id = e.winning_outcome_id)
                THEN 1 ELSE 0 
            END) AS wins,
            COUNT(*) AS total
        FROM bets b
        INNER JOIN events e ON e.id = b.event_id
        WHERE b.user_id = :uid
          AND e.status = \'resolved\'
          AND e.settled_at >= DATE_SUB(CURDATE(), INTERVAL :days DAY)
        GROUP BY DATE(e.settled_at)
        ORDER BY date ASC
    ');
    $stmt->execute([':uid' => $userId, ':days' => $days]);
    
    return array_map(function($row) {
        return [
            'date' => $row['date'],
            'accuracy' => (int)$row['total'] > 0 
                ? round(((int)$row['wins'] / (int)$row['total']) * 100, 1) 
                : 0,
            'bets_resolved' => (int)$row['total'],
        ];
    }, $stmt->fetchAll());
}

function getBalanceHistory(PDO $pdo, int $userId, int $days): array {
    // Reconstruct balance history from bets
    // This is a simplified version - in production you'd want a balance_history table
    $stmt = $pdo->prepare('
        SELECT 
            DATE(b.created_at) AS date,
            SUM(
                CASE 
                    WHEN e.status = \'resolved\' AND (
                        (e.event_type = \'binary\' AND b.side = e.winning_side) 
                        OR (e.event_type = \'multiple\' AND b.outcome_id = e.winning_outcome_id)
                    )
                    THEN b.shares * (100 - b.price) / 100
                    WHEN e.status = \'resolved\'
                    THEN -b.notional
                    ELSE 0
                END
            ) AS daily_change
        FROM bets b
        INNER JOIN events e ON e.id = b.event_id
        WHERE b.user_id = :uid
          AND b.created_at >= DATE_SUB(CURDATE(), INTERVAL :days DAY)
        GROUP BY DATE(b.created_at)
        ORDER BY date ASC
    ');
    $stmt->execute([':uid' => $userId, ':days' => $days]);
    
    $history = [];
    $runningTotal = 0;
    
    foreach ($stmt->fetchAll() as $row) {
        $runningTotal += (float)$row['daily_change'];
        $history[] = [
            'date' => $row['date'],
            'change' => (float)$row['daily_change'],
            'cumulative' => $runningTotal,
        ];
    }
    
    return $history;
}


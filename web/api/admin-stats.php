<?php
// api/admin-stats.php
// Aggregated metrics and time-series data for the admin dashboard.
// Only accessible to admin users.

declare(strict_types=1);

require_once __DIR__ . '/helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method !== 'GET') {
    json_response(['error' => 'Method not allowed'], 405);
}

try {
    $pdo = get_pdo();
    // Enforce admin access
    require_admin($pdo);

    // --- High-level KPIs ---
    $totalUsers = (int)$pdo->query('SELECT COUNT(*) FROM users')->fetchColumn();
    $totalMarkets = (int)$pdo->query('SELECT COUNT(*) FROM markets')->fetchColumn();
    $totalEvents = (int)$pdo->query('SELECT COUNT(*) FROM events')->fetchColumn();

    $stmtEventsStatus = $pdo->query(
        'SELECT status, COUNT(*) AS c
         FROM events
         GROUP BY status'
    );
    $eventsByStatus = [
        'open'     => 0,
        'closed'   => 0,
        'resolved' => 0,
    ];
    foreach ($stmtEventsStatus->fetchAll() ?: [] as $row) {
        $status = $row['status'];
        if (isset($eventsByStatus[$status])) {
            $eventsByStatus[$status] = (int)$row['c'];
        }
    }

    $stmtBetsTotals = $pdo->query(
        'SELECT COUNT(*) AS bets_count, COALESCE(SUM(notional), 0) AS volume_total
         FROM bets'
    );
    $betsRow = $stmtBetsTotals->fetch() ?: ['bets_count' => 0, 'volume_total' => 0];

    $stmtNewUsers7 = $pdo->query(
        'SELECT COUNT(*) 
         FROM users 
         WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)'
    );
    $newUsers7 = (int)$stmtNewUsers7->fetchColumn();

    // --- Time series (last 30 days) ---
    $signups = [];
    $stmtSignups = $pdo->query(
        'SELECT DATE(created_at) AS d, COUNT(*) AS c
         FROM users
         WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 29 DAY)
         GROUP BY DATE(created_at)
         ORDER BY d'
    );
    foreach ($stmtSignups->fetchAll() ?: [] as $row) {
        $signups[] = [
            'date'  => $row['d'],
            'count' => (int)$row['c'],
        ];
    }

    $betsSeries = [];
    $stmtBetsSeries = $pdo->query(
        'SELECT DATE(created_at) AS d,
                COUNT(*) AS bets,
                COALESCE(SUM(notional), 0) AS volume
         FROM bets
         WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 29 DAY)
         GROUP BY DATE(created_at)
         ORDER BY d'
    );
    foreach ($stmtBetsSeries->fetchAll() ?: [] as $row) {
        $betsSeries[] = [
            'date'   => $row['d'],
            'bets'   => (int)$row['bets'],
            'volume' => (float)$row['volume'],
        ];
    }

    $eventsSeries = [];
    $stmtEventsSeries = $pdo->query(
        'SELECT DATE(created_at) AS d, COUNT(*) AS c
         FROM events
         WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 29 DAY)
         GROUP BY DATE(created_at)
         ORDER BY d'
    );
    foreach ($stmtEventsSeries->fetchAll() ?: [] as $row) {
        $eventsSeries[] = [
            'date'  => $row['d'],
            'count' => (int)$row['c'],
        ];
    }

    // --- Top aggregates ---
    $topMarkets = [];
    $stmtTopMarkets = $pdo->query(
        'SELECT m.id,
                m.name,
                m.avatar_emoji,
                COUNT(DISTINCT e.id) AS events_count,
                COUNT(DISTINCT mm.user_id) AS members_count
         FROM markets m
         LEFT JOIN events e ON e.market_id = m.id
         LEFT JOIN market_members mm ON mm.market_id = m.id
         GROUP BY m.id, m.name, m.avatar_emoji
         ORDER BY events_count DESC
         LIMIT 5'
    );
    foreach ($stmtTopMarkets->fetchAll() ?: [] as $row) {
        $topMarkets[] = [
            'id'            => (int)$row['id'],
            'name'          => $row['name'],
            'avatar_emoji'  => $row['avatar_emoji'],
            'events_count'  => (int)$row['events_count'],
            'members_count' => (int)$row['members_count'],
        ];
    }

    $topEvents = [];
    $stmtTopEvents = $pdo->query(
        'SELECT e.id,
                e.title,
                e.status,
                e.volume,
                e.traders_count,
                m.name AS market_name
         FROM events e
         INNER JOIN markets m ON m.id = e.market_id
         ORDER BY e.volume DESC
         LIMIT 10'
    );
    foreach ($stmtTopEvents->fetchAll() ?: [] as $row) {
        $topEvents[] = [
            'id'            => (int)$row['id'],
            'title'         => $row['title'],
            'status'        => $row['status'],
            'volume'        => (float)$row['volume'],
            'traders_count' => (int)$row['traders_count'],
            'market_name'   => $row['market_name'],
        ];
    }

    // --- Recent activity ---
    $recentUsers = [];
    $stmtRecentUsers = $pdo->query(
        'SELECT id, name, username, email, created_at, is_admin
         FROM users
         ORDER BY created_at DESC
         LIMIT 8'
    );
    foreach ($stmtRecentUsers->fetchAll() ?: [] as $row) {
        $recentUsers[] = [
            'id'        => (int)$row['id'],
            'name'      => $row['name'],
            'username'  => $row['username'],
            'email'     => $row['email'],
            'created_at'=> $row['created_at'],
            'is_admin'  => (int)$row['is_admin'] === 1,
        ];
    }

    $recentEvents = [];
    $stmtRecentEvents = $pdo->query(
        'SELECT e.id,
                e.title,
                e.status,
                e.created_at,
                e.closes_at,
                e.volume,
                m.name AS market_name
         FROM events e
         INNER JOIN markets m ON m.id = e.market_id
         ORDER BY e.created_at DESC
         LIMIT 10'
    );
    foreach ($stmtRecentEvents->fetchAll() ?: [] as $row) {
        $recentEvents[] = [
            'id'          => (int)$row['id'],
            'title'       => $row['title'],
            'status'      => $row['status'],
            'created_at'  => $row['created_at'],
            'closes_at'   => $row['closes_at'],
            'volume'      => (float)$row['volume'],
            'market_name' => $row['market_name'],
        ];
    }

    $recentBets = [];
    $stmtRecentBets = $pdo->query(
        'SELECT b.id,
                b.event_id,
                b.user_id,
                b.side,
                b.outcome_id,
                b.shares,
                b.price,
                b.notional,
                b.created_at,
                u.username,
                e.title AS event_title
         FROM bets b
         INNER JOIN users u ON u.id = b.user_id
         INNER JOIN events e ON e.id = b.event_id
         ORDER BY b.created_at DESC
         LIMIT 15'
    );
    foreach ($stmtRecentBets->fetchAll() ?: [] as $row) {
        $recentBets[] = [
            'id'          => (int)$row['id'],
            'event_id'    => (int)$row['event_id'],
            'user_id'     => (int)$row['user_id'],
            'username'    => $row['username'],
            'event_title' => $row['event_title'],
            'side'        => $row['side'],
            'outcome_id'  => $row['outcome_id'],
            'shares'      => (int)$row['shares'],
            'price'       => (int)$row['price'],
            'notional'    => (float)$row['notional'],
            'created_at'  => $row['created_at'],
        ];
    }

    json_response([
        'kpis' => [
            'total_users'        => $totalUsers,
            'total_markets'      => $totalMarkets,
            'total_events'       => $totalEvents,
            'events_open'        => $eventsByStatus['open'],
            'events_closed'      => $eventsByStatus['closed'],
            'events_resolved'    => $eventsByStatus['resolved'],
            'total_bets'         => (int)$betsRow['bets_count'],
            'total_volume'       => (float)$betsRow['volume_total'],
            'new_users_7d'       => $newUsers7,
        ],
        'series' => [
            'signups'      => $signups,
            'bets'         => $betsSeries,
            'events'       => $eventsSeries,
        ],
        'top_markets'    => $topMarkets,
        'top_events'     => $topEvents,
        'recent_users'   => $recentUsers,
        'recent_events'  => $recentEvents,
        'recent_bets'    => $recentBets,
    ]);
} catch (Throwable $e) {
    error_log('admin-stats.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    json_response(['error' => 'Server error'], 500);
}



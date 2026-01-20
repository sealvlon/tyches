<?php
/**
 * User Stats API - Get detailed stats for profile
 * Returns real calculated stats from database
 */

declare(strict_types=1);

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/security.php';
require_once __DIR__ . '/helpers.php';

tyches_start_session();

// Require authentication
if (empty($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['error' => 'Authentication required']);
    exit;
}

$userId = (int) ($_GET['user_id'] ?? $_SESSION['user_id']);
$method = $_SERVER['REQUEST_METHOD'];

if ($method !== 'GET') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

// Get user basic info
$stmt = $pdo->prepare("
    SELECT 
        id, name, username, email, tokens_balance, 
        COALESCE(xp, 0) as xp, 
        COALESCE(level, 1) as level,
        created_at
    FROM users 
    WHERE id = ?
");
$stmt->execute([$userId]);
$user = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$user) {
    http_response_code(404);
    echo json_encode(['error' => 'User not found']);
    exit;
}

// Calculate betting stats
$stmt = $pdo->prepare("
    SELECT 
        COUNT(*) as total_bets,
        COALESCE(SUM(notional), 0) as total_volume,
        COUNT(DISTINCT event_id) as events_bet_on
    FROM bets 
    WHERE user_id = ?
");
$stmt->execute([$userId]);
$betStats = $stmt->fetch(PDO::FETCH_ASSOC);

// Calculate win/loss stats
$stmt = $pdo->prepare("
    SELECT 
        COUNT(CASE WHEN (b.side = 'YES' AND e.winning_side = 'YES') OR (b.side = 'NO' AND e.winning_side = 'NO') THEN 1 END) as wins,
        COUNT(CASE WHEN (b.side = 'YES' AND e.winning_side = 'NO') OR (b.side = 'NO' AND e.winning_side = 'YES') THEN 1 END) as losses,
        COUNT(CASE WHEN e.status = 'resolved' THEN 1 END) as resolved
    FROM bets b
    JOIN events e ON b.event_id = e.id
    WHERE b.user_id = ?
");
$stmt->execute([$userId]);
$winLossStats = $stmt->fetch(PDO::FETCH_ASSOC);

$wins = (int) $winLossStats['wins'];
$losses = (int) $winLossStats['losses'];
$resolved = (int) $winLossStats['resolved'];
$accuracy = $resolved > 0 ? round(($wins / $resolved) * 100, 1) : 0;

// Calculate P&L
$stmt = $pdo->prepare("
    SELECT 
        COALESCE(SUM(
            CASE 
                WHEN e.status = 'resolved' AND ((b.side = 'YES' AND e.winning_side = 'YES') OR (b.side = 'NO' AND e.winning_side = 'NO'))
                THEN (100 / b.price - 1) * b.notional
                WHEN e.status = 'resolved' 
                THEN -b.notional
                ELSE 0
            END
        ), 0) as realized_pnl
    FROM bets b
    JOIN events e ON b.event_id = e.id
    WHERE b.user_id = ?
");
$stmt->execute([$userId]);
$realizedPnl = (float) $stmt->fetchColumn();

// Get streak data
$stmt = $pdo->prepare("SELECT * FROM user_streaks WHERE user_id = ?");
$stmt->execute([$userId]);
$streak = $stmt->fetch(PDO::FETCH_ASSOC);

// Count markets
$stmt = $pdo->prepare("SELECT COUNT(*) FROM market_members WHERE user_id = ?");
$stmt->execute([$userId]);
$marketsJoined = (int) $stmt->fetchColumn();

// Count events created
$stmt = $pdo->prepare("SELECT COUNT(*) FROM events WHERE creator_id = ?");
$stmt->execute([$userId]);
$eventsCreated = (int) $stmt->fetchColumn();

// Count friends
$stmt = $pdo->prepare("
    SELECT COUNT(*) FROM friendships 
    WHERE (user_id = ? OR friend_id = ?) AND status = 'accepted'
");
$stmt->execute([$userId, $userId]);
$friendsCount = (int) $stmt->fetchColumn();

// Count gossip messages
$stmt = $pdo->prepare("SELECT COUNT(*) FROM gossip WHERE user_id = ?");
$stmt->execute([$userId]);
$gossipCount = (int) $stmt->fetchColumn();

// Get XP and level info
$xp = (int) $user['xp'];
$level = (int) $user['level'];
$xpForNextLevel = $level * 500;
$xpProgress = $xpForNextLevel > 0 ? min($xp / $xpForNextLevel, 1) : 0;

$levelTitles = [
    1 => 'Novice Trader',
    5 => 'Market Watcher',
    10 => 'Odds Master',
    20 => 'Prediction Pro',
    30 => 'Oracle',
    50 => 'Market Sage',
    75 => 'Legend',
    100 => 'Tyches God'
];

$levelTitle = 'Novice Trader';
foreach ($levelTitles as $lvl => $title) {
    if ($level >= $lvl) {
        $levelTitle = $title;
    }
}

echo json_encode([
    'user' => [
        'id' => (int) $user['id'],
        'name' => $user['name'],
        'username' => $user['username'],
        'tokens_balance' => (float) $user['tokens_balance'],
        'created_at' => $user['created_at']
    ],
    'level' => [
        'current' => $level,
        'title' => $levelTitle,
        'xp' => $xp,
        'xp_for_next' => $xpForNextLevel,
        'progress' => round($xpProgress, 2)
    ],
    'streak' => [
        'current' => (int) ($streak['current_streak'] ?? 0),
        'longest' => (int) ($streak['longest_streak'] ?? 0),
        'total_days' => (int) ($streak['total_days_active'] ?? 0),
        'weekly_activity' => json_decode($streak['weekly_activity'] ?? '[]', true) ?: array_fill(0, 7, false)
    ],
    'trading' => [
        'total_bets' => (int) $betStats['total_bets'],
        'total_volume' => (float) $betStats['total_volume'],
        'events_bet_on' => (int) $betStats['events_bet_on'],
        'wins' => $wins,
        'losses' => $losses,
        'accuracy' => $accuracy,
        'realized_pnl' => round($realizedPnl, 2)
    ],
    'social' => [
        'markets_joined' => $marketsJoined,
        'events_created' => $eventsCreated,
        'friends_count' => $friendsCount,
        'gossip_count' => $gossipCount
    ]
]);


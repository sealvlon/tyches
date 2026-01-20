<?php
/**
 * Leaderboard API
 * GET: Fetch leaderboard with various sorting options
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

$userId = (int) $_SESSION['user_id'];
$method = $_SERVER['REQUEST_METHOD'];

if ($method !== 'GET') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

// Initialize database connection
try {
    $pdo = get_pdo();
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database connection failed']);
    exit;
}

$type = $_GET['type'] ?? 'tokens'; // tokens, accuracy, streak, xp
$scope = $_GET['scope'] ?? 'global'; // global, friends, market
$marketId = isset($_GET['market_id']) ? (int) $_GET['market_id'] : null;
$limit = min((int) ($_GET['limit'] ?? 20), 100);

$leaderboard = [];

try {
    switch ($type) {
        case 'tokens':
            $leaderboard = getTokensLeaderboard($pdo, $userId, $scope, $marketId, $limit);
            break;
        case 'accuracy':
            $leaderboard = getAccuracyLeaderboard($pdo, $userId, $scope, $marketId, $limit);
            break;
        case 'streak':
            $leaderboard = getStreakLeaderboard($pdo, $userId, $scope, $limit);
            break;
        case 'xp':
            $leaderboard = getXPLeaderboard($pdo, $userId, $scope, $limit);
            break;
        default:
            $leaderboard = getTokensLeaderboard($pdo, $userId, $scope, $marketId, $limit);
    }

    // Find current user's position
    $userPosition = null;
    foreach ($leaderboard as $i => $entry) {
        if ($entry['user_id'] === $userId) {
            $userPosition = $i + 1;
            break;
        }
    }

    echo json_encode([
        'leaderboard' => $leaderboard,
        'type' => $type,
        'scope' => $scope,
        'user_position' => $userPosition,
        'total_entries' => count($leaderboard)
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database error: ' . $e->getMessage()]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Leaderboard error: ' . $e->getMessage()]);
}

// Helper functions
function getTokensLeaderboard(PDO $pdo, int $userId, string $scope, ?int $marketId, int $limit): array {
    $whereClause = '';
    $params = [];
    
    if ($scope === 'friends') {
        // Use the 'friendships' table (consistent with user-stats.php)
        $whereClause = "AND (u.id IN (
            SELECT friend_id FROM friendships WHERE user_id = ? AND status = 'accepted'
            UNION
            SELECT user_id FROM friendships WHERE friend_id = ? AND status = 'accepted'
        ) OR u.id = ?)";
        $params = [$userId, $userId, $userId];
    } elseif ($scope === 'market' && $marketId) {
        $whereClause = "AND u.id IN (SELECT user_id FROM market_members WHERE market_id = ?)";
        $params = [$marketId];
    }
    
    // Include accuracy calculation in the main query
    $sql = "
        SELECT 
            u.id as user_id,
            u.name as user_name,
            u.username,
            u.tokens_balance as score,
            (SELECT COUNT(*) FROM bets WHERE user_id = u.id) as total_bets,
            (SELECT COUNT(*) FROM bets b 
             INNER JOIN events e ON b.event_id = e.id 
             WHERE b.user_id = u.id AND e.status = 'resolved'
            ) as resolved_bets,
            (SELECT COUNT(*) FROM bets b 
             INNER JOIN events e ON b.event_id = e.id 
             WHERE b.user_id = u.id 
               AND e.status = 'resolved'
               AND ((b.side = 'YES' AND e.winning_side = 'YES') OR (b.side = 'NO' AND e.winning_side = 'NO'))
            ) as winning_bets
        FROM users u
        WHERE u.status = 'active' {$whereClause}
        ORDER BY u.tokens_balance DESC
        LIMIT {$limit}
    ";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    return array_map(function($row, $index) {
        $resolvedBets = (int) ($row['resolved_bets'] ?? 0);
        $winningBets = (int) ($row['winning_bets'] ?? 0);
        $accuracy = $resolvedBets > 0 ? round(($winningBets / $resolvedBets) * 100) : 0;
        
        return [
            'rank' => $index + 1,
            'user_id' => (int) $row['user_id'],
            'name' => $row['user_name'] ?? '',
            'username' => $row['username'],
            'tokens_balance' => (float) $row['score'],
            'accuracy' => $accuracy,
            'total_bets' => (int) ($row['total_bets'] ?? 0)
        ];
    }, $results, array_keys($results));
}

function getAccuracyLeaderboard(PDO $pdo, int $userId, string $scope, ?int $marketId, int $limit): array {
    $whereClause = '';
    $params = [];
    
    if ($scope === 'friends') {
        // Use the 'friendships' table (consistent with user-stats.php)
        $whereClause = "AND (u.id IN (
            SELECT friend_id FROM friendships WHERE user_id = ? AND status = 'accepted'
            UNION
            SELECT user_id FROM friendships WHERE friend_id = ? AND status = 'accepted'
        ) OR u.id = ?)";
        $params = [$userId, $userId, $userId];
    } elseif ($scope === 'market' && $marketId) {
        $whereClause = "AND u.id IN (SELECT user_id FROM market_members WHERE market_id = ?)";
        $params = [$marketId];
    }
    
    $sql = "
        SELECT 
            u.id as user_id,
            u.name as user_name,
            u.username,
            u.tokens_balance,
            COUNT(CASE WHEN (b.side = 'YES' AND e.winning_side = 'YES') OR (b.side = 'NO' AND e.winning_side = 'NO') THEN 1 END) as wins,
            COUNT(CASE WHEN e.status = 'resolved' THEN 1 END) as total_resolved,
            CASE 
                WHEN COUNT(CASE WHEN e.status = 'resolved' THEN 1 END) >= 1 
                THEN ROUND(100.0 * COUNT(CASE WHEN (b.side = 'YES' AND e.winning_side = 'YES') OR (b.side = 'NO' AND e.winning_side = 'NO') THEN 1 END) / COUNT(CASE WHEN e.status = 'resolved' THEN 1 END), 1)
                ELSE 0 
            END as accuracy
        FROM users u
        LEFT JOIN bets b ON u.id = b.user_id
        LEFT JOIN events e ON b.event_id = e.id
        WHERE u.status = 'active' {$whereClause}
        GROUP BY u.id, u.name, u.username, u.tokens_balance
        ORDER BY accuracy DESC, total_resolved DESC
        LIMIT {$limit}
    ";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    return array_map(function($row, $index) {
        return [
            'rank' => $index + 1,
            'user_id' => (int) $row['user_id'],
            'name' => $row['user_name'] ?? '',
            'username' => $row['username'],
            'tokens_balance' => (float) $row['tokens_balance'],
            'accuracy' => (float) $row['accuracy'],
            'wins' => (int) $row['wins'],
            'total_resolved' => (int) $row['total_resolved']
        ];
    }, $results, array_keys($results));
}

function getStreakLeaderboard(PDO $pdo, int $userId, string $scope, int $limit): array {
    // Simplified - just return tokens leaderboard for now since streaks table doesn't exist
    return getTokensLeaderboard($pdo, $userId, $scope, null, $limit);
}

function getXPLeaderboard(PDO $pdo, int $userId, string $scope, int $limit): array {
    // Simplified - just return tokens leaderboard for now since XP isn't implemented
    return getTokensLeaderboard($pdo, $userId, $scope, null, $limit);
}

<?php
/**
 * search.php
 * Global search API - searches markets, events, and users
 * 
 * GET /api/search.php?q=query
 * Returns matching markets, events, and users the current user has access to
 */

declare(strict_types=1);

require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/config.php';

tyches_start_session();

// Only logged-in users can search
if (!isset($_SESSION['user_id'])) {
    json_response(['error' => 'Unauthorized'], 401);
}

$userId = (int)$_SESSION['user_id'];
$query = trim($_GET['q'] ?? '');

if (strlen($query) < 2) {
    json_response([
        'markets' => [],
        'events' => [],
        'users' => [],
    ]);
}

try {
    $pdo = get_pdo();
    $searchPattern = '%' . $query . '%';
    
    $markets = [];
    $events = [];
    $users = [];

    // Search markets the user is a member of
    $marketsStmt = $pdo->prepare("
        SELECT DISTINCT m.id, m.name, m.description, m.avatar_emoji, m.avatar_color,
               (SELECT COUNT(*) FROM market_members WHERE market_id = m.id) as members_count,
               (SELECT COUNT(*) FROM events WHERE market_id = m.id) as events_count
        FROM markets m
        JOIN market_members mm ON m.id = mm.market_id
        WHERE mm.user_id = ?
          AND (m.name LIKE ? OR m.description LIKE ?)
        ORDER BY m.name ASC
        LIMIT 5
    ");
    $marketsStmt->execute([$userId, $searchPattern, $searchPattern]);
    $markets = $marketsStmt->fetchAll(PDO::FETCH_ASSOC) ?: [];

    // Search events in markets the user is a member of
    $eventsStmt = $pdo->prepare("
        SELECT DISTINCT e.id, e.title, e.description, e.status, e.closes_at,
               e.yes_percent, e.volume,
               m.id as market_id, m.name as market_name, m.avatar_emoji as market_emoji
        FROM events e
        JOIN markets m ON e.market_id = m.id
        JOIN market_members mm ON m.id = mm.market_id
        WHERE mm.user_id = ?
          AND (e.title LIKE ? OR e.description LIKE ?)
        ORDER BY e.closes_at DESC
        LIMIT 8
    ");
    $eventsStmt->execute([$userId, $searchPattern, $searchPattern]);
    $events = $eventsStmt->fetchAll(PDO::FETCH_ASSOC) ?: [];

    // Set default yes_percent if null
    foreach ($events as &$event) {
        $event['yes_percent'] = $event['yes_percent'] ?? 50;
    }
    unset($event);

    // Search users who share a market with the current user
    $usersStmt = $pdo->prepare("
        SELECT DISTINCT u.id, u.username, u.name, u.tokens_balance
        FROM users u
        JOIN market_members mm1 ON u.id = mm1.user_id
        JOIN market_members mm2 ON mm1.market_id = mm2.market_id
        WHERE mm2.user_id = ?
          AND u.id != ?
          AND (u.username LIKE ? OR u.name LIKE ? OR u.email LIKE ?)
        ORDER BY u.name ASC
        LIMIT 5
    ");
    $usersStmt->execute([$userId, $userId, $searchPattern, $searchPattern, $searchPattern]);
    $users = $usersStmt->fetchAll(PDO::FETCH_ASSOC) ?: [];

    // Sanitize user data (remove sensitive fields)
    $users = array_map(function($user) {
        return [
            'id' => $user['id'],
            'username' => $user['username'],
            'name' => $user['name'],
            'tokens_balance' => $user['tokens_balance'],
        ];
    }, $users);

    json_response([
        'markets' => $markets,
        'events' => $events,
        'users' => $users,
        'query' => $query,
    ]);
    
} catch (PDOException $e) {
    json_response(['error' => 'Database error: ' . $e->getMessage()], 500);
} catch (Exception $e) {
    json_response(['error' => 'Search failed: ' . $e->getMessage()], 500);
}


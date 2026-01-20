<?php
// api/friends.php
// Friend search and relationship management.

declare(strict_types=1);

require_once __DIR__ . '/security.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

try {
    if ($method === 'GET') {
        handle_get_friends();
    } elseif ($method === 'POST') {
        handle_mutate_friends();
    } else {
        json_response(['error' => 'Method not allowed'], 405);
    }
} catch (Throwable $e) {
    error_log('[Tyches] friends.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    json_response(['error' => 'Server error: ' . $e->getMessage()], 500);
}

/**
 * GET /api/friends.php
 * Returns current friends, pending requests, and optionally search results.
 */
function handle_get_friends(): void {
    $uid = require_auth();
    $pdo = get_pdo();

    $query = sanitize_string($_GET['q'] ?? '', 64);

    // Friends and requests
    //
    // Similar to api/profile.php, some PDO/MySQL setups do not allow the same
    // named parameter to be reused multiple times in a prepared statement.
    // Use distinct names for each :uid occurrence to avoid HY093 errors.
    $stmt = $pdo->prepare(
        'SELECT
             f.id,
             f.user_id,
             f.friend_user_id,
             f.status,
             f.requester_id,
             f.created_at,
             u.id   AS other_id,
             u.name AS other_name,
             u.username AS other_username
         FROM friends f
         INNER JOIN users u
           ON u.id = CASE WHEN f.user_id = :uid1 THEN f.friend_user_id ELSE f.user_id END
         WHERE (f.user_id = :uid2 OR f.friend_user_id = :uid3)
           AND f.status IN ("pending", "accepted")'
    );
    $stmt->execute([
        ':uid1' => $uid,
        ':uid2' => $uid,
        ':uid3' => $uid,
    ]);
    $rows = $stmt->fetchAll() ?: [];

    $friends = [];
    foreach ($rows as $row) {
        $requesterId = isset($row['requester_id']) ? (int)$row['requester_id'] : 0;
        $friends[] = [
            'id'          => (int)$row['id'],
            'user_id'     => $uid,
            'friend_id'   => (int)$row['other_id'],
            'name'        => $row['other_name'],
            'username'    => $row['other_username'],
            'status'      => $row['status'],
            'requester_id'=> $requesterId,
            // For pending requests: did I send it, or did I receive it?
            'is_incoming' => $row['status'] === 'pending' && $requesterId !== $uid,
            'created_at'  => $row['created_at'],
        ];
    }

    $searchResults = [];
    if ($query !== '') {
        // Use distinct parameter names for the LIKE clauses to avoid HY093 on some PDO setups.
        $stmtSearch = $pdo->prepare(
            'SELECT id, name, username, email, created_at
             FROM users
             WHERE (username LIKE :q1 OR email LIKE :q2 OR name LIKE :q3)
               AND id <> :uid
             ORDER BY created_at DESC
             LIMIT 10'
        );
        $like = '%' . $query . '%';
        $stmtSearch->execute([
            ':q1'  => $like,
            ':q2'  => $like,
            ':q3'  => $like,
            ':uid' => $uid,
        ]);
        $searchResults = $stmtSearch->fetchAll() ?: [];
    }

    // Get suggested friends (people in same markets/events who aren't friends)
    $suggested = get_suggested_friends($pdo, $uid, $friends);

    json_response([
        'friends'   => $friends,
        'search'    => $searchResults,
        'suggested' => $suggested,
    ]);
}

/**
 * Get suggested friends based on shared markets/events
 * Returns empty array on any error to not break the main API
 */
function get_suggested_friends(PDO $pdo, int $uid, array $existingFriends): array {
    try {
        // Get IDs of existing friends to exclude
        $friendIds = array_map(fn($f) => $f['friend_id'], $existingFriends);
        $friendIds[] = $uid; // Also exclude self
        
        $suggested = [];
        
        // Try to find users who share markets with the current user
        // This is a simpler query that's less likely to fail
        try {
            $stmt = $pdo->prepare(
                'SELECT DISTINCT u.id, u.name, u.username
                 FROM users u
                 INNER JOIN market_members mm2 ON mm2.user_id = u.id
                 INNER JOIN market_members mm1 ON mm1.market_id = mm2.market_id AND mm1.user_id = :uid
                 WHERE u.id <> :uid2
                 LIMIT 10'
            );
            $stmt->execute([':uid' => $uid, ':uid2' => $uid]);
            $candidates = $stmt->fetchAll() ?: [];
            
            foreach ($candidates as $user) {
                if (!in_array((int)$user['id'], $friendIds, true)) {
                    $suggested[] = [
                        'id'             => (int)$user['id'],
                        'name'           => $user['name'],
                        'username'       => $user['username'],
                        'shared_markets' => 1,
                        'shared_events'  => 0,
                        'reason'         => 'In your markets',
                    ];
                }
                if (count($suggested) >= 5) break;
            }
        } catch (Throwable $e) {
            // market_members table might not exist, continue
            error_log('[Tyches] Suggested friends (markets) error: ' . $e->getMessage());
        }
        
        // If we don't have enough suggestions, add some recent users
        if (count($suggested) < 5) {
            $existingIds = array_merge($friendIds, array_map(fn($s) => $s['id'], $suggested));
            
            if (empty($existingIds)) {
                $existingIds = [0]; // Prevent empty IN clause
            }
            
            $placeholders = implode(',', array_fill(0, count($existingIds), '?'));
            
            $stmtRecent = $pdo->prepare(
                "SELECT u.id, u.name, u.username
                 FROM users u
                 WHERE u.id NOT IN ({$placeholders})
                 ORDER BY u.created_at DESC
                 LIMIT " . (5 - count($suggested))
            );
            $stmtRecent->execute($existingIds);
            $recentUsers = $stmtRecent->fetchAll() ?: [];
            
            foreach ($recentUsers as $user) {
                $suggested[] = [
                    'id'             => (int)$user['id'],
                    'name'           => $user['name'],
                    'username'       => $user['username'],
                    'shared_markets' => 0,
                    'shared_events'  => 0,
                    'reason'         => 'New to Tyches',
                ];
            }
        }
        
        return $suggested;
    } catch (Throwable $e) {
        error_log('[Tyches] get_suggested_friends error: ' . $e->getMessage());
        return []; // Return empty array on any error
    }
}

/**
 * Build a human-readable reason for friend suggestion
 */
function build_suggestion_reason(int $markets, int $events): string {
    $parts = [];
    if ($markets > 0) {
        $parts[] = $markets . ' shared market' . ($markets > 1 ? 's' : '');
    }
    if ($events > 0) {
        $parts[] = $events . ' shared event' . ($events > 1 ? 's' : '');
    }
    return !empty($parts) ? implode(', ', $parts) : 'Suggested for you';
}

/**
 * POST /api/friends.php
 * action = send_request | accept | decline | unfriend
 */
function handle_mutate_friends(): void {
    $uid = require_auth();
    $pdo = get_pdo();

    // CSRF protection for friend mutations
    tyches_require_csrf();

    $raw  = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        $data = $_POST;
    }

    $action  = sanitize_string($data['action'] ?? '', 32);
    $targetId= isset($data['user_id']) ? (int)$data['user_id'] : 0;
    $byQuery = sanitize_string($data['query'] ?? '', 128);

    if ($action === 'send_request') {
        if ($targetId <= 0 && $byQuery === '') {
            json_response(['error' => 'user_id or query is required to send request'], 400);
        }

        if ($targetId <= 0) {
            // Find by username/email
            $stmtFind = $pdo->prepare(
                'SELECT id FROM users WHERE username = :q OR email = :q LIMIT 1'
            );
            $stmtFind->execute([':q' => $byQuery]);
            $u = $stmtFind->fetch();
            if (!$u) {
                json_response(['error' => 'User not found'], 404);
            }
            $targetId = (int)$u['id'];
        }

        if ($targetId === $uid) {
            json_response(['error' => 'You cannot friend yourself'], 400);
        }

        // Normalize pair ordering for friends table (user_id < friend_user_id)
        $u1 = min($uid, $targetId);
        $u2 = max($uid, $targetId);

        // Check if relationship already exists
        $checkStmt = $pdo->prepare(
            'SELECT id, status, requester_id FROM friends WHERE user_id = :u1 AND friend_user_id = :u2 LIMIT 1'
        );
        $checkStmt->execute([':u1' => $u1, ':u2' => $u2]);
        $existing = $checkStmt->fetch();

        if ($existing) {
            if ($existing['status'] === 'accepted') {
                json_response(['error' => 'You are already friends'], 400);
            }
            if ($existing['status'] === 'pending') {
                // If I'm the recipient of their pending request, auto-accept instead
                if ((int)$existing['requester_id'] === $targetId) {
                    $updateStmt = $pdo->prepare(
                        'UPDATE friends SET status = "accepted" WHERE id = :id'
                    );
                    $updateStmt->execute([':id' => $existing['id']]);
                    json_response(['ok' => true, 'auto_accepted' => true]);
                    return;
                }
                // I already sent a request, nothing to do
                json_response(['error' => 'Friend request already sent'], 400);
            }
        }

        // Insert new friend request with requester_id to track who initiated
        $stmt = $pdo->prepare(
            'INSERT INTO friends (user_id, friend_user_id, status, requester_id)
             VALUES (:u1, :u2, "pending", :requester)
             ON DUPLICATE KEY UPDATE status = "pending", requester_id = :requester2'
        );
        $stmt->execute([':u1' => $u1, ':u2' => $u2, ':requester' => $uid, ':requester2' => $uid]);

        json_response(['ok' => true]);
        return;
    }

    if (!in_array($action, ['accept', 'decline', 'unfriend'], true) || $targetId <= 0) {
        json_response(['error' => 'Invalid action or user_id'], 400);
    }

    $u1 = min($uid, $targetId);
    $u2 = max($uid, $targetId);

    if ($action === 'unfriend') {
        $stmt = $pdo->prepare(
            'DELETE FROM friends WHERE user_id = :u1 AND friend_user_id = :u2'
        );
        $stmt->execute([':u1' => $u1, ':u2' => $u2]);
        json_response(['ok' => true]);
        return;
    }

    // accept / decline - MUST verify current user is the RECIPIENT, not the sender
    $checkStmt = $pdo->prepare(
        'SELECT id, status, requester_id FROM friends 
         WHERE user_id = :u1 AND friend_user_id = :u2 AND status = "pending"
         LIMIT 1'
    );
    $checkStmt->execute([':u1' => $u1, ':u2' => $u2]);
    $friendRow = $checkStmt->fetch();

    if (!$friendRow) {
        json_response(['error' => 'No pending friend request found'], 404);
    }

    // The requester_id is the person who sent the request.
    // Only the OTHER person (the recipient) can accept or decline.
    $requesterId = $friendRow['requester_id'] !== null ? (int)$friendRow['requester_id'] : null;
    
    // If requester_id is NULL (legacy data before this fix), allow either party to accept
    // This is a fallback for old pending requests that don't have requester tracking
    if ($requesterId !== null && $requesterId === $uid) {
        json_response(['error' => 'You cannot accept your own friend request'], 403);
    }

    $newStatus = $action === 'accept' ? 'accepted' : 'declined';
    $stmt = $pdo->prepare(
        'UPDATE friends
         SET status = :status
         WHERE id = :id'
    );
    $stmt->execute([':status' => $newStatus, ':id' => $friendRow['id']]);

    json_response(['ok' => true]);
}





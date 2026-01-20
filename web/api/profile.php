<?php
// api/profile.php
// Profile data for the currently authenticated user.

declare(strict_types=1);

require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/security.php';
require_once __DIR__ . '/mailer.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

try {
    if ($method === 'GET') {
        handle_profile();
    } elseif ($method === 'POST') {
        handle_profile_action();
    } else {
        json_response(['error' => 'Method not allowed'], 405);
    }
} catch (Throwable $e) {
    error_log('profile.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    json_response(['error' => 'Server error'], 500);
}

/**
 * POST /api/profile.php
 * Handle profile actions like resending verification email
 */
function handle_profile_action(): void {
    $uid = require_auth();
    $pdo = get_pdo();
    
    tyches_require_csrf();
    
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        $data = $_POST;
    }
    
    $action = $data['action'] ?? '';
    
    if ($action === 'resend_verification') {
        // Rate limit: 3 resends per hour
        $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
        tyches_require_rate_limit('resend_verify:' . $uid, 3, 3600);
        
        // Get user details
        $stmt = $pdo->prepare('SELECT email, name, email_verified_at, verification_token FROM users WHERE id = :id');
        $stmt->execute([':id' => $uid]);
        $user = $stmt->fetch();
        
        if (!$user) {
            json_response(['error' => 'User not found'], 404);
        }
        
        if ($user['email_verified_at'] !== null) {
            json_response(['error' => 'Email is already verified'], 400);
        }
        
        // Generate new token if needed
        $token = $user['verification_token'];
        if (empty($token)) {
            $token = bin2hex(random_bytes(32));
            $stmtUpdate = $pdo->prepare('UPDATE users SET verification_token = :token WHERE id = :id');
            $stmtUpdate->execute([':token' => $token, ':id' => $uid]);
        }
        
        // Send verification email
        send_verification_email($user['email'], $user['name'], $token);
        
        json_response(['ok' => true, 'message' => 'Verification email sent']);
    } else {
        json_response(['error' => 'Unknown action'], 400);
    }
}

function handle_profile(): void {
    $uid = require_auth();
    $pdo = get_pdo();

    $user = fetch_current_user($pdo);
    if (!$user) {
        json_response(['error' => 'User not found'], 404);
    }

    // Friends: accepted + pending
    //
    // Note: Some PDO drivers (including MySQL when emulate_prepares is disabled)
    // do not allow the same named parameter to be reused multiple times in a
    // statement. To avoid "SQLSTATE[HY093]: Invalid parameter number" on the
    // live host, we use distinct parameter names for each occurrence of :uid.
    $stmtFriends = $pdo->prepare(
        'SELECT
             CASE WHEN f.user_id = :uid1 THEN f.friend_user_id ELSE f.user_id END AS friend_id,
             f.status,
             u.name,
             u.username,
             u.created_at
         FROM friends f
         INNER JOIN users u
           ON u.id = CASE WHEN f.user_id = :uid2 THEN f.friend_user_id ELSE f.user_id END
         WHERE f.user_id = :uid3 OR f.friend_user_id = :uid4'
    );
    $stmtFriends->execute([
        ':uid1' => $uid,
        ':uid2' => $uid,
        ':uid3' => $uid,
        ':uid4' => $uid,
    ]);
    $friendsRows = $stmtFriends->fetchAll() ?: [];

    $friends = [];
    foreach ($friendsRows as $row) {
        $friends[] = [
            'id'        => (int)$row['friend_id'],
            'name'      => $row['name'],
            'username'  => $row['username'],
            'status'    => $row['status'],
            'created_at'=> $row['created_at'],
        ];
    }

    // Markets the user owns or is a member of
    $stmtMarkets = $pdo->prepare(
        'SELECT m.*, mm.role,
                (SELECT COUNT(*) FROM market_members mm2 WHERE mm2.market_id = m.id) AS members_count,
                (SELECT COUNT(*) FROM events e WHERE e.market_id = m.id) AS events_count
         FROM market_members mm
         INNER JOIN markets m ON m.id = mm.market_id
         WHERE mm.user_id = :uid
         ORDER BY m.created_at DESC'
    );
    $stmtMarkets->execute([':uid' => $uid]);
    $marketsRows = $stmtMarkets->fetchAll() ?: [];

    $markets = [];
    foreach ($marketsRows as $row) {
        $markets[] = [
            'id'            => (int)$row['id'],
            'name'          => $row['name'],
            'description'   => $row['description'],
            'visibility'    => $row['visibility'],
            'avatar_emoji'  => $row['avatar_emoji'],
            'avatar_color'  => $row['avatar_color'],
            'role'          => $row['role'],
            'members_count' => (int)$row['members_count'],
            'events_count'  => (int)$row['events_count'],
            'created_at'    => $row['created_at'],
        ];
    }

    // Events created by the user
    $stmtEvents = $pdo->prepare(
        'SELECT e.*, m.name AS market_name
         FROM events e
         INNER JOIN markets m ON m.id = e.market_id
         WHERE e.creator_id = :uid
         ORDER BY e.created_at DESC
         LIMIT 20'
    );
    $stmtEvents->execute([':uid' => $uid]);
    $eventsRows = $stmtEvents->fetchAll() ?: [];

    $eventsCreated = [];
    foreach ($eventsRows as $row) {
        $eventsCreated[] = [
            'id'            => (int)$row['id'],
            'market_id'     => (int)$row['market_id'],
            'market_name'   => $row['market_name'],
            'title'         => $row['title'],
            'event_type'    => $row['event_type'],
            'status'        => $row['status'],
            'closes_at'     => $row['closes_at'],
            'created_at'    => $row['created_at'],
            'volume'        => (float)$row['volume'],
            'traders_count' => (int)$row['traders_count'],
        ];
    }

    // Recent bets placed by the user
    $stmtBets = $pdo->prepare(
        'SELECT b.*, e.title, e.event_type, m.name AS market_name
         FROM bets b
         INNER JOIN events e ON e.id = b.event_id
         INNER JOIN markets m ON m.id = e.market_id
         WHERE b.user_id = :uid
         ORDER BY b.created_at DESC
         LIMIT 30'
    );
    $stmtBets->execute([':uid' => $uid]);
    $betsRows = $stmtBets->fetchAll() ?: [];

    $bets = [];
    foreach ($betsRows as $row) {
        $bets[] = [
            'id'           => (int)$row['id'],
            'event_id'     => (int)$row['event_id'],
            'event_title'  => $row['title'],
            'event_type'   => $row['event_type'],
            'market_name'  => $row['market_name'],
            'side'         => $row['side'],
            'outcome_id'   => $row['outcome_id'],
            'shares'       => (int)$row['shares'],
            'price'        => (int)$row['price'],
            'notional'     => (float)$row['notional'],
            'created_at'   => $row['created_at'],
        ];
    }

    // Add is_verified flag for convenience
    $user['is_verified'] = $user['email_verified_at'] !== null;
    
    // Calculate total wins - count distinct events where user bet on winning side/outcome
    $stmtWins = $pdo->prepare(
        'SELECT COUNT(DISTINCT b.event_id) AS total_wins
         FROM bets b
         INNER JOIN events e ON e.id = b.event_id
         WHERE b.user_id = :uid
           AND e.status = "resolved"
           AND (
               (e.event_type = "binary" AND b.side = e.winning_side)
               OR
               (e.event_type != "binary" AND b.outcome_id = e.winning_outcome_id)
           )'
    );
    $stmtWins->execute([':uid' => $uid]);
    $winsResult = $stmtWins->fetch();
    $user['total_wins'] = (int)($winsResult['total_wins'] ?? 0);
    
    json_response([
        'user'           => $user,
        'friends'        => $friends,
        'markets'        => $markets,
        'events_created' => $eventsCreated,
        'bets'           => $bets,
    ]);
}





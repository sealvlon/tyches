<?php
// api/markets.php
// CRUD-style API for Markets (friend groups).

declare(strict_types=1);

require_once __DIR__ . '/security.php';
require_once __DIR__ . '/mailer.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

// Store raw input for POST requests (can only be read once)
$GLOBALS['tyches_raw_input'] = null;
if ($method === 'POST') {
    $GLOBALS['tyches_raw_input'] = file_get_contents('php://input');
}

try {
    if ($method === 'GET') {
        handle_get_markets();
    } elseif ($method === 'POST') {
        // Check if this is an invite action
        $data = json_decode($GLOBALS['tyches_raw_input'], true);
        if (is_array($data) && isset($data['action']) && $data['action'] === 'invite') {
            handle_invite_to_market($data);
        } else {
            handle_create_market($data);
        }
    } else {
        json_response(['error' => 'Method not allowed'], 405);
    }
} catch (Throwable $e) {
    error_log('markets.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    json_response(['error' => 'Server error: ' . $e->getMessage()], 500);
}

/**
 * GET /api/markets.php
 *  - no params: list markets for current user
 *  - ?id=123: get single market with members + recent events
 */
function handle_get_markets(): void {
    $uid = require_auth();
    $pdo = get_pdo();

    $id = isset($_GET['id']) ? (int)$_GET['id'] : 0;

    if ($id > 0) {
        // Verify membership and get user's role
        $stmt = $pdo->prepare(
            'SELECT m.*, mm.role AS user_role
             FROM markets m
             INNER JOIN market_members mm ON mm.market_id = m.id
             WHERE m.id = :id AND mm.user_id = :uid
             LIMIT 1'
        );
        $stmt->execute([':id' => $id, ':uid' => $uid]);
        $market = $stmt->fetch();
        if (!$market) {
            json_response(['error' => 'Market not found'], 404);
        }
        
        // Check if user can invite (owner only)
        $isOwner = (int)$market['owner_id'] === $uid;
        $userRole = $market['user_role'];

        // Members
        $stmtMembers = $pdo->prepare(
            'SELECT u.id, u.name, u.username, mm.role, u.created_at
             FROM market_members mm
             INNER JOIN users u ON u.id = mm.user_id
             WHERE mm.market_id = :mid
             ORDER BY mm.role DESC, u.name ASC'
        );
        $stmtMembers->execute([':mid' => $id]);
        $members = $stmtMembers->fetchAll() ?: [];

        // Recent events (filter private events user can't access)
        $stmtEvents = $pdo->prepare(
            'SELECT e.*, u.name AS creator_name, u.username AS creator_username
             FROM events e
             INNER JOIN users u ON u.id = e.creator_id
             WHERE e.market_id = :mid
             ORDER BY e.created_at DESC
             LIMIT 50'
        );
        $stmtEvents->execute([':mid' => $id]);
        $events = [];
        foreach ($stmtEvents->fetchAll() ?: [] as $row) {
            // Filter private events - only show if user has access
            $visibility = $row['visibility'] ?? 'public';
            if ($visibility === 'private') {
                $isCreator = (int)$row['creator_id'] === $uid;
                $isResolver = isset($row['resolver_id']) && (int)$row['resolver_id'] === $uid;
                if (!$isCreator && !$isResolver && !canUserAccessEvent($pdo, (int)$row['id'], $uid)) {
                    continue; // Skip this private event
                }
            }
            $events[] = normalize_event_row($row);
        }

        json_response([
            'market'  => [
                'id'           => (int)$market['id'],
                'name'         => $market['name'],
                'description'  => $market['description'],
                'visibility'   => $market['visibility'],
                'avatar_emoji' => $market['avatar_emoji'],
                'avatar_color' => $market['avatar_color'],
                'owner_id'     => (int)$market['owner_id'],
                'created_at'   => $market['created_at'],
                'is_owner'     => $isOwner,
                'can_invite'   => $isOwner, // Only owners can invite for now
                'user_role'    => $userRole,
            ],
            'members' => $members,
            'events'  => $events,
        ]);
        return;
    }

    // List all markets current user belongs to
    $stmt = $pdo->prepare(
        'SELECT m.*, 
                COUNT(DISTINCT mm2.id) AS members_count,
                (SELECT COUNT(*) FROM events e WHERE e.market_id = m.id) AS events_count
         FROM markets m
         INNER JOIN market_members mm ON mm.market_id = m.id AND mm.user_id = :uid
         LEFT JOIN market_members mm2 ON mm2.market_id = m.id
         GROUP BY m.id
         ORDER BY m.created_at DESC
         LIMIT 50'
    );
    $stmt->execute([':uid' => $uid]);
    $rows = $stmt->fetchAll() ?: [];

    $markets = [];
    foreach ($rows as $row) {
        $markets[] = [
            'id'            => (int)$row['id'],
            'name'          => $row['name'],
            'description'   => $row['description'],
            'visibility'    => $row['visibility'],
            'avatar_emoji'  => $row['avatar_emoji'],
            'avatar_color'  => $row['avatar_color'],
            'owner_id'      => (int)$row['owner_id'],
            'created_at'    => $row['created_at'],
            'members_count' => (int)$row['members_count'],
            'events_count'  => (int)$row['events_count'],
        ];
    }

    json_response(['markets' => $markets]);
}

/**
 * POST /api/markets.php
 * Create a new Market (group) and optionally add existing friends + email invites.
 */
function handle_create_market(?array $data = null): void {
    $ownerId = require_verified_auth(); // Requires email verification
    $pdo     = get_pdo();

    // CSRF protection for market creation
    tyches_require_csrf();

    if (!is_array($data)) {
        $data = $_POST;
    }

    $name        = sanitize_string($data['name'] ?? '', 150);
    $description = sanitize_string($data['description'] ?? '', 1000);
    $visibility  = sanitize_string($data['visibility'] ?? 'invite_only', 20);
    $avatarEmoji = sanitize_string($data['avatar_emoji'] ?? '', 8);
    $avatarColor = sanitize_string($data['avatar_color'] ?? '', 16);

    $friendIds = isset($data['friend_ids']) && is_array($data['friend_ids'])
        ? array_map('intval', $data['friend_ids'])
        : [];
    
    $usernames = isset($data['usernames']) && is_array($data['usernames'])
        ? $data['usernames']
        : [];

    $invites = isset($data['invites']) && is_array($data['invites'])
        ? $data['invites']
        : [];

    if ($name === '') {
        json_response(['error' => 'Market name is required'], 400);
    }

    $visibilityAllowed = ['private', 'invite_only', 'link_only'];
    if (!in_array($visibility, $visibilityAllowed, true)) {
        $visibility = 'invite_only';
    }

    if ($avatarEmoji === '') {
        $avatarEmoji = '🎯';
    }

    $pdo->beginTransaction();

    try {
        // Create market
        $stmt = $pdo->prepare(
            'INSERT INTO markets (owner_id, name, description, visibility, avatar_emoji, avatar_color)
             VALUES (:owner_id, :name, :description, :visibility, :avatar_emoji, :avatar_color)'
        );
        $stmt->execute([
            ':owner_id'     => $ownerId,
            ':name'         => $name,
            ':description'  => $description !== '' ? $description : null,
            ':visibility'   => $visibility,
            ':avatar_emoji' => $avatarEmoji,
            ':avatar_color' => $avatarColor !== '' ? $avatarColor : null,
        ]);

        $marketId = (int)$pdo->lastInsertId();

        // Owner as member
        $stmtMember = $pdo->prepare(
            'INSERT INTO market_members (market_id, user_id, role)
             VALUES (:mid, :uid, :role)'
        );
        $stmtMember->execute([
            ':mid'  => $marketId,
            ':uid'  => $ownerId,
            ':role' => 'owner',
        ]);

        // Add selected friends as members (if they are actually friends)
        if (!empty($friendIds)) {
            $placeholders = implode(',', array_fill(0, count($friendIds), '?'));
            $sqlFriends = "
                SELECT id FROM users
                WHERE id IN ($placeholders)
            ";
            $stmtFriends = $pdo->prepare($sqlFriends);
            $stmtFriends->execute($friendIds);
            $validIds = array_column($stmtFriends->fetchAll() ?: [], 'id');

            foreach ($validIds as $fid) {
                if ((int)$fid === $ownerId) {
                    continue;
                }
                try {
                    $stmtMember->execute([
                        ':mid'  => $marketId,
                        ':uid'  => (int)$fid,
                        ':role' => 'member',
                    ]);
                } catch (PDOException $e) {
                    // Ignore duplicates
                }
            }
        }
        
        // Add users by username
        if (!empty($usernames)) {
            $stmtFindByUsername = $pdo->prepare('SELECT id FROM users WHERE username = :username');
            
            foreach ($usernames as $username) {
                $username = trim((string)$username);
                if ($username === '') continue;
                
                // Remove @ if present
                $username = ltrim($username, '@');
                
                $stmtFindByUsername->execute([':username' => $username]);
                $userRow = $stmtFindByUsername->fetch();
                
                if (!$userRow) {
                    continue; // Username not found
                }
                
                $userId = (int)$userRow['id'];
                if ($userId === $ownerId) {
                    continue; // Don't add owner again
                }
                
                try {
                    $stmtMember->execute([
                        ':mid'  => $marketId,
                        ':uid'  => $userId,
                        ':role' => 'member',
                    ]);
                } catch (PDOException $e) {
                    // Ignore duplicates
                }
            }
        }

        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        throw $e;
    }

    // Reward: tokens for creating a new market.
    tyches_award_tokens($pdo, $ownerId, TYCHES_TOKENS_MARKET);

    // Process email invites - store pending invites for non-existing users
    if (!empty($invites)) {
        // Get owner's name for invitation
        $stmtOwner = $pdo->prepare('SELECT name FROM users WHERE id = ?');
        $stmtOwner->execute([$ownerId]);
        $inviterName = $stmtOwner->fetchColumn() ?: 'Someone';
        
        // Prepare statements for checking existing users and storing pending invites
        $stmtFindUser = $pdo->prepare('SELECT id FROM users WHERE email = :email');
        $stmtCheckMember = $pdo->prepare('SELECT id FROM market_members WHERE market_id = :mid AND user_id = :uid');
        $stmtAddMember = $pdo->prepare('INSERT INTO market_members (market_id, user_id, role) VALUES (:mid, :uid, \'member\')');
        $stmtPendingInvite = $pdo->prepare('
            INSERT IGNORE INTO pending_market_invites (email, market_id, invited_by)
            VALUES (:email, :market_id, :invited_by)
        ');
        
        foreach ($invites as $inviteEmail) {
            $inviteEmail = strtolower(trim((string)$inviteEmail));
            if ($inviteEmail === '' || !filter_var($inviteEmail, FILTER_VALIDATE_EMAIL)) {
                continue;
            }
            
            // Check if user already exists
            $stmtFindUser->execute([':email' => $inviteEmail]);
            $existingUser = $stmtFindUser->fetch();
            
            if ($existingUser) {
                // User exists - add them directly if not already a member
                $stmtCheckMember->execute([':mid' => $marketId, ':uid' => $existingUser['id']]);
                if (!$stmtCheckMember->fetch()) {
                    try {
                        $stmtAddMember->execute([':mid' => $marketId, ':uid' => $existingUser['id']]);
                    } catch (PDOException $e) {
                        // Ignore duplicates
                    }
                }
            } else {
                // User doesn't exist - store pending invite for when they sign up
                try {
                    $stmtPendingInvite->execute([
                        ':email' => $inviteEmail,
                        ':market_id' => $marketId,
                        ':invited_by' => $ownerId,
                    ]);
                } catch (PDOException $e) {
                    // Ignore errors (table might not exist yet, or duplicate)
                }
            }
            
            // Send invitation email regardless
            send_market_invite_email($inviteEmail, $inviterName, $name, (string)$marketId);
        }
    }

    json_response([
        'id'           => $marketId,
        'name'         => $name,
        'description'  => $description,
        'visibility'   => $visibility,
        'avatar_emoji' => $avatarEmoji,
        'avatar_color' => $avatarColor,
    ], 201);
}

/**
 * POST /api/markets.php with action=invite
 * Invite members to a market.
 */
function handle_invite_to_market(array $data): void {
    tyches_require_csrf();
    $uid = require_auth();
    $pdo = get_pdo();
    
    $marketId = isset($data['market_id']) ? (int)$data['market_id'] : 0;
    $emails = isset($data['emails']) && is_array($data['emails']) ? $data['emails'] : [];
    $userIds = isset($data['user_ids']) && is_array($data['user_ids']) ? array_map('intval', $data['user_ids']) : [];
    $usernames = isset($data['usernames']) && is_array($data['usernames']) ? $data['usernames'] : [];
    
    if ($marketId <= 0) {
        json_response(['error' => 'Market ID is required'], 400);
    }
    
    if (empty($emails) && empty($userIds) && empty($usernames)) {
        json_response(['error' => 'Please provide emails, usernames, or user IDs to invite'], 400);
    }
    
    // Get market and verify the user is the owner
    $stmt = $pdo->prepare('SELECT * FROM markets WHERE id = :market_id');
    $stmt->execute([':market_id' => $marketId]);
    $market = $stmt->fetch();
    
    if (!$market) {
        json_response(['error' => 'Market not found'], 404);
    }
    
    $isOwner = (int)$market['owner_id'] === $uid;
    
    if (!$isOwner) {
        json_response(['error' => 'Only the market owner can invite members'], 403);
    }
    
    $marketName = $market['name'];
    
    // Get inviter's name
    $stmt = $pdo->prepare('SELECT name FROM users WHERE id = :uid');
    $stmt->execute([':uid' => $uid]);
    $inviterName = $stmt->fetchColumn() ?: 'Someone';
    
    $invited = 0;
    $alreadyMembers = 0;
    $emailsSent = 0;
    
    // Add existing users by ID
    if (!empty($userIds)) {
        $stmtCheck = $pdo->prepare('
            SELECT id FROM market_members WHERE market_id = :mid AND user_id = :uid
        ');
        $stmtInsert = $pdo->prepare('
            INSERT INTO market_members (market_id, user_id, role)
            VALUES (:mid, :uid, \'member\')
        ');
        
        foreach ($userIds as $inviteeId) {
            if ($inviteeId <= 0) continue;
            
            // Check if already a member
            $stmtCheck->execute([':mid' => $marketId, ':uid' => $inviteeId]);
            if ($stmtCheck->fetch()) {
                $alreadyMembers++;
                continue;
            }
            
            try {
                $stmtInsert->execute([':mid' => $marketId, ':uid' => $inviteeId]);
                $invited++;
                
                // Create notification for the invited user
                createMarketNotification($pdo, (int)$inviteeId, $marketId, $marketName, $inviterName);
            } catch (PDOException $e) {
                // Ignore duplicates
            }
        }
    }
    
    // Add existing users by username
    if (!empty($usernames)) {
        $stmtFindByUsername = $pdo->prepare('SELECT id FROM users WHERE username = :username');
        $stmtCheck = $pdo->prepare('
            SELECT id FROM market_members WHERE market_id = :mid AND user_id = :uid
        ');
        $stmtInsert = $pdo->prepare('
            INSERT INTO market_members (market_id, user_id, role)
            VALUES (:mid, :uid, \'member\')
        ');
        
        foreach ($usernames as $username) {
            $username = trim((string)$username);
            if ($username === '') continue;
            
            // Remove @ if present
            $username = ltrim($username, '@');
            
            // Find user by username
            $stmtFindByUsername->execute([':username' => $username]);
            $userRow = $stmtFindByUsername->fetch();
            
            if (!$userRow) {
                continue; // Username not found
            }
            
            $inviteeId = (int)$userRow['id'];
            
            // Check if already a member
            $stmtCheck->execute([':mid' => $marketId, ':uid' => $inviteeId]);
            if ($stmtCheck->fetch()) {
                $alreadyMembers++;
                continue;
            }
            
            try {
                $stmtInsert->execute([':mid' => $marketId, ':uid' => $inviteeId]);
                $invited++;
                
                // Create notification for the invited user
                createMarketNotification($pdo, $inviteeId, $marketId, $marketName, $inviterName);
            } catch (PDOException $e) {
                // Ignore duplicates
            }
        }
    }
    
    // Invite by email
    if (!empty($emails)) {
        $stmtFindUser = $pdo->prepare('SELECT id, name, email FROM users WHERE email = :email');
        $stmtCheckMember = $pdo->prepare('
            SELECT id FROM market_members WHERE market_id = :mid AND user_id = :uid
        ');
        $stmtInsertMember = $pdo->prepare('
            INSERT INTO market_members (market_id, user_id, role)
            VALUES (:mid, :uid, \'member\')
        ');
        
        foreach ($emails as $email) {
            $email = trim(strtolower((string)$email));
            if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
                continue;
            }
            
            // Check if user exists
            $stmtFindUser->execute([':email' => $email]);
            $existingUser = $stmtFindUser->fetch();
            
            if ($existingUser) {
                // User exists - add to market if not already a member
                $stmtCheckMember->execute([':mid' => $marketId, ':uid' => $existingUser['id']]);
                if ($stmtCheckMember->fetch()) {
                    $alreadyMembers++;
                    continue;
                }
                
                try {
                    $stmtInsertMember->execute([':mid' => $marketId, ':uid' => $existingUser['id']]);
                    $invited++;
                    
                    // Create in-app notification for the invited user
                    createMarketNotification($pdo, (int)$existingUser['id'], $marketId, $marketName, $inviterName);
                    
                    // Send notification email to existing user
                    send_notification_email(
                        $email,
                        $existingUser['name'],
                        "You've been added to a market",
                        "{$inviterName} added you to the market \"{$marketName}\" on Tyches. You can now view and participate in all events in this market.",
                        'View Market',
                        APP_URL . "/market.php?id={$marketId}"
                    );
                    $emailsSent++;
                } catch (PDOException $e) {
                    // Ignore
                }
            } else {
                // User doesn't exist - store pending invite and send email
                try {
                    $stmtPendingInvite = $pdo->prepare('
                        INSERT IGNORE INTO pending_market_invites (email, market_id, invited_by)
                        VALUES (:email, :market_id, :invited_by)
                    ');
                    $stmtPendingInvite->execute([
                        ':email' => $email,
                        ':market_id' => $marketId,
                        ':invited_by' => $uid,
                    ]);
                } catch (PDOException $e) {
                    // Ignore errors (table might not exist yet, or duplicate)
                }
                
                send_market_invite_email($email, $inviterName, $marketName, (string)$marketId);
                $emailsSent++;
            }
        }
    }
    
    $message = [];
    if ($invited > 0) {
        $message[] = "{$invited} member(s) added";
    }
    if ($emailsSent > 0) {
        $message[] = "{$emailsSent} invitation(s) sent";
    }
    if ($alreadyMembers > 0) {
        $message[] = "{$alreadyMembers} already member(s)";
    }

    // Reward: tokens for invitations (both direct user IDs and emails).
    $totalInvites = $invited + $emailsSent;
    if ($totalInvites > 0) {
        tyches_award_tokens($pdo, $uid, TYCHES_TOKENS_INVITE * $totalInvites);
    }
    
    json_response([
        'ok' => true,
        'invited' => $invited,
        'emails_sent' => $emailsSent,
        'already_members' => $alreadyMembers,
        'message' => implode(', ', $message) ?: 'No invitations sent',
    ]);
}

/**
 * Normalize an event row from DB for JSON output.
 *
 * @param array $row
 * @return array
 */
function normalize_event_row(array $row): array {
    $outcomes = null;
    if (!empty($row['outcomes_json'])) {
        $decoded = json_decode((string)$row['outcomes_json'], true);
        if (is_array($decoded)) {
            $outcomes = $decoded;
        }
    }

    return [
        'id'             => (int)$row['id'],
        'market_id'      => (int)$row['market_id'],
        'creator_id'     => (int)$row['creator_id'],
        'creator_name'   => $row['creator_name'] ?? null,
        'creator_handle' => $row['creator_username'] ?? null,
        'title'          => $row['title'],
        'description'    => $row['description'],
        'event_type'     => $row['event_type'],
        'status'         => $row['status'],
        'closes_at'      => $row['closes_at'],
        'created_at'     => $row['created_at'],
        'yes_price'      => $row['yes_price'] !== null ? (int)$row['yes_price'] : null,
        'no_price'       => $row['no_price'] !== null ? (int)$row['no_price'] : null,
        'yes_percent'    => $row['yes_percent'] !== null ? (int)$row['yes_percent'] : null,
        'no_percent'     => $row['no_percent'] !== null ? (int)$row['no_percent'] : null,
        'outcomes'       => $outcomes,
        'volume'         => (float)$row['volume'],
        'traders_count'  => (int)$row['traders_count'],
        'winning_side'   => $row['winning_side'],
        'winning_outcome_id' => $row['winning_outcome_id'],
    ];
}

/**
 * Create a notification when a user is added to a market
 */
function createMarketNotification(PDO $pdo, int $userId, int $marketId, string $marketName, string $inviterName): void {
    try {
        $stmt = $pdo->prepare("
            INSERT INTO notifications (user_id, type, title, message, url)
            VALUES (?, 'market_invite', ?, ?, ?)
        ");
        $stmt->execute([
            $userId,
            "You've been added to {$marketName}! 👥",
            "{$inviterName} added you to the market. You can now view and participate in all events.",
            "market.php?id={$marketId}"
        ]);
    } catch (Exception $e) {
        error_log('createMarketNotification error: ' . $e->getMessage());
    }
}

/**
 * Check if user can access a private event (is a participant)
 */
function canUserAccessEvent(PDO $pdo, int $eventId, int $userId): bool {
    $stmt = $pdo->prepare(
        'SELECT 1 FROM event_participants WHERE event_id = :event_id AND user_id = :user_id LIMIT 1'
    );
    $stmt->execute([':event_id' => $eventId, ':user_id' => $userId]);
    return (bool)$stmt->fetch();
}

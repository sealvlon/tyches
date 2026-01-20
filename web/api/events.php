<?php
// api/events.php
// Create and list Events (prediction questions) within Markets.

declare(strict_types=1);

require_once __DIR__ . '/security.php';
require_once __DIR__ . '/mailer.php';
require_once __DIR__ . '/pools.php';

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
        handle_get_events();
    } elseif ($method === 'POST') {
        // Check if this is an action
        $data = json_decode($GLOBALS['tyches_raw_input'], true);
        $action = (is_array($data) && isset($data['action'])) ? $data['action'] : null;
        
        switch ($action) {
            case 'invite':
                handle_invite_to_event($data);
                break;
            case 'add_participant':
                handle_add_participant($data);
                break;
            case 'remove_participant':
                handle_remove_participant($data);
                break;
            default:
                handle_create_event($data);
        }
    } else {
        json_response(['error' => 'Method not allowed'], 405);
    }
} catch (Throwable $e) {
    error_log('events.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    json_response(['error' => 'Server error'], 500);
}

/**
 * GET /api/events.php
 *  - ?market_id=... → list events in a market (if member)
 *  - ?id=...        → single event with basic meta
 */
function handle_get_events(): void {
    $uid = require_auth();
    $pdo = get_pdo();

    $id        = isset($_GET['id']) ? (int)$_GET['id'] : 0;
    $marketId  = isset($_GET['market_id']) ? (int)$_GET['market_id'] : 0;

    if ($id > 0) {
        // Get event with resolver info
        $stmt = $pdo->prepare(
            'SELECT e.*, m.name AS market_name, m.avatar_emoji, m.avatar_color,
                    m.owner_id AS market_owner_id,
                    u.name AS creator_name, u.username AS creator_username,
                    r.name AS resolver_name, r.username AS resolver_username
             FROM events e
             INNER JOIN markets m ON m.id = e.market_id
             INNER JOIN users u ON u.id = e.creator_id
             LEFT JOIN users r ON r.id = e.resolver_id
             INNER JOIN market_members mm ON mm.market_id = e.market_id AND mm.user_id = :uid
             WHERE e.id = :id
             LIMIT 1'
        );
        $stmt->execute([':id' => $id, ':uid' => $uid]);
        $row = $stmt->fetch();
        if (!$row) {
            json_response(['error' => 'Event not found'], 404);
        }
        
        // Check visibility for private events
        $visibility = $row['visibility'] ?? 'public';
        if ($visibility === 'private' && !can_user_access_event($pdo, $id, $uid, $visibility)) {
            // Also allow creator and resolver
            if ((int)$row['creator_id'] !== $uid && (int)$row['resolver_id'] !== $uid) {
                json_response(['error' => 'Event not found'], 404);
            }
        }
        
        $event = normalize_event_for_output($row);
        
        // Add permissions for the current user
        $isCreator = (int)$row['creator_id'] === $uid;
        $isResolver = (int)($row['resolver_id'] ?? 0) === $uid;
        $isMarketOwner = (int)$row['market_owner_id'] === $uid;
        $isHost = is_event_host($pdo, $id, $uid);
        
        $event['is_creator'] = $isCreator;
        $event['is_resolver'] = $isResolver;
        $event['is_market_owner'] = $isMarketOwner;
        $event['is_host'] = $isHost;
        $event['can_invite'] = $isCreator || $isMarketOwner || $isHost;
        // can_manage: close/reopen trading (NOT resolver - resolver only resolves)
        $event['can_manage'] = $isCreator || $isMarketOwner || $isHost;
        // can_resolve: determine outcome
        $event['can_resolve'] = $isResolver || $isCreator || $isMarketOwner || $isHost;
        
        // Add real-time pool/odds data
        $event['pools'] = calculate_event_odds($pdo, $id);
        
        // Get user's position
        $event['your_position'] = get_potential_payout($pdo, $id, $uid);
        
        // For private events, include participants list
        if ($visibility === 'private') {
            $event['participants'] = get_event_participants($pdo, $id);
        }
        
        json_response(['event' => $event]);
        return;
    }

    if ($marketId > 0) {
        // Ensure membership in this market.
        $stmtCheck = $pdo->prepare(
            'SELECT 1 FROM market_members WHERE market_id = :mid AND user_id = :uid LIMIT 1'
        );
        $stmtCheck->execute([':mid' => $marketId, ':uid' => $uid]);
        if (!$stmtCheck->fetch()) {
            json_response(['error' => 'Not a member of this market'], 403);
        }

        // Get events, filtering out private events user can't access
        $stmt = $pdo->prepare(
            'SELECT e.*, 
                    u.name AS creator_name, u.username AS creator_username,
                    r.name AS resolver_name, r.username AS resolver_username
             FROM events e
             INNER JOIN users u ON u.id = e.creator_id
             LEFT JOIN users r ON r.id = e.resolver_id
             WHERE e.market_id = :mid
             ORDER BY e.created_at DESC
             LIMIT 100'
        );
        $stmt->execute([':mid' => $marketId]);
        $rows = $stmt->fetchAll() ?: [];

        $events = [];
        foreach ($rows as $row) {
            // Filter private events
            $visibility = $row['visibility'] ?? 'public';
            if ($visibility === 'private') {
                $isCreator = (int)$row['creator_id'] === $uid;
                $isResolver = (int)($row['resolver_id'] ?? 0) === $uid;
                if (!$isCreator && !$isResolver && !can_user_access_event($pdo, (int)$row['id'], $uid, $visibility)) {
                    continue; // Skip this event
                }
            }
            
            $event = normalize_event_for_output($row);
            // Add pool data
            $event['pools'] = calculate_event_odds($pdo, (int)$row['id']);
            $events[] = $event;
        }

        json_response(['events' => $events]);
        return;
    }

    // Check for filter parameter
    $filter = sanitize_string($_GET['filter'] ?? '', 32);
    
    if ($filter === 'participating' || $filter === 'my') {
        // Get ALL events from markets the user belongs to
        // Simple query: user is market member = sees all events in that market
        // Order by most recently created first
        $stmt = $pdo->prepare(
            "SELECT e.*, m.name AS market_name, m.avatar_emoji, m.avatar_color,
                    u.name AS creator_name, u.username AS creator_username,
                    r.name AS resolver_name, r.username AS resolver_username
             FROM events e
             INNER JOIN markets m ON m.id = e.market_id
             INNER JOIN market_members mm ON mm.market_id = m.id AND mm.user_id = :uid
             INNER JOIN users u ON u.id = e.creator_id
             LEFT JOIN users r ON r.id = e.resolver_id
             ORDER BY e.created_at DESC
             LIMIT 100"
        );
        $stmt->execute([':uid' => $uid]);
    } else {
        // Default: upcoming events across all markets the user belongs to.
        $stmt = $pdo->prepare(
            'SELECT e.*, m.name AS market_name, m.avatar_emoji, m.avatar_color,
                    u.name AS creator_name, u.username AS creator_username,
                    r.name AS resolver_name, r.username AS resolver_username
             FROM events e
             INNER JOIN markets m ON m.id = e.market_id
             INNER JOIN market_members mm ON mm.market_id = m.id AND mm.user_id = :uid
             INNER JOIN users u ON u.id = e.creator_id
             LEFT JOIN users r ON r.id = e.resolver_id
             WHERE e.status = "open"
             ORDER BY e.closes_at ASC
             LIMIT 50'
        );
        $stmt->execute([':uid' => $uid]);
    }
    
    $rows = $stmt->fetchAll() ?: [];

    $events = [];
    foreach ($rows as $row) {
        // Filter private events - only show if user has access
        $visibility = $row['visibility'] ?? 'public';
        if ($visibility === 'private') {
            $isCreator = (int)$row['creator_id'] === $uid;
            $isResolver = (int)($row['resolver_id'] ?? 0) === $uid;
            if (!$isCreator && !$isResolver && !can_user_access_event($pdo, (int)$row['id'], $uid, $visibility)) {
                continue; // Skip this event
            }
        }
        
        $event = normalize_event_for_output($row);
        // Add pool data
        $event['pools'] = calculate_event_odds($pdo, (int)$row['id']);
        $events[] = $event;
    }

    json_response(['events' => $events]);
}

/**
 * POST /api/events.php
 * Create a new Event inside a market.
 */
function handle_create_event(?array $data = null): void {
    $uid = require_verified_auth(); // Requires email verification
    $pdo = get_pdo();

    // CSRF protection for event creation
    tyches_require_csrf();

    if (!is_array($data)) {
        $data = $_POST;
    }

    $marketId       = isset($data['market_id']) ? (int)$data['market_id'] : 0;
    $title          = sanitize_string($data['title'] ?? '', 255);
    $description    = sanitize_string($data['description'] ?? '', 1000);
    $eventType      = strtolower(sanitize_string($data['event_type'] ?? 'binary', 16));
    $closesAt       = sanitize_string($data['closes_at'] ?? '', 32);
    
    // New fields: visibility, resolver, resolution_type
    $visibility     = strtolower(sanitize_string($data['visibility'] ?? 'public', 16));
    $resolverId     = isset($data['resolver_id']) ? (int)$data['resolver_id'] : 0;
    $resolutionType = strtolower(sanitize_string($data['resolution_type'] ?? 'manual', 16));
    $participants   = isset($data['participants']) && is_array($data['participants']) ? $data['participants'] : [];

    if ($marketId <= 0 || $title === '' || $closesAt === '') {
        json_response(['error' => 'Market, title, and closing time are required'], 400);
    }

    if (!in_array($eventType, ['binary', 'multiple'], true)) {
        $eventType = 'binary';
    }
    
    if (!in_array($visibility, ['public', 'private'], true)) {
        $visibility = 'public';
    }
    
    if (!in_array($resolutionType, ['manual', 'automatic'], true)) {
        $resolutionType = 'manual';
    }

    // Ensure user is in the market.
    $stmtCheck = $pdo->prepare(
        'SELECT 1 FROM market_members WHERE market_id = :mid AND user_id = :uid LIMIT 1'
    );
    $stmtCheck->execute([':mid' => $marketId, ':uid' => $uid]);
    if (!$stmtCheck->fetch()) {
        json_response(['error' => 'Not a member of this market'], 403);
    }
    
    // Validate resolver_id if provided (must be a market member)
    if ($resolverId > 0 && $resolverId !== $uid) {
        $stmtResolverCheck = $pdo->prepare(
            'SELECT 1 FROM market_members WHERE market_id = :mid AND user_id = :uid LIMIT 1'
        );
        $stmtResolverCheck->execute([':mid' => $marketId, ':uid' => $resolverId]);
        if (!$stmtResolverCheck->fetch()) {
            json_response(['error' => 'Resolver must be a member of this market'], 400);
        }
    } else {
        // Default: creator is the resolver
        $resolverId = $uid;
    }

    // Parse closes_at into DATETIME; basic validation
    $closesAtDateTime = date_create($closesAt);
    if (!$closesAtDateTime) {
        json_response(['error' => 'Invalid closing time'], 400);
    }
    $closesAtStr = $closesAtDateTime->format('Y-m-d H:i:s');

    $yesPrice    = null;
    $noPrice     = null;
    $yesPercent  = null;
    $noPercent   = null;
    $outcomesJson= null;

    if ($eventType === 'binary') {
        $yesPctInput = isset($data['yes_percent']) ? (int)$data['yes_percent'] : 50;
        $yesPercent  = max(1, min(99, $yesPctInput));
        $noPercent   = 100 - $yesPercent;
        $yesPrice    = $yesPercent; // cents 1–99
        $noPrice     = $noPercent;  // cents 1–99
    } else {
        // Multiple choice: label + probability entries
        $rawOutcomes = isset($data['outcomes']) && is_array($data['outcomes']) ? $data['outcomes'] : [];
        $clean = [];
        foreach ($rawOutcomes as $o) {
            $label = sanitize_string($o['label'] ?? '', 80);
            $prob  = isset($o['probability']) ? (int)$o['probability'] : 0;
            $id    = sanitize_string($o['id'] ?? '', 64);
            if ($label !== '' && $prob > 0) {
                if ($id === '') {
                    $id = strtolower(preg_replace('/[^a-zA-Z0-9_]+/', '_', $label));
                }
                $clean[] = [
                    'id'          => $id,
                    'label'       => $label,
                    'probability' => $prob,
                ];
            }
        }
        if (count($clean) < 2) {
            json_response(['error' => 'Multiple-choice events need at least two outcomes'], 400);
        }

        // Normalize probabilities to sum 100
        $total = array_sum(array_column($clean, 'probability'));
        if ($total <= 0) {
            $equal = (int)floor(100 / count($clean));
            foreach ($clean as $i => &$o) {
                $o['probability'] = $equal;
            }
            $clean[count($clean) - 1]['probability'] = 100 - ($equal * (count($clean) - 1));
        } else {
            $acc = 0;
            foreach ($clean as $i => &$o) {
                if ($i === count($clean) - 1) {
                    $o['probability'] = 100 - $acc;
                } else {
                    $p = (int)round(($o['probability'] / $total) * 100);
                    $p = max(1, min(99, $p));
                    $o['probability'] = $p;
                    $acc += $p;
                }
            }
        }

        $outcomesJson = json_encode($clean);
    }

    $stmt = $pdo->prepare(
        'INSERT INTO events
         (market_id, creator_id, resolver_id, title, description, event_type, status, 
          visibility, resolution_type, closes_at,
          yes_price, no_price, yes_percent, no_percent, outcomes_json)
         VALUES
         (:market_id, :creator_id, :resolver_id, :title, :description, :event_type, "open", 
          :visibility, :resolution_type, :closes_at,
          :yes_price, :no_price, :yes_percent, :no_percent, :outcomes_json)'
    );
    $stmt->execute([
        ':market_id'       => $marketId,
        ':creator_id'      => $uid,
        ':resolver_id'     => $resolverId,
        ':title'           => $title,
        ':description'     => $description !== '' ? $description : null,
        ':event_type'      => $eventType,
        ':visibility'      => $visibility,
        ':resolution_type' => $resolutionType,
        ':closes_at'       => $closesAtStr,
        ':yes_price'       => $yesPrice,
        ':no_price'        => $noPrice,
        ':yes_percent'     => $yesPercent,
        ':no_percent'      => $noPercent,
        ':outcomes_json'   => $outcomesJson,
    ]);

    $eventId = (int)$pdo->lastInsertId();
    
    // For private events, add the creator and selected participants
    if ($visibility === 'private') {
        // Always add creator as participant (host role)
        $stmtAddParticipant = $pdo->prepare(
            'INSERT INTO event_participants (event_id, user_id, role, invited_by)
             VALUES (:event_id, :user_id, :role, :invited_by)
             ON DUPLICATE KEY UPDATE role = role'
        );
        
        try {
            $stmtAddParticipant->execute([
                ':event_id'   => $eventId,
                ':user_id'    => $uid,
                ':role'       => 'host',
                ':invited_by' => null,
            ]);
        } catch (PDOException $e) {
            error_log("[Tyches] Failed to add creator as participant: " . $e->getMessage());
        }
        
        // Add resolver if different from creator AND valid
        if ($resolverId > 0 && $resolverId !== $uid) {
            try {
                $stmtAddParticipant->execute([
                    ':event_id'   => $eventId,
                    ':user_id'    => $resolverId,
                    ':role'       => 'host',
                    ':invited_by' => $uid,
                ]);
            } catch (PDOException $e) {
                error_log("[Tyches] Failed to add resolver as participant: " . $e->getMessage());
            }
        }
        
        // Add selected participants
        foreach ($participants as $participantId) {
            $participantId = (int)$participantId;
            if ($participantId > 0 && $participantId !== $uid && $participantId !== $resolverId) {
                try {
                    $stmtAddParticipant->execute([
                        ':event_id'   => $eventId,
                        ':user_id'    => $participantId,
                        ':role'       => 'participant',
                        ':invited_by' => $uid,
                    ]);
                } catch (PDOException $e) {
                    error_log("[Tyches] Failed to add participant {$participantId}: " . $e->getMessage());
                }
            }
        }
    }

    // Reward: tokens for creating a new event.
    tyches_award_tokens($pdo, $uid, TYCHES_TOKENS_EVENT);
    
    // Notify market members about the new event
    notifyMarketMembersAboutEvent($pdo, $marketId, $eventId, $title, $uid, $visibility);

    json_response(['id' => $eventId], 201);
}

/**
 * POST /api/events.php with action=invite
 * Invite members to an event (adds them to the parent market).
 */
function handle_invite_to_event(array $data): void {
    tyches_require_csrf();
    $uid = require_auth();
    $pdo = get_pdo();
    
    $eventId = isset($data['event_id']) ? (int)$data['event_id'] : 0;
    $emails = isset($data['emails']) && is_array($data['emails']) ? $data['emails'] : [];
    $userIds = isset($data['user_ids']) && is_array($data['user_ids']) ? array_map('intval', $data['user_ids']) : [];
    
    if ($eventId <= 0) {
        json_response(['error' => 'Event ID is required'], 400);
    }
    
    if (empty($emails) && empty($userIds)) {
        json_response(['error' => 'Please provide emails or user IDs to invite'], 400);
    }
    
    // Get event and verify the user is the creator or market owner
    $stmt = $pdo->prepare('
        SELECT e.*, m.owner_id AS market_owner_id, m.name AS market_name
        FROM events e
        INNER JOIN markets m ON m.id = e.market_id
        WHERE e.id = :event_id
    ');
    $stmt->execute([':event_id' => $eventId]);
    $event = $stmt->fetch();
    
    if (!$event) {
        json_response(['error' => 'Event not found'], 404);
    }
    
    $isCreator = (int)$event['creator_id'] === $uid;
    $isMarketOwner = (int)$event['market_owner_id'] === $uid;
    
    if (!$isCreator && !$isMarketOwner) {
        json_response(['error' => 'Only the event creator or market owner can invite members'], 403);
    }
    
    $marketId = (int)$event['market_id'];
    $marketName = $event['market_name'];
    $eventTitle = $event['title'];
    
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
                    
                    // Send notification email to existing user
                    send_notification_email(
                        $email,
                        $existingUser['name'],
                        "You've been invited to an event",
                        "{$inviterName} invited you to participate in \"{$eventTitle}\" on Tyches.",
                        'View Event',
                        APP_URL . "/event.php?id={$eventId}"
                    );
                    $emailsSent++;
                } catch (PDOException $e) {
                    // Ignore
                }
            } else {
                // User doesn't exist - send invite email
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
 * Normalize event row for JSON.
 *
 * @param array $row
 * @return array
 */
function normalize_event_for_output(array $row): array {
    $outcomes = null;
    if (!empty($row['outcomes_json'])) {
        $decoded = json_decode((string)$row['outcomes_json'], true);
        if (is_array($decoded)) {
            $outcomes = $decoded;
        }
    }

    return [
        'id'                  => (int)$row['id'],
        'market_id'           => (int)$row['market_id'],
        'creator_id'          => (int)$row['creator_id'],
        'resolver_id'         => isset($row['resolver_id']) ? (int)$row['resolver_id'] : (int)$row['creator_id'],
        'title'               => $row['title'],
        'description'         => $row['description'],
        'event_type'          => $row['event_type'],
        'status'              => $row['status'],
        'visibility'          => $row['visibility'] ?? 'public',
        'resolution_type'     => $row['resolution_type'] ?? 'manual',
        'closes_at'           => $row['closes_at'],
        'created_at'          => $row['created_at'],
        'yes_price'           => $row['yes_price'] !== null ? (int)$row['yes_price'] : null,
        'no_price'            => $row['no_price'] !== null ? (int)$row['no_price'] : null,
        'yes_percent'         => $row['yes_percent'] !== null ? (int)$row['yes_percent'] : null,
        'no_percent'          => $row['no_percent'] !== null ? (int)$row['no_percent'] : null,
        'outcomes'            => $outcomes,
        'volume'              => (float)$row['volume'],
        'traders_count'       => (int)$row['traders_count'],
        'winning_side'        => $row['winning_side'],
        'winning_outcome_id'  => $row['winning_outcome_id'],
        'market_name'         => $row['market_name'] ?? null,
        'market_avatar_emoji' => $row['avatar_emoji'] ?? null,
        'market_avatar_color' => $row['avatar_color'] ?? null,
        'creator_name'        => $row['creator_name'] ?? null,
        'creator_username'    => $row['creator_username'] ?? null,
        'resolver_name'       => $row['resolver_name'] ?? null,
        'resolver_username'   => $row['resolver_username'] ?? null,
    ];
}

/**
 * Check if user is a host for this event
 */
function is_event_host(PDO $pdo, int $eventId, int $userId): bool {
    try {
        // First check if table exists
        $stmt = $pdo->query("SHOW TABLES LIKE 'event_hosts'");
        if (!$stmt->fetch()) {
            return false; // Table doesn't exist
        }
        
        $stmt = $pdo->prepare('SELECT 1 FROM event_hosts WHERE event_id = :event_id AND user_id = :user_id LIMIT 1');
        $stmt->execute([':event_id' => $eventId, ':user_id' => $userId]);
        return (bool)$stmt->fetch();
    } catch (Throwable $e) {
        // Any error - just return false
        return false;
    }
}

/**
 * Check if user can access a private event
 */
function can_user_access_event(PDO $pdo, int $eventId, int $userId, string $visibility): bool {
    // Public events are accessible to all market members (handled by JOIN in main query)
    if ($visibility === 'public') {
        return true;
    }
    
    // Private events: check if user is a participant
    $stmt = $pdo->prepare(
        'SELECT 1 FROM event_participants WHERE event_id = :event_id AND user_id = :user_id LIMIT 1'
    );
    $stmt->execute([':event_id' => $eventId, ':user_id' => $userId]);
    return (bool)$stmt->fetch();
}

/**
 * Add a participant to a private event
 */
function add_event_participant(PDO $pdo, int $eventId, int $userId, string $role = 'participant', ?int $invitedBy = null): bool {
    try {
        $stmt = $pdo->prepare(
            'INSERT INTO event_participants (event_id, user_id, role, invited_by)
             VALUES (:event_id, :user_id, :role, :invited_by)
             ON DUPLICATE KEY UPDATE role = :role2'
        );
        $stmt->execute([
            ':event_id'   => $eventId,
            ':user_id'    => $userId,
            ':role'       => $role,
            ':invited_by' => $invitedBy,
            ':role2'      => $role,
        ]);
        return true;
    } catch (PDOException $e) {
        return false;
    }
}

/**
 * Get event participants
 */
function get_event_participants(PDO $pdo, int $eventId): array {
    $stmt = $pdo->prepare(
        'SELECT ep.*, u.name, u.username
         FROM event_participants ep
         INNER JOIN users u ON u.id = ep.user_id
         WHERE ep.event_id = :event_id
         ORDER BY ep.role DESC, ep.created_at ASC'
    );
    $stmt->execute([':event_id' => $eventId]);
    return $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
}

/**
 * POST /api/events.php with action=add_participant
 * Add a participant to a private event
 */
function handle_add_participant(array $data): void {
    tyches_require_csrf();
    $uid = require_auth();
    $pdo = get_pdo();
    
    $eventId = isset($data['event_id']) ? (int)$data['event_id'] : 0;
    $userId = isset($data['user_id']) ? (int)$data['user_id'] : 0;
    
    if ($eventId <= 0 || $userId <= 0) {
        json_response(['error' => 'Event ID and User ID are required'], 400);
    }
    
    // Get event and verify permissions
    $stmt = $pdo->prepare('
        SELECT e.*, m.owner_id AS market_owner_id
        FROM events e
        INNER JOIN markets m ON m.id = e.market_id
        WHERE e.id = :event_id
    ');
    $stmt->execute([':event_id' => $eventId]);
    $event = $stmt->fetch();
    
    if (!$event) {
        json_response(['error' => 'Event not found'], 404);
    }
    
    // Only creator, resolver, or market owner can add participants
    $isCreator = (int)$event['creator_id'] === $uid;
    $isResolver = (int)($event['resolver_id'] ?? 0) === $uid;
    $isMarketOwner = (int)$event['market_owner_id'] === $uid;
    
    if (!$isCreator && !$isResolver && !$isMarketOwner) {
        json_response(['error' => 'You cannot add participants to this event'], 403);
    }
    
    // Check if this is a private event
    $visibility = $event['visibility'] ?? 'public';
    if ($visibility !== 'private') {
        json_response(['error' => 'Cannot add participants to a public event'], 400);
    }
    
    // Verify user is a market member
    $stmtMember = $pdo->prepare(
        'SELECT 1 FROM market_members WHERE market_id = :mid AND user_id = :uid LIMIT 1'
    );
    $stmtMember->execute([':mid' => $event['market_id'], ':uid' => $userId]);
    if (!$stmtMember->fetch()) {
        json_response(['error' => 'User is not a member of this market'], 400);
    }
    
    // Add participant
    if (add_event_participant($pdo, $eventId, $userId, 'participant', $uid)) {
        json_response(['ok' => true, 'message' => 'Participant added']);
    } else {
        json_response(['error' => 'Could not add participant'], 500);
    }
}

/**
 * POST /api/events.php with action=remove_participant
 * Remove a participant from a private event
 */
function handle_remove_participant(array $data): void {
    tyches_require_csrf();
    $uid = require_auth();
    $pdo = get_pdo();
    
    $eventId = isset($data['event_id']) ? (int)$data['event_id'] : 0;
    $userId = isset($data['user_id']) ? (int)$data['user_id'] : 0;
    
    if ($eventId <= 0 || $userId <= 0) {
        json_response(['error' => 'Event ID and User ID are required'], 400);
    }
    
    // Get event and verify permissions
    $stmt = $pdo->prepare('
        SELECT e.*, m.owner_id AS market_owner_id
        FROM events e
        INNER JOIN markets m ON m.id = e.market_id
        WHERE e.id = :event_id
    ');
    $stmt->execute([':event_id' => $eventId]);
    $event = $stmt->fetch();
    
    if (!$event) {
        json_response(['error' => 'Event not found'], 404);
    }
    
    // Only creator or market owner can remove participants (not resolver)
    $isCreator = (int)$event['creator_id'] === $uid;
    $isMarketOwner = (int)$event['market_owner_id'] === $uid;
    
    // Users can also remove themselves
    $isSelf = $userId === $uid;
    
    if (!$isCreator && !$isMarketOwner && !$isSelf) {
        json_response(['error' => 'You cannot remove participants from this event'], 403);
    }
    
    // Cannot remove the creator or resolver
    if ($userId === (int)$event['creator_id']) {
        json_response(['error' => 'Cannot remove the event creator'], 400);
    }
    if ($userId === (int)($event['resolver_id'] ?? 0)) {
        json_response(['error' => 'Cannot remove the event resolver'], 400);
    }
    
    // Remove participant
    $stmtDelete = $pdo->prepare(
        'DELETE FROM event_participants WHERE event_id = :event_id AND user_id = :user_id'
    );
    $stmtDelete->execute([':event_id' => $eventId, ':user_id' => $userId]);
    
    json_response(['ok' => true, 'message' => 'Participant removed']);
}

/**
 * Notify market members about a new event
 */
function notifyMarketMembersAboutEvent(PDO $pdo, int $marketId, int $eventId, string $eventTitle, int $creatorId, string $visibility): void {
    try {
        // Get creator name
        $stmt = $pdo->prepare('SELECT name, username FROM users WHERE id = ?');
        $stmt->execute([$creatorId]);
        $creator = $stmt->fetch();
        $creatorName = $creator['name'] ?? $creator['username'] ?? 'Someone';
        
        // Get market name
        $stmt = $pdo->prepare('SELECT name FROM markets WHERE id = ?');
        $stmt->execute([$marketId]);
        $marketName = $stmt->fetchColumn() ?: 'a market';
        
        // Get members to notify (exclude the creator)
        if ($visibility === 'private') {
            // For private events, only notify participants
            $stmt = $pdo->prepare('
                SELECT user_id FROM event_participants 
                WHERE event_id = ? AND user_id != ?
            ');
            $stmt->execute([$eventId, $creatorId]);
        } else {
            // For public events, notify all market members
            $stmt = $pdo->prepare('
                SELECT user_id FROM market_members 
                WHERE market_id = ? AND user_id != ?
            ');
            $stmt->execute([$marketId, $creatorId]);
        }
        
        $members = $stmt->fetchAll(PDO::FETCH_COLUMN);
        
        if (empty($members)) return;
        
        // Create notifications for all members
        $stmtInsert = $pdo->prepare("
            INSERT INTO notifications (user_id, type, title, message, url)
            VALUES (?, 'event_created', ?, ?, ?)
        ");
        
        $truncatedTitle = mb_strlen($eventTitle) > 50 ? mb_substr($eventTitle, 0, 47) . '...' : $eventTitle;
        $notifTitle = "New event in {$marketName} 📊";
        $notifMessage = "{$creatorName} created: \"{$truncatedTitle}\"";
        $notifUrl = "event.php?id={$eventId}";
        
        foreach ($members as $memberId) {
            try {
                $stmtInsert->execute([$memberId, $notifTitle, $notifMessage, $notifUrl]);
            } catch (Exception $e) {
                // Continue on individual failures
            }
        }
    } catch (Exception $e) {
        error_log('notifyMarketMembersAboutEvent error: ' . $e->getMessage());
    }
}

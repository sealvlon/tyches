<?php
// api/users.php
// Signup API for Tyches (create user + send verification email).

declare(strict_types=1);

require_once __DIR__ . '/security.php';
require_once __DIR__ . '/mailer.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

try {
    if ($method === 'POST') {
        handle_signup();
    } else {
        json_response(['error' => 'Method not allowed'], 405);
    }
} catch (Throwable $e) {
    // Do NOT leak stack traces to clients.
    json_response(['error' => 'Server error'], 500);
}

/**
 * Handle user signup.
 */
function handle_signup(): void {
    // CSRF protection for signup
    tyches_require_csrf();

    // Basic rate limiting: prevent signup abuse
    $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    tyches_require_rate_limit('signup:' . $ip, 3, 3600); // 3 signups/hour/IP

    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        $data = $_POST;
    }

    $name     = sanitize_string($data['name'] ?? '', 100);
    $username = sanitize_string($data['username'] ?? '', 32);
    $email    = sanitize_string($data['email'] ?? '', 255);
    $phone    = sanitize_string($data['phone'] ?? '', 32);
    $password = (string)($data['password'] ?? '');
    $confirm  = (string)($data['password_confirmation'] ?? '');

    if ($name === '' || $username === '' || $email === '' || $password === '') {
        json_response(['error' => 'Name, username, email and password are required'], 400);
    }

    if (!preg_match('/^[a-zA-Z0-9_]{3,32}$/', $username)) {
        json_response(['error' => 'Username must be 3–32 characters, letters/numbers/underscores only'], 400);
    }

    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        json_response(['error' => 'Invalid email address'], 400);
    }

    if (strlen($password) < 8) {
        json_response(['error' => 'Password must be at least 8 characters'], 400);
    }

    if ($confirm !== '' && $confirm !== $password) {
        json_response(['error' => 'Passwords do not match'], 400);
    }

    $passwordHash = password_hash($password, PASSWORD_DEFAULT);
    $token        = bin2hex(random_bytes(32));

    $pdo = get_pdo();

    $sql = 'INSERT INTO users (name, username, email, phone, password_hash, verification_token)
            VALUES (:name, :username, :email, :phone, :password_hash, :verification_token)';
    $stmt = $pdo->prepare($sql);

    try {
        $stmt->execute([
            ':name'              => $name,
            ':username'          => $username,
            ':email'             => $email,
            ':phone'             => $phone !== '' ? $phone : null,
            ':password_hash'     => $passwordHash,
            ':verification_token'=> $token,
        ]);
    } catch (PDOException $e) {
        // 23000 = integrity constraint violation (duplicate email/username)
        if ((int)$e->getCode() === 23000) {
            json_response(['error' => 'Email or username already registered'], 409);
        }
        throw $e;
    }

    $id = (int)$pdo->lastInsertId();

    // Reward: default starting tokens for every new account.
    tyches_award_tokens($pdo, $id, TYCHES_TOKENS_SIGNUP);
    
    // Process any pending market invitations for this email
    error_log("[Tyches] About to call process_pending_invites for user {$id}, email: {$email}");
    try {
        process_pending_invites($pdo, $id, $email);
        error_log("[Tyches] process_pending_invites completed for user {$id}");
    } catch (Throwable $e) {
        error_log("[Tyches] process_pending_invites EXCEPTION: " . $e->getMessage() . " in " . $e->getFile() . ":" . $e->getLine());
    }

    // Build verification URL pointing to /verify.php at the app root.
    $scheme   = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host     = $_SERVER['HTTP_HOST'] ?? 'example.com';
    $script   = $_SERVER['SCRIPT_NAME'] ?? '';         // e.g. /tyches/api/users.php
    $apiDir   = rtrim(dirname($script), '/\\');        // e.g. /tyches/api
    $basePath = rtrim(dirname($apiDir), '/\\');        // e.g. /tyches

    $verifyUrl = sprintf(
        '%s://%s%s/verify.php?token=%s',
        $scheme,
        $host,
        $basePath,
        urlencode($token)
    );

    // Send verification email using new mailer
    send_verification_email($email, $name, $token);

    // Auto-login the user after signup
    // They can browse but need verification to create markets/events or place bets
    tyches_start_session();
    session_regenerate_id(true);
    $_SESSION['user_id'] = $id;

    json_response([
        'id'                 => $id,
        'name'               => $name,
        'username'           => $username,
        'email'              => $email,
        'phone'              => $phone,
        'needs_verification' => true,
        'auto_logged_in'     => true,
    ], 201);
}

/**
 * Process pending market invitations for a newly registered user.
 * Adds the user to any markets they were invited to before signing up.
 */
function process_pending_invites(PDO $pdo, int $userId, string $email): void {
    $email = strtolower(trim($email));
    
    error_log("[Tyches] Processing pending invites for user {$userId}, email: {$email}");
    
    try {
        // First check if table exists
        try {
            $tableCheck = $pdo->query("SHOW TABLES LIKE 'pending_market_invites'");
            if ($tableCheck->rowCount() === 0) {
                error_log("[Tyches] pending_market_invites table does not exist");
                return;
            }
        } catch (PDOException $e) {
            error_log("[Tyches] Error checking table: " . $e->getMessage());
            return;
        }
        
        // Find all pending invites for this email
        $stmtFind = $pdo->prepare('
            SELECT id, market_id, invited_by
            FROM pending_market_invites
            WHERE LOWER(email) = LOWER(:email)
        ');
        $stmtFind->execute([':email' => $email]);
        $pendingInvites = $stmtFind->fetchAll();
        
        error_log("[Tyches] Found " . count($pendingInvites) . " pending invites for {$email}");
        
        if (empty($pendingInvites)) {
            return;
        }
        
        // Prepare statements for adding members and deleting processed invites
        $stmtAddMember = $pdo->prepare('
            INSERT IGNORE INTO market_members (market_id, user_id, role)
            VALUES (:market_id, :user_id, \'member\')
        ');
        $stmtDelete = $pdo->prepare('DELETE FROM pending_market_invites WHERE id = :id');
        $stmtGetMarket = $pdo->prepare('SELECT name FROM markets WHERE id = :id');
        $stmtGetInviter = $pdo->prepare('SELECT name FROM users WHERE id = :id');
        
        foreach ($pendingInvites as $invite) {
            error_log("[Tyches] Processing invite ID {$invite['id']} for market {$invite['market_id']}");
            
            // Add user to the market - THIS IS THE CRITICAL PART
            try {
                $stmtAddMember->execute([
                    ':market_id' => $invite['market_id'],
                    ':user_id' => $userId,
                ]);
                error_log("[Tyches] Successfully added user {$userId} to market {$invite['market_id']}");
            } catch (PDOException $e) {
                error_log("[Tyches] Error adding user to market: " . $e->getMessage());
                continue; // Skip to next invite if we can't add to market
            }
            
            // Get market name for notification
            $stmtGetMarket->execute([':id' => $invite['market_id']]);
            $marketName = $stmtGetMarket->fetchColumn() ?: 'a market';
            
            // Get inviter name
            $stmtGetInviter->execute([':id' => $invite['invited_by']]);
            $inviterName = $stmtGetInviter->fetchColumn() ?: 'Someone';
            
            // Create welcome notification (optional - don't fail if this doesn't work)
            try {
                $notifTitle = "Welcome to {$marketName}!";
                $notifBody = "{$inviterName} invited you to join this market.";
                $notifUrl = "/market.php?id={$invite['market_id']}";
                
                // Try different column combinations based on what the table might have
                $pdo->exec("
                    INSERT INTO notifications (user_id, type, title, url)
                    VALUES ({$userId}, 'market_invite', '{$notifTitle}', '{$notifUrl}')
                ");
                error_log("[Tyches] Created notification for user {$userId}");
            } catch (PDOException $e) {
                // Notification is optional - log but don't fail
                error_log("[Tyches] Could not create notification (non-critical): " . $e->getMessage());
            }
            
            // Delete the processed invite
            try {
                $stmtDelete->execute([':id' => $invite['id']]);
                error_log("[Tyches] Deleted pending invite {$invite['id']}");
            } catch (PDOException $e) {
                error_log("[Tyches] Error deleting invite: " . $e->getMessage());
            }
        }
    } catch (PDOException $e) {
        // Log error but don't fail signup
        error_log('[Tyches] Error processing pending invites: ' . $e->getMessage());
    }
}



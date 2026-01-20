<?php
// api/helpers.php
// Shared helpers: sessions, JSON responses, auth helpers, validation.

declare(strict_types=1);

require_once __DIR__ . '/config.php';

// === Token reward configuration ===
// Central place for all token reward amounts so they are easy to change later.
const TYCHES_TOKENS_SIGNUP  = 10000; // New account default
const TYCHES_TOKENS_INVITE  = 2000;  // Per invitation sent
const TYCHES_TOKENS_MARKET  = 1000;  // Per market created
const TYCHES_TOKENS_EVENT   = 5000;  // Per event created

/**
 * Award tokens to a user by incrementing their balance.
 *
 * This is a small helper so all reward logic uses the same code path.
 */
function tyches_award_tokens(PDO $pdo, int $userId, float $amount): void {
    if ($amount <= 0) {
        return;
    }

    $stmt = $pdo->prepare('
        UPDATE users
        SET tokens_balance = tokens_balance + :amount
        WHERE id = :id
        LIMIT 1
    ');
    $stmt->execute([
        ':amount' => $amount,
        ':id'     => $userId,
    ]);
}

/**
 * Start a secure PHP session (idempotent).
 *
 * We set the cookie path to "/" to ensure the session is sent to all
 * endpoints (e.g., /admin.php and /api/*.php). This avoids path-mismatch
 * issues that can block admin API calls.
 */
function tyches_start_session(): void {
    if (session_status() === PHP_SESSION_NONE) {
        $secure = !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';

        session_set_cookie_params([
            'lifetime' => 0,
            'path'     => '/',
            'domain'   => '',
            'secure'   => $secure,
            'httponly' => true,
            'samesite' => 'Lax',
        ]);

        session_start();
    }
}

/**
 * Send a JSON response and terminate.
 *
 * @param mixed $data
 * @param int   $status
 */
function json_response($data, int $status = 200): void {
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data);
    exit;
}

/**
 * Get currently authenticated user id from session or null.
 */
function current_user_id(): ?int {
    tyches_start_session();
    if (!isset($_SESSION['user_id']) || !is_int($_SESSION['user_id'])) {
        return null;
    }
    return $_SESSION['user_id'];
}

/**
 * Require authentication for an API endpoint.
 * Exits with 401 JSON if not logged in.
 */
function require_auth(): int {
    $uid = current_user_id();
    if ($uid === null) {
        json_response(['error' => 'Authentication required'], 401);
    }

    // Enforce user status (only active users may use authenticated APIs).
    $pdo = get_pdo();
    $stmt = $pdo->prepare('SELECT status FROM users WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $uid]);
    $row = $stmt->fetch();
    if (!$row) {
        // Session refers to a non-existent user – clear it.
        $_SESSION['user_id'] = null;
        json_response(['error' => 'Authentication required'], 401);
    }

    $status = $row['status'] ?? 'active';
    if ($status !== 'active') {
        json_response(['error' => 'Account is not active. Please contact support.'], 403);
    }

    return $uid;
}

/**
 * Require authentication AND email verification for an API endpoint.
 * Use this for actions like creating markets, events, or placing bets.
 * Exits with 401/403 JSON if not logged in or not verified.
 */
function require_verified_auth(): int {
    $uid = current_user_id();
    if ($uid === null) {
        json_response(['error' => 'Authentication required'], 401);
    }

    $pdo = get_pdo();
    $stmt = $pdo->prepare('SELECT status, email_verified_at FROM users WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $uid]);
    $row = $stmt->fetch();
    
    if (!$row) {
        $_SESSION['user_id'] = null;
        json_response(['error' => 'Authentication required'], 401);
    }

    $status = $row['status'] ?? 'active';
    if ($status !== 'active') {
        json_response(['error' => 'Account is not active. Please contact support.'], 403);
    }

    if ($row['email_verified_at'] === null) {
        json_response([
            'error' => 'Please verify your email to perform this action.',
            'code' => 'EMAIL_NOT_VERIFIED',
            'requires_verification' => true
        ], 403);
    }

    return $uid;
}

/**
 * Fetch the current user row (without password_hash).
 */
function fetch_current_user(PDO $pdo): ?array {
    $uid = current_user_id();
    if ($uid === null) {
        return null;
    }

    $stmt = $pdo->prepare(
        'SELECT id,
                name,
                username,
                email,
                phone,
                email_verified_at,
                is_admin,
                status,
                tokens_balance,
                profile_image_url,
                created_at
         FROM users
         WHERE id = :id
         LIMIT 1'
    );
    $stmt->execute([':id' => $uid]);
    $user = $stmt->fetch();
    return $user ?: null;
}

/**
 * Require that the current session user is an admin.
 * Returns the user row (without password_hash) or exits with 403 JSON.
 */
function require_admin(PDO $pdo): array {
    $user = fetch_current_user($pdo);
    if (
        !$user ||
        (int)$user['is_admin'] !== 1 ||
        ($user['status'] ?? 'active') !== 'active'
    ) {
        json_response(['error' => 'Admin only'], 403);
    }
    return $user;
}

/**
 * Sanitize a string field (trim and strip control characters, but preserve newlines).
 */
function sanitize_string(?string $value, int $maxLength = 255): string {
    $value = trim((string)$value);
    // Strip control characters EXCEPT newlines (\n = \x0A) and carriage returns (\r = \x0D)
    $value = preg_replace('/[\x00-\x09\x0B\x0C\x0E-\x1F\x7F]+/', ' ', $value);
    if (mb_strlen($value) > $maxLength) {
        $value = mb_substr($value, 0, $maxLength);
    }
    return $value;
}

/**
 * Escape HTML for safe output in templates.
 */
function e(string $value): string {
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}





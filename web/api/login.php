<?php
// api/login.php
// Email + password login with PHP sessions.

declare(strict_types=1);

require_once __DIR__ . '/security.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
    json_response(['error' => 'Method not allowed'], 405);
}

try {
    handle_login();
} catch (Throwable $e) {
    error_log('login.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    json_response(['error' => 'Server error: ' . $e->getMessage()], 500);
}

function handle_login(): void {
    tyches_start_session();

    // NOTE: We intentionally do NOT enforce CSRF on the login endpoint.
    // Some hosting/CDN setups were causing the CSRF token header to get
    // out of sync with the PHP session, which blocked users from logging in
    // with a "CSRF token mismatch" error.
    //
    // Login is still protected by:
    //  - Same‑origin cookies (credentials: 'same-origin' in fetch)
    //  - Strong rate limiting per IP
    //
    // If you later want to re‑enable strict CSRF here, make sure that:
    //  - The <meta name="csrf-token"> value is never cached across users, and
    //  - The PHP session cookie is shared correctly between index.php and /api/.

    // Rate limiting for login POST
    $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    tyches_require_rate_limit('login:' . $ip, 5, 60); // 5 attempts per minute per IP

    $raw  = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        $data = $_POST;
    }

    $email    = sanitize_string($data['email'] ?? '', 255);
    $password = (string)($data['password'] ?? '');

    if ($email === '' || $password === '') {
        json_response(['error' => 'Email and password are required'], 400);
    }

    $pdo = get_pdo();

    $sql = 'SELECT id, name, username, email, phone, password_hash, email_verified_at, is_admin, status, created_at
            FROM users
            WHERE email = :email
            LIMIT 1';
    $stmt = $pdo->prepare($sql);
    $stmt->execute([':email' => $email]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['password_hash'])) {
        json_response(['error' => 'Invalid email or password'], 401);
    }

    // Allow unverified users to login - they can browse but not take actions
    // Email verification is now required only for creating markets, events, and placing bets

    if (($user['status'] ?? 'active') !== 'active') {
        json_response(['error' => 'Your account is not active. Please contact support.'], 403);
    }

    // Regenerate session ID on successful login to prevent fixation.
    session_regenerate_id(true);

    $_SESSION['user_id'] = (int)$user['id'];

    unset($user['password_hash']);

    json_response(['user' => $user], 200);
}





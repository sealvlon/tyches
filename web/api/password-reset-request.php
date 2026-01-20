<?php
// api/password-reset-request.php
// Request a password reset link via email.
//
// POST JSON:
//   { "email": string }
//
// Always responds with a generic success message to avoid email enumeration.

declare(strict_types=1);

require_once __DIR__ . '/security.php';
require_once __DIR__ . '/mailer.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method !== 'POST') {
    json_response(['error' => 'Method not allowed'], 405);
}

try {
    handle_password_reset_request();
} catch (Throwable $e) {
    error_log('password-reset-request.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    // Generic error, do not leak details
    json_response(['error' => 'Server error'], 500);
}

function handle_password_reset_request(): void {
    // CSRF + rate limiting on reset requests
    tyches_require_csrf();
    $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    tyches_require_rate_limit('password_reset_request:' . $ip, 5, 3600); // 5 per hour per IP

    $raw  = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        $data = $_POST;
    }

    $email = sanitize_string($data['email'] ?? '', 255);
    if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        // Generic response: do not reveal whether the email exists.
        json_response(['ok' => true]);
    }

    $pdo = get_pdo();

    $stmt = $pdo->prepare(
        'SELECT id, name, email_verified_at
         FROM users
         WHERE email = :email
         LIMIT 1'
    );
    $stmt->execute([':email' => $email]);
    $user = $stmt->fetch();

    // Always return generic success to prevent enumeration.
    if (!$user) {
        json_response(['ok' => true]);
    }

    // Only send reset link for verified users; others get same generic response.
    if ($user['email_verified_at'] === null) {
        json_response(['ok' => true]);
    }

    // Reuse verification_token column for reset tokens.
    $token = bin2hex(random_bytes(32));

    $stmtUpd = $pdo->prepare(
        'UPDATE users
         SET verification_token = :token
         WHERE id = :id
         LIMIT 1'
    );
    $stmtUpd->execute([
        ':token' => $token,
        ':id'    => (int)$user['id'],
    ]);

    // Build reset URL pointing to /reset-password.php at the app root.
    $scheme   = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host     = $_SERVER['HTTP_HOST'] ?? 'example.com';
    $script   = $_SERVER['SCRIPT_NAME'] ?? '';   // e.g. /tyches/api/password-reset-request.php
    $apiDir   = rtrim(dirname($script), '/\\');  // e.g. /tyches/api
    $basePath = rtrim(dirname($apiDir), '/\\');  // e.g. /tyches

    $resetUrl = sprintf(
        '%s://%s%s/reset-password.php?token=%s',
        $scheme,
        $host,
        $basePath,
        urlencode($token)
    );

    $name = $user['name'] ?? 'there';
    
    // Send password reset email using new mailer
    send_password_reset_email($email, $name, $token);

    json_response(['ok' => true]);
}



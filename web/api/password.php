<?php
// api/password.php
// Change password for the currently authenticated user.
//
// POST JSON:
//   {
//     "current_password": string,
//     "new_password": string,
//     "new_password_confirmation": string
//   }

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
    handle_change_password();
} catch (Throwable $e) {
    error_log('password.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    json_response(['error' => 'Server error'], 500);
}

function handle_change_password(): void {
    // Auth + CSRF
    $uid = require_auth();
    tyches_require_csrf();

    // Rate limit password change attempts per user
    tyches_require_rate_limit('password_change:user:' . $uid, 3, 600); // 3 per 10 minutes
    $pdo = get_pdo();

    $raw  = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        $data = $_POST;
    }

    $current = (string)($data['current_password'] ?? '');
    $new     = (string)($data['new_password'] ?? '');
    $confirm = (string)($data['new_password_confirmation'] ?? '');

    if ($current === '' || $new === '') {
        json_response(['error' => 'Current and new password are required'], 400);
    }

    if ($new !== $confirm) {
        json_response(['error' => 'New passwords do not match'], 400);
    }

    if (strlen($new) < 8) {
        json_response(['error' => 'New password must be at least 8 characters'], 400);
    }

    // Load current password hash
    $stmt = $pdo->prepare(
        'SELECT password_hash
         FROM users
         WHERE id = :id
         LIMIT 1'
    );
    $stmt->execute([':id' => $uid]);
    $row = $stmt->fetch();
    if (!$row) {
        json_response(['error' => 'User not found'], 404);
    }

    if (!password_verify($current, (string)$row['password_hash'])) {
        json_response(['error' => 'Current password is incorrect'], 400);
    }

    $newHash = password_hash($new, PASSWORD_DEFAULT);

    $stmtUpd = $pdo->prepare(
        'UPDATE users
         SET password_hash = :hash
         WHERE id = :id
         LIMIT 1'
    );
    $stmtUpd->execute([
        ':hash' => $newHash,
        ':id'   => $uid,
    ]);

    // Regenerate session ID after sensitive change
    tyches_start_session();
    session_regenerate_id(true);

    json_response(['ok' => true], 200);
}



<?php
// api/csrf.php
// Get CSRF token for the current session (for mobile clients)

declare(strict_types=1);

require_once __DIR__ . '/security.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
    json_response(['error' => 'Method not allowed'], 405);
}

try {
    tyches_start_session();
    $token = tyches_get_csrf_token();
    json_response(['csrf_token' => $token]);
} catch (Throwable $e) {
    error_log('csrf.php error: ' . $e->getMessage());
    json_response(['error' => 'Server error'], 500);
}


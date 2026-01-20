<?php
// api/security.php
// CSRF helpers and security utilities for Tyches (including rate limiting).

declare(strict_types=1);

require_once __DIR__ . '/helpers.php';

/**
 * Get or generate the CSRF token for the current session.
 *
 * Safe to call from templates (index.php, profile.php, etc.).
 */
function tyches_get_csrf_token(): string {
    tyches_start_session();
    if (empty($_SESSION['csrf_token']) || !is_string($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

/**
 * Enforce CSRF protection for state‑changing requests.
 *
 * Accepts either:
 *  - X-CSRF-Token header (for fetch/XHR)
 *  - _csrf POST field (for HTML forms)
 *
 * Responds with 419 on failure.
 */
function tyches_require_csrf(): void {
    // Only enforce for unsafe methods.
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if (!in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE'], true)) {
        return;
    }

    tyches_start_session();
    $expected = $_SESSION['csrf_token'] ?? '';
    if (!is_string($expected) || $expected === '') {
        json_response(['error' => 'Invalid session'], 419);
    }

    $headerToken = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '';
    $postToken   = $_POST['_csrf'] ?? '';

    $provided = is_string($headerToken) && $headerToken !== ''
        ? $headerToken
        : (is_string($postToken) ? $postToken : '');

    if ($provided === '' || !hash_equals($expected, $provided)) {
        json_response(['error' => 'CSRF token mismatch'], 419);
    }
}
/**
 * Simple file-based rate limiting helper.
 *
 * Usage:
 *   // Allow max 5 login attempts per minute per IP
 *   tyches_require_rate_limit('login:' . $ip, 5, 60);
 *
 * Keys are arbitrary strings; values are stored in a temp dir and
 * automatically expire after $windowSeconds.
 */
function tyches_require_rate_limit(string $key, int $maxAttempts, int $windowSeconds): void {
    if ($maxAttempts <= 0 || $windowSeconds <= 0) {
        return; // Misconfigured; fail open rather than blocking everyone.
    }

    $dir = sys_get_temp_dir() . '/tyches_ratelimit';
    if (!is_dir($dir)) {
        @mkdir($dir, 0700, true);
    }

    $file = $dir . '/' . md5($key) . '.json';
    $now  = time();
    $data = [];

    if (is_file($file)) {
        $raw = @file_get_contents($file);
        if (is_string($raw) && $raw !== '') {
            $decoded = json_decode($raw, true);
            if (is_array($decoded)) {
                $data = $decoded;
            }
        }
    }

    // Drop timestamps outside the window
    $threshold = $now - $windowSeconds;
    $filtered  = [];
    foreach ($data as $ts) {
        if (is_int($ts) && $ts > $threshold) {
            $filtered[] = $ts;
        }
    }

    if (count($filtered) >= $maxAttempts) {
        json_response(['error' => 'Too many requests. Please wait and try again.'], 429);
    }

    // Record this attempt and overwrite the file
    $filtered[] = $now;
    @file_put_contents($file, json_encode($filtered), LOCK_EX);
}


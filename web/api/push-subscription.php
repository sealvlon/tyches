<?php
// api/push-subscription.php
// Manage push notification subscriptions

declare(strict_types=1);

require_once __DIR__ . '/helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method !== 'POST') {
    json_response(['error' => 'Method not allowed'], 405);
}

try {
    handle_push_subscription();
} catch (Throwable $e) {
    error_log('push-subscription.php error: ' . $e->getMessage());
    json_response(['error' => 'Server error'], 500);
}

function handle_push_subscription(): void {
    tyches_require_csrf();
    $userId = require_auth();
    $pdo = get_pdo();
    
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    
    $action = $data['action'] ?? 'subscribe';
    
    if ($action === 'subscribe') {
        $subscription = $data['subscription'] ?? null;
        
        if (!$subscription || !isset($subscription['endpoint'])) {
            json_response(['error' => 'Invalid subscription'], 400);
        }
        
        $endpoint = $subscription['endpoint'];
        $keys = $subscription['keys'] ?? [];
        $p256dh = $keys['p256dh'] ?? '';
        $auth = $keys['auth'] ?? '';
        
        if (!$endpoint || !$p256dh || !$auth) {
            json_response(['error' => 'Missing subscription keys'], 400);
        }
        
        // Insert or update subscription
        $stmt = $pdo->prepare('
            INSERT INTO push_subscriptions (user_id, endpoint, p256dh_key, auth_key)
            VALUES (:uid, :endpoint, :p256dh, :auth)
            ON DUPLICATE KEY UPDATE
                user_id = VALUES(user_id),
                p256dh_key = VALUES(p256dh_key),
                auth_key = VALUES(auth_key),
                created_at = NOW()
        ');
        $stmt->execute([
            ':uid' => $userId,
            ':endpoint' => $endpoint,
            ':p256dh' => $p256dh,
            ':auth' => $auth,
        ]);
        
        json_response(['ok' => true, 'message' => 'Subscription saved']);
        
    } elseif ($action === 'unsubscribe') {
        $endpoint = $data['endpoint'] ?? '';
        
        if (!$endpoint) {
            json_response(['error' => 'Endpoint required'], 400);
        }
        
        $stmt = $pdo->prepare('
            DELETE FROM push_subscriptions 
            WHERE user_id = :uid AND endpoint = :endpoint
        ');
        $stmt->execute([':uid' => $userId, ':endpoint' => $endpoint]);
        
        json_response(['ok' => true, 'message' => 'Unsubscribed']);
        
    } else {
        json_response(['error' => 'Invalid action'], 400);
    }
}

// ============================================
// PUSH NOTIFICATION SENDING
// ============================================

/**
 * Send push notification to a user
 * Note: Requires web-push library for production
 */
function send_push_notification(PDO $pdo, int $userId, array $payload): void {
    $stmt = $pdo->prepare('
        SELECT endpoint, p256dh_key, auth_key
        FROM push_subscriptions
        WHERE user_id = :uid
    ');
    $stmt->execute([':uid' => $userId]);
    $subscriptions = $stmt->fetchAll();
    
    foreach ($subscriptions as $sub) {
        try {
            sendPushToEndpoint(
                $sub['endpoint'],
                $sub['p256dh_key'],
                $sub['auth_key'],
                $payload
            );
        } catch (Throwable $e) {
            error_log("Push notification failed: " . $e->getMessage());
            
            // Remove invalid subscription
            if (strpos($e->getMessage(), '410') !== false || 
                strpos($e->getMessage(), '404') !== false) {
                $stmt = $pdo->prepare('DELETE FROM push_subscriptions WHERE endpoint = :endpoint');
                $stmt->execute([':endpoint' => $sub['endpoint']]);
            }
        }
    }
}

/**
 * Send push to a specific endpoint
 * Simplified implementation - production should use web-push library
 */
function sendPushToEndpoint(string $endpoint, string $p256dh, string $auth, array $payload): void {
    // This is a placeholder - proper implementation requires:
    // 1. VAPID keys
    // 2. Encryption of payload
    // 3. Proper JWT for authorization
    
    // For now, we'll just log the attempt
    error_log("Would send push to: " . substr($endpoint, 0, 50) . "...");
    error_log("Payload: " . json_encode($payload));
    
    // In production, use the web-push PHP library:
    // composer require minishlink/web-push
    /*
    use Minishlink\WebPush\WebPush;
    use Minishlink\WebPush\Subscription;
    
    $webPush = new WebPush([
        'VAPID' => [
            'subject' => 'mailto:your@email.com',
            'publicKey' => 'YOUR_VAPID_PUBLIC_KEY',
            'privateKey' => 'YOUR_VAPID_PRIVATE_KEY',
        ],
    ]);
    
    $subscription = Subscription::create([
        'endpoint' => $endpoint,
        'keys' => [
            'p256dh' => $p256dh,
            'auth' => $auth,
        ],
    ]);
    
    $webPush->sendOneNotification($subscription, json_encode($payload));
    */
}


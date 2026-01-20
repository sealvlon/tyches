<?php
/**
 * api/delete-account.php
 * Handle account deletion requests
 * Requires password confirmation for security
 */

declare(strict_types=1);

require_once __DIR__ . '/security.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['error' => 'Method not allowed'], 405);
}

try {
    $pdo = get_pdo();
    
    // Require authenticated user
    $userId = require_auth();
    
    // CSRF protection
    tyches_require_csrf();
    
    // Rate limit: 3 deletion attempts per hour
    $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    tyches_require_rate_limit("delete_account:{$userId}:{$ip}", 3, 3600);
    
    // Get request data
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        $data = $_POST;
    }
    
    $password = $data['password'] ?? '';
    $confirmation = $data['confirmation'] ?? '';
    
    // Validate confirmation text
    if ($confirmation !== 'DELETE') {
        json_response(['error' => 'Please type DELETE to confirm'], 400);
    }
    
    // Validate password
    if ($password === '') {
        json_response(['error' => 'Password is required'], 400);
    }
    
    // Verify password
    $stmt = $pdo->prepare('SELECT password_hash FROM users WHERE id = :id');
    $stmt->execute([':id' => $userId]);
    $row = $stmt->fetch();
    
    if (!$row || !password_verify($password, $row['password_hash'])) {
        json_response(['error' => 'Incorrect password'], 401);
    }
    
    // Begin transaction for safe deletion
    $pdo->beginTransaction();
    
    try {
        // Helper to safely delete from a table (ignores if table doesn't exist)
        $safeDelete = function($table, $column = 'user_id') use ($pdo, $userId) {
            try {
                $stmt = $pdo->prepare("DELETE FROM {$table} WHERE {$column} = :id");
                $stmt->execute([':id' => $userId]);
            } catch (PDOException $e) {
                // Table might not exist - ignore
            }
        };
        
        // Delete user's related data
        $safeDelete('gossip');
        $safeDelete('bets');
        $safeDelete('resolution_votes');
        $safeDelete('resolution_disputes');
        $safeDelete('notifications');
        $safeDelete('push_subscriptions');
        $safeDelete('user_notes');
        $safeDelete('market_members');
        $safeDelete('event_participants');
        $safeDelete('event_hosts');
        
        // Delete friendships (both directions)
        try {
            $stmt = $pdo->prepare('DELETE FROM friends WHERE user_id = :id OR friend_user_id = :id');
            $stmt->execute([':id' => $userId]);
        } catch (PDOException $e) {}
        
        // Handle events created by user
        // Delete events with no bets
        try {
            $stmt = $pdo->prepare('
                DELETE FROM events 
                WHERE creator_id = :id 
                AND id NOT IN (SELECT DISTINCT event_id FROM bets WHERE event_id IS NOT NULL)
            ');
            $stmt->execute([':id' => $userId]);
        } catch (PDOException $e) {}
        
        // Handle markets owned by user
        // Transfer ownership to another member or delete if empty
        try {
            $stmt = $pdo->prepare('
                SELECT m.id, 
                       (SELECT user_id FROM market_members WHERE market_id = m.id AND user_id != :uid LIMIT 1) as new_owner
                FROM markets m 
                WHERE m.owner_id = :uid
            ');
            $stmt->execute([':uid' => $userId]);
            $markets = $stmt->fetchAll();
            
            foreach ($markets as $market) {
                if ($market['new_owner']) {
                    // Transfer to another member
                    $stmt = $pdo->prepare('UPDATE markets SET owner_id = :new_owner WHERE id = :id');
                    $stmt->execute([':new_owner' => $market['new_owner'], ':id' => $market['id']]);
                    
                    // Update their role to owner
                    $stmt = $pdo->prepare('UPDATE market_members SET role = "owner" WHERE market_id = :mid AND user_id = :uid');
                    $stmt->execute([':mid' => $market['id'], ':uid' => $market['new_owner']]);
                } else {
                    // No other members, delete the market (cascades to events)
                    $stmt = $pdo->prepare('DELETE FROM markets WHERE id = :id');
                    $stmt->execute([':id' => $market['id']]);
                }
            }
        } catch (PDOException $e) {}
        
        // Delete password reset tokens
        $safeDelete('password_reset_tokens');
        
        // Finally, delete the user
        $stmt = $pdo->prepare('DELETE FROM users WHERE id = :id');
        $stmt->execute([':id' => $userId]);
        
        $pdo->commit();
        
        // Destroy session
        session_destroy();
        
        // Log the deletion
        error_log("Account deleted: user_id={$userId}, ip={$ip}");
        
        json_response([
            'success' => true,
            'message' => 'Your account has been permanently deleted.'
        ]);
        
    } catch (Throwable $e) {
        $pdo->rollBack();
        throw $e;
    }
    
} catch (Throwable $e) {
    error_log('delete-account.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    json_response(['error' => 'Failed to delete account. Please try again or contact support.'], 500);
}


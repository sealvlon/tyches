<?php
/**
 * Admin Nuclear Reset API
 * 
 * DANGER: This endpoint completely wipes the database except for user ID = 1.
 * Only accessible by admin users with user ID = 1.
 * 
 * POST /api/admin-reset.php
 * Required body: { action: "nuclear_reset", confirmation: "RESET_ALL_DATA" }
 */

declare(strict_types=1);

require_once __DIR__ . '/security.php';
require_once __DIR__ . '/admin-audit.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method !== 'POST') {
    json_response(['error' => 'Method not allowed'], 405);
}

try {
    $pdo = get_pdo();
    $admin = require_admin($pdo);
    
    // EXTRA SECURITY: Only user ID = 1 can perform nuclear reset
    if ((int)$admin['id'] !== 1) {
        json_response(['error' => 'Only the primary administrator (ID=1) can perform a nuclear reset'], 403);
    }
    
    // CSRF protection
    tyches_require_csrf();
    
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        $data = $_POST;
    }
    
    $action = sanitize_string($data['action'] ?? '', 32);
    $confirmation = sanitize_string($data['confirmation'] ?? '', 64);
    
    if ($action !== 'nuclear_reset') {
        json_response(['error' => 'Invalid action'], 400);
    }
    
    // Require exact confirmation string to prevent accidents
    if ($confirmation !== 'RESET_ALL_DATA') {
        json_response(['error' => 'Invalid confirmation code. Send confirmation: "RESET_ALL_DATA"'], 400);
    }
    
    // Start transaction for safety
    $pdo->beginTransaction();
    
    try {
        // Disable foreign key checks temporarily
        $pdo->exec('SET FOREIGN_KEY_CHECKS = 0');
        
        // Helper function to safely delete from table (handles non-existent tables)
        $safeDelete = function(string $table, string $where = '') use ($pdo) {
            try {
                $sql = $where ? "DELETE FROM {$table} WHERE {$where}" : "DELETE FROM {$table}";
                return (int)$pdo->exec($sql);
            } catch (PDOException $e) {
                // Table doesn't exist, that's OK
                error_log("admin-reset: Table {$table} may not exist: " . $e->getMessage());
                return 0;
            }
        };
        
        // === DELETE DATA (order matters for foreign keys) ===
        
        // 1. Delete all bets
        $deletedBets = $safeDelete('bets');
        
        // 2. Delete all gossip/comments
        $deletedGossip = $safeDelete('gossip');
        
        // 3. Delete all resolution votes
        $safeDelete('resolution_votes');
        
        // 4. Delete all resolution disputes
        $safeDelete('resolution_disputes');
        
        // 5. Delete all event participants (may not exist)
        $safeDelete('event_participants');
        
        // 6. Delete all event hosts (may not exist)
        $safeDelete('event_hosts');
        
        // 7. Delete all events
        $deletedEvents = $safeDelete('events');
        
        // 8. Delete all market members
        $safeDelete('market_members');
        
        // 9. Delete all markets
        $deletedMarkets = $safeDelete('markets');
        
        // 10. Delete all friendships
        $safeDelete('friends');
        
        // 11. Delete all notifications
        $safeDelete('notifications');
        
        // 12. Delete all push subscriptions
        $safeDelete('push_subscriptions');
        
        // 13. Delete all password reset tokens
        $safeDelete('password_reset_tokens');
        
        // 14. Delete all user notes (except notes about user 1)
        $safeDelete('user_notes', 'user_id != 1');
        
        // 15. Delete all user achievements (gamification - may not exist)
        $safeDelete('user_achievements');
        
        // 16. Delete all user streaks (gamification - may not exist)
        $safeDelete('user_streaks');
        
        // 17. Delete all user daily challenges (gamification - may not exist)
        $safeDelete('user_daily_challenges');
        
        // 18. Delete all users EXCEPT user ID = 1
        $deletedUsers = $safeDelete('users', 'id != 1');
        
        // 19. Reset user 1's tokens to default
        $pdo->exec('UPDATE users SET tokens_balance = 10000 WHERE id = 1');
        
        // Re-enable foreign key checks
        $pdo->exec('SET FOREIGN_KEY_CHECKS = 1');
        
        // Log the action
        logAdminAction($pdo, 'nuclear_reset', 'system', 'all', 
            "Nuclear reset performed. Deleted: {$deletedUsers} users, {$deletedMarkets} markets, {$deletedEvents} events, {$deletedBets} bets, {$deletedGossip} gossip messages");
        
        $pdo->commit();
        
        json_response([
            'ok' => true,
            'message' => 'Nuclear reset complete. All data has been wiped except your admin account.',
            'deleted' => [
                'users' => (int)$deletedUsers,
                'markets' => (int)$deletedMarkets,
                'events' => (int)$deletedEvents,
                'bets' => (int)$deletedBets,
                'gossip' => (int)$deletedGossip,
            ],
        ]);
        
    } catch (Throwable $e) {
        $pdo->rollBack();
        $pdo->exec('SET FOREIGN_KEY_CHECKS = 1'); // Re-enable just in case
        throw $e;
    }
    
} catch (Throwable $e) {
    error_log('admin-reset.php error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    json_response(['error' => 'Server error: ' . $e->getMessage()], 500);
}


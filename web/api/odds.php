<?php
/**
 * Odds API - Get current odds and pool sizes for events
 * 
 * GET /api/odds.php?event_id=X - Get odds for single event
 * GET /api/odds.php?event_ids=1,2,3 - Get odds for multiple events
 * 
 * Parimutuel odds are calculated from pool sizes:
 * - Odds = total_pool / side_pool
 * - Implied probability = side_pool / total_pool
 */

declare(strict_types=1);

require_once __DIR__ . '/security.php';
require_once __DIR__ . '/pools.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['error' => 'Method not allowed'], 405);
}

try {
    $uid = require_auth();
    $pdo = get_pdo();
    
    $eventId = isset($_GET['event_id']) ? (int)$_GET['event_id'] : 0;
    $eventIds = isset($_GET['event_ids']) ? array_map('intval', explode(',', $_GET['event_ids'])) : [];
    
    if ($eventId > 0) {
        // Single event
        $odds = calculate_event_odds($pdo, $eventId);
        $position = get_potential_payout($pdo, $eventId, $uid);
        
        json_response([
            'event_id' => $eventId,
            'odds' => $odds,
            'your_position' => $position,
        ]);
    } elseif (!empty($eventIds)) {
        // Multiple events
        $results = [];
        foreach ($eventIds as $eid) {
            if ($eid > 0) {
                $results[$eid] = calculate_event_odds($pdo, $eid);
            }
        }
        
        json_response([
            'odds' => $results,
        ]);
    } else {
        json_response(['error' => 'event_id or event_ids required'], 400);
    }
    
} catch (Throwable $e) {
    error_log('odds.php error: ' . $e->getMessage());
    json_response(['error' => 'Server error'], 500);
}


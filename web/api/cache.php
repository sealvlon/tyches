<?php
// api/cache.php
// Simple file-based caching layer for performance

declare(strict_types=1);

// Cache configuration
define('CACHE_DIR', sys_get_temp_dir() . '/tyches_cache');
define('CACHE_DEFAULT_TTL', 300); // 5 minutes

/**
 * Initialize cache directory
 */
function cache_init(): void {
    if (!is_dir(CACHE_DIR)) {
        @mkdir(CACHE_DIR, 0755, true);
    }
}

/**
 * Get cached value
 * 
 * @param string $key Cache key
 * @return mixed|null Cached value or null if not found/expired
 */
function cache_get(string $key) {
    cache_init();
    
    $file = CACHE_DIR . '/' . md5($key) . '.cache';
    
    if (!is_file($file)) {
        return null;
    }
    
    $content = @file_get_contents($file);
    if ($content === false) {
        return null;
    }
    
    $data = @unserialize($content);
    if ($data === false || !is_array($data)) {
        return null;
    }
    
    // Check expiration
    if (isset($data['expires']) && time() > $data['expires']) {
        @unlink($file);
        return null;
    }
    
    return $data['value'] ?? null;
}

/**
 * Set cached value
 * 
 * @param string $key Cache key
 * @param mixed $value Value to cache
 * @param int $ttl Time to live in seconds
 * @return bool Success
 */
function cache_set(string $key, $value, int $ttl = CACHE_DEFAULT_TTL): bool {
    cache_init();
    
    $file = CACHE_DIR . '/' . md5($key) . '.cache';
    
    $data = [
        'value' => $value,
        'expires' => $ttl > 0 ? time() + $ttl : 0,
        'created' => time(),
    ];
    
    return @file_put_contents($file, serialize($data), LOCK_EX) !== false;
}

/**
 * Delete cached value
 * 
 * @param string $key Cache key
 * @return bool Success
 */
function cache_delete(string $key): bool {
    $file = CACHE_DIR . '/' . md5($key) . '.cache';
    
    if (is_file($file)) {
        return @unlink($file);
    }
    
    return true;
}

/**
 * Clear all cache or by pattern
 * 
 * @param string|null $pattern Optional key pattern (not implemented for file cache)
 * @return int Number of items deleted
 */
function cache_clear(?string $pattern = null): int {
    cache_init();
    
    $count = 0;
    $files = glob(CACHE_DIR . '/*.cache');
    
    foreach ($files as $file) {
        if (@unlink($file)) {
            $count++;
        }
    }
    
    return $count;
}

/**
 * Get or set cached value (convenience method)
 * 
 * @param string $key Cache key
 * @param callable $callback Function to generate value if not cached
 * @param int $ttl Time to live in seconds
 * @return mixed Cached or generated value
 */
function cache_remember(string $key, callable $callback, int $ttl = CACHE_DEFAULT_TTL) {
    $value = cache_get($key);
    
    if ($value !== null) {
        return $value;
    }
    
    $value = $callback();
    cache_set($key, $value, $ttl);
    
    return $value;
}

/**
 * Cache database query results
 * 
 * @param PDO $pdo Database connection
 * @param string $sql SQL query
 * @param array $params Query parameters
 * @param int $ttl Cache TTL
 * @return array Query results
 */
function cache_query(PDO $pdo, string $sql, array $params = [], int $ttl = CACHE_DEFAULT_TTL): array {
    $key = 'query:' . md5($sql . json_encode($params));
    
    return cache_remember($key, function() use ($pdo, $sql, $params) {
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }, $ttl);
}

// ============================================
// QUERY OPTIMIZATION HELPERS
// ============================================

/**
 * Eager load related data to avoid N+1 queries
 */
function eager_load_events(PDO $pdo, array $eventIds): array {
    if (empty($eventIds)) {
        return [];
    }
    
    $cacheKey = 'events:' . md5(json_encode($eventIds));
    
    return cache_remember($cacheKey, function() use ($pdo, $eventIds) {
        $placeholders = implode(',', array_fill(0, count($eventIds), '?'));
        
        $stmt = $pdo->prepare("
            SELECT e.*, 
                   m.name AS market_name, 
                   m.avatar_emoji,
                   u.name AS creator_name,
                   u.username AS creator_username
            FROM events e
            INNER JOIN markets m ON m.id = e.market_id
            INNER JOIN users u ON u.id = e.creator_id
            WHERE e.id IN ({$placeholders})
        ");
        $stmt->execute($eventIds);
        
        $events = [];
        foreach ($stmt->fetchAll() as $row) {
            $events[(int)$row['id']] = $row;
        }
        
        return $events;
    }, 60);
}

/**
 * Eager load bets for events
 */
function eager_load_bets(PDO $pdo, array $eventIds): array {
    if (empty($eventIds)) {
        return [];
    }
    
    $placeholders = implode(',', array_fill(0, count($eventIds), '?'));
    
    $stmt = $pdo->prepare("
        SELECT b.*, u.name AS user_name, u.username AS user_username
        FROM bets b
        INNER JOIN users u ON u.id = b.user_id
        WHERE b.event_id IN ({$placeholders})
        ORDER BY b.created_at DESC
    ");
    $stmt->execute($eventIds);
    
    $betsByEvent = [];
    foreach ($stmt->fetchAll() as $row) {
        $eventId = (int)$row['event_id'];
        if (!isset($betsByEvent[$eventId])) {
            $betsByEvent[$eventId] = [];
        }
        $betsByEvent[$eventId][] = $row;
    }
    
    return $betsByEvent;
}

/**
 * Get aggregated stats with caching
 */
function get_cached_stats(PDO $pdo): array {
    return cache_remember('global_stats', function() use ($pdo) {
        $stats = [];
        
        // Total users
        $stmt = $pdo->query('SELECT COUNT(*) FROM users WHERE status = "active"');
        $stats['total_users'] = (int)$stmt->fetchColumn();
        
        // Total markets
        $stmt = $pdo->query('SELECT COUNT(*) FROM markets');
        $stats['total_markets'] = (int)$stmt->fetchColumn();
        
        // Total events
        $stmt = $pdo->query('SELECT COUNT(*) FROM events');
        $stats['total_events'] = (int)$stmt->fetchColumn();
        
        // Active events
        $stmt = $pdo->query('SELECT COUNT(*) FROM events WHERE status = "open"');
        $stats['active_events'] = (int)$stmt->fetchColumn();
        
        // Total volume
        $stmt = $pdo->query('SELECT COALESCE(SUM(notional), 0) FROM bets');
        $stats['total_volume'] = (float)$stmt->fetchColumn();
        
        // Total bets
        $stmt = $pdo->query('SELECT COUNT(*) FROM bets');
        $stats['total_bets'] = (int)$stmt->fetchColumn();
        
        return $stats;
    }, 300); // Cache for 5 minutes
}

/**
 * Invalidate cache for specific entities
 */
function invalidate_event_cache(int $eventId): void {
    cache_delete("event:{$eventId}");
    cache_delete("event_bets:{$eventId}");
    cache_delete("event_gossip:{$eventId}");
}

function invalidate_user_cache(int $userId): void {
    cache_delete("user:{$userId}");
    cache_delete("user_profile:{$userId}");
    cache_delete("user_bets:{$userId}");
}

function invalidate_market_cache(int $marketId): void {
    cache_delete("market:{$marketId}");
    cache_delete("market_events:{$marketId}");
    cache_delete("market_members:{$marketId}");
}


<?php
/**
 * Achievements API - User achievement tracking
 * GET: Fetch all achievements with user progress
 * POST: Update achievement progress or unlock
 */

declare(strict_types=1);

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/security.php';
require_once __DIR__ . '/helpers.php';

tyches_start_session();

// Require authentication
if (empty($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['error' => 'Authentication required']);
    exit;
}

$userId = (int) $_SESSION['user_id'];
$method = $_SERVER['REQUEST_METHOD'];

// Ensure achievements table exists
ensureAchievementsTable($pdo);

// Define all achievements
$allAchievements = [
    // Trading achievements
    ['id' => 'first_bet', 'name' => 'First Bet', 'description' => 'Place your first bet', 'emoji' => '🎯', 'category' => 'trading', 'requirement' => 1],
    ['id' => 'high_roller', 'name' => 'High Roller', 'description' => 'Place 50 bets', 'emoji' => '🎰', 'category' => 'trading', 'requirement' => 50],
    ['id' => 'whale', 'name' => 'Whale', 'description' => 'Bet 10,000 tokens total', 'emoji' => '🐋', 'category' => 'trading', 'requirement' => 10000],
    ['id' => 'diversified', 'name' => 'Diversified', 'description' => 'Bet on 10 different events', 'emoji' => '📊', 'category' => 'trading', 'requirement' => 10],
    
    // Prediction achievements
    ['id' => 'oracle', 'name' => 'Oracle', 'description' => 'Win 10 predictions', 'emoji' => '🔮', 'category' => 'prediction', 'requirement' => 10],
    ['id' => 'fortune_teller', 'name' => 'Fortune Teller', 'description' => 'Win 5 in a row', 'emoji' => '🌟', 'category' => 'prediction', 'requirement' => 5],
    ['id' => 'psychic', 'name' => 'Psychic', 'description' => 'Achieve 80% accuracy', 'emoji' => '🧠', 'category' => 'prediction', 'requirement' => 80],
    
    // Social achievements
    ['id' => 'social_butterfly', 'name' => 'Social Butterfly', 'description' => 'Add 5 friends', 'emoji' => '🦋', 'category' => 'social', 'requirement' => 5],
    ['id' => 'gossip_queen', 'name' => 'Gossip Queen', 'description' => 'Post 20 gossip messages', 'emoji' => '💬', 'category' => 'social', 'requirement' => 20],
    ['id' => 'event_creator', 'name' => 'Event Creator', 'description' => 'Create your first event', 'emoji' => '✨', 'category' => 'social', 'requirement' => 1],
    ['id' => 'market_maker', 'name' => 'Market Maker', 'description' => 'Create a market', 'emoji' => '🏛️', 'category' => 'social', 'requirement' => 1],
    
    // Streak achievements
    ['id' => 'week_warrior', 'name' => 'Week Warrior', 'description' => '7 day streak', 'emoji' => '🗓️', 'category' => 'streak', 'requirement' => 7],
    ['id' => 'monthly_master', 'name' => 'Monthly Master', 'description' => '30 day streak', 'emoji' => '📅', 'category' => 'streak', 'requirement' => 30],
    ['id' => 'year_legend', 'name' => 'Year Legend', 'description' => '365 day streak', 'emoji' => '🏆', 'category' => 'streak', 'requirement' => 365],
    
    // Special achievements
    ['id' => 'early_adopter', 'name' => 'Early Adopter', 'description' => 'Join Tyches in 2024', 'emoji' => '🚀', 'category' => 'special', 'requirement' => 1],
    ['id' => 'perfect_week', 'name' => 'Perfect Week', 'description' => 'Bet every day for a week', 'emoji' => '💎', 'category' => 'special', 'requirement' => 7],
];

if ($method === 'GET') {
    // Fetch user's achievement progress
    $stmt = $pdo->prepare("
        SELECT achievement_id, progress, unlocked_at
        FROM user_achievements
        WHERE user_id = ?
    ");
    $stmt->execute([$userId]);
    $userProgress = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $progressMap = [];
    foreach ($userProgress as $p) {
        $progressMap[$p['achievement_id']] = [
            'progress' => (int) $p['progress'],
            'unlocked_at' => $p['unlocked_at']
        ];
    }
    
    // Calculate actual progress for some achievements from database
    $actualProgress = calculateActualProgress($pdo, $userId);
    
    // Merge with achievements
    $achievements = [];
    foreach ($allAchievements as $achievement) {
        $id = $achievement['id'];
        $progress = $actualProgress[$id] ?? ($progressMap[$id]['progress'] ?? 0);
        $unlockedAt = $progressMap[$id]['unlocked_at'] ?? null;
        
        // Auto-unlock if progress meets requirement
        if ($progress >= $achievement['requirement'] && !$unlockedAt) {
            $unlockedAt = date('Y-m-d H:i:s');
            $stmt = $pdo->prepare("
                INSERT INTO user_achievements (user_id, achievement_id, progress, unlocked_at)
                VALUES (?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE progress = ?, unlocked_at = COALESCE(unlocked_at, ?)
            ");
            $stmt->execute([$userId, $id, $progress, $unlockedAt, $progress, $unlockedAt]);
        }
        
        $achievements[] = [
            'id' => $achievement['id'],
            'name' => $achievement['name'],
            'description' => $achievement['description'],
            'emoji' => $achievement['emoji'],
            'category' => $achievement['category'],
            'requirement' => $achievement['requirement'],
            'progress' => $progress,
            'is_unlocked' => $unlockedAt !== null,
            'unlocked_at' => $unlockedAt
        ];
    }
    
    // Calculate summary
    $unlocked = array_filter($achievements, fn($a) => $a['is_unlocked']);
    
    echo json_encode([
        'achievements' => $achievements,
        'total' => count($achievements),
        'unlocked' => count($unlocked),
        'categories' => ['trading', 'prediction', 'social', 'streak', 'special']
    ]);
    exit;
}

if ($method === 'POST') {
    // Update achievement progress
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (empty($input['achievement_id'])) {
        http_response_code(400);
        echo json_encode(['error' => 'achievement_id required']);
        exit;
    }
    
    $achievementId = $input['achievement_id'];
    $incrementBy = (int) ($input['increment'] ?? 1);
    
    // Find achievement definition
    $achievement = null;
    foreach ($allAchievements as $a) {
        if ($a['id'] === $achievementId) {
            $achievement = $a;
            break;
        }
    }
    
    if (!$achievement) {
        http_response_code(404);
        echo json_encode(['error' => 'Achievement not found']);
        exit;
    }
    
    // Update or insert progress
    $stmt = $pdo->prepare("
        INSERT INTO user_achievements (user_id, achievement_id, progress)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE progress = progress + ?
    ");
    $stmt->execute([$userId, $achievementId, $incrementBy, $incrementBy]);
    
    // Check if unlocked
    $stmt = $pdo->prepare("SELECT progress, unlocked_at FROM user_achievements WHERE user_id = ? AND achievement_id = ?");
    $stmt->execute([$userId, $achievementId]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    $progress = (int) $result['progress'];
    $justUnlocked = false;
    
    if ($progress >= $achievement['requirement'] && !$result['unlocked_at']) {
        $stmt = $pdo->prepare("UPDATE user_achievements SET unlocked_at = NOW() WHERE user_id = ? AND achievement_id = ?");
        $stmt->execute([$userId, $achievementId]);
        $justUnlocked = true;
        
        // Award XP for unlocking
        $stmt = $pdo->prepare("UPDATE users SET xp = xp + 50 WHERE id = ?");
        $stmt->execute([$userId]);
    }
    
    echo json_encode([
        'achievement_id' => $achievementId,
        'progress' => $progress,
        'requirement' => $achievement['requirement'],
        'is_unlocked' => $progress >= $achievement['requirement'],
        'just_unlocked' => $justUnlocked
    ]);
    exit;
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);

// Helper functions
function ensureAchievementsTable(PDO $pdo): void {
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS user_achievements (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            achievement_id VARCHAR(50) NOT NULL,
            progress INT DEFAULT 0,
            unlocked_at DATETIME,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY unique_user_achievement (user_id, achievement_id)
        )
    ");
}

function calculateActualProgress(PDO $pdo, int $userId): array {
    $progress = [];
    
    // Count total bets
    $stmt = $pdo->prepare("SELECT COUNT(*) FROM bets WHERE user_id = ?");
    $stmt->execute([$userId]);
    $totalBets = (int) $stmt->fetchColumn();
    $progress['first_bet'] = min($totalBets, 1);
    $progress['high_roller'] = $totalBets;
    
    // Count total tokens bet
    $stmt = $pdo->prepare("SELECT COALESCE(SUM(notional), 0) FROM bets WHERE user_id = ?");
    $stmt->execute([$userId]);
    $progress['whale'] = (int) $stmt->fetchColumn();
    
    // Count unique events bet on
    $stmt = $pdo->prepare("SELECT COUNT(DISTINCT event_id) FROM bets WHERE user_id = ?");
    $stmt->execute([$userId]);
    $progress['diversified'] = (int) $stmt->fetchColumn();
    
    // Count wins (resolved bets where user's side won)
    $stmt = $pdo->prepare("
        SELECT COUNT(*) FROM bets b
        JOIN events e ON b.event_id = e.id
        WHERE b.user_id = ? 
        AND e.status = 'resolved'
        AND ((b.side = 'YES' AND e.winning_side = 'YES') OR (b.side = 'NO' AND e.winning_side = 'NO'))
    ");
    $stmt->execute([$userId]);
    $progress['oracle'] = (int) $stmt->fetchColumn();
    
    // Count friends
    $stmt = $pdo->prepare("SELECT COUNT(*) FROM friendships WHERE (user_id = ? OR friend_id = ?) AND status = 'accepted'");
    $stmt->execute([$userId, $userId]);
    $progress['social_butterfly'] = (int) $stmt->fetchColumn();
    
    // Count gossip messages
    $stmt = $pdo->prepare("SELECT COUNT(*) FROM gossip WHERE user_id = ?");
    $stmt->execute([$userId]);
    $progress['gossip_queen'] = (int) $stmt->fetchColumn();
    
    // Count events created
    $stmt = $pdo->prepare("SELECT COUNT(*) FROM events WHERE creator_id = ?");
    $stmt->execute([$userId]);
    $eventsCreated = (int) $stmt->fetchColumn();
    $progress['event_creator'] = min($eventsCreated, 1);
    
    // Count markets created
    $stmt = $pdo->prepare("SELECT COUNT(*) FROM markets WHERE owner_id = ?");
    $stmt->execute([$userId]);
    $marketsCreated = (int) $stmt->fetchColumn();
    $progress['market_maker'] = min($marketsCreated, 1);
    
    // Check if early adopter (joined in 2024)
    $stmt = $pdo->prepare("SELECT created_at FROM users WHERE id = ?");
    $stmt->execute([$userId]);
    $createdAt = $stmt->fetchColumn();
    if ($createdAt && strpos($createdAt, '2024') === 0) {
        $progress['early_adopter'] = 1;
    }
    
    return $progress;
}


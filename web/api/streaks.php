<?php
/**
 * Streaks API - Gamification streak tracking
 * GET: Fetch user's streak data
 * POST: Record daily activity (call when user opens app)
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

// Ensure streaks table exists
ensureStreaksTable($pdo);

if ($method === 'GET') {
    // Fetch user's streak data
    $stmt = $pdo->prepare("
        SELECT 
            current_streak,
            longest_streak,
            last_activity_date,
            total_days_active,
            weekly_activity
        FROM user_streaks
        WHERE user_id = ?
    ");
    $stmt->execute([$userId]);
    $streak = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$streak) {
        // Initialize streak for new user
        $streak = [
            'current_streak' => 0,
            'longest_streak' => 0,
            'last_activity_date' => null,
            'total_days_active' => 0,
            'weekly_activity' => json_encode([false, false, false, false, false, false, false])
        ];
        
        $stmt = $pdo->prepare("
            INSERT INTO user_streaks (user_id, current_streak, longest_streak, total_days_active, weekly_activity)
            VALUES (?, 0, 0, 0, ?)
        ");
        $stmt->execute([$userId, $streak['weekly_activity']]);
    }
    
    // Parse weekly activity
    $weeklyActivity = json_decode($streak['weekly_activity'] ?? '[]', true) ?: array_fill(0, 7, false);
    
    // Calculate streak status
    $isActiveToday = false;
    if ($streak['last_activity_date']) {
        $lastDate = new DateTime($streak['last_activity_date']);
        $today = new DateTime('today');
        $isActiveToday = $lastDate->format('Y-m-d') === $today->format('Y-m-d');
    }
    
    echo json_encode([
        'current_streak' => (int) $streak['current_streak'],
        'longest_streak' => (int) $streak['longest_streak'],
        'last_activity_date' => $streak['last_activity_date'],
        'total_days_active' => (int) $streak['total_days_active'],
        'weekly_activity' => $weeklyActivity,
        'is_active_today' => $isActiveToday,
        'streak_emoji' => getStreakEmoji((int) $streak['current_streak']),
        'streak_message' => getStreakMessage((int) $streak['current_streak'])
    ]);
    exit;
}

if ($method === 'POST') {
    // Record daily activity
    $today = date('Y-m-d');
    
    // Get current streak data
    $stmt = $pdo->prepare("SELECT * FROM user_streaks WHERE user_id = ?");
    $stmt->execute([$userId]);
    $streak = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$streak) {
        // Initialize new streak
        $stmt = $pdo->prepare("
            INSERT INTO user_streaks (user_id, current_streak, longest_streak, last_activity_date, total_days_active, weekly_activity)
            VALUES (?, 1, 1, ?, 1, ?)
        ");
        $weeklyActivity = array_fill(0, 6, false);
        $weeklyActivity[] = true;
        $stmt->execute([$userId, $today, json_encode($weeklyActivity)]);
        
        // Award XP for first activity
        awardXP($pdo, $userId, 10, 'daily_activity');
        
        echo json_encode([
            'current_streak' => 1,
            'longest_streak' => 1,
            'is_new_day' => true,
            'xp_awarded' => 10
        ]);
        exit;
    }
    
    $lastDate = $streak['last_activity_date'] ? new DateTime($streak['last_activity_date']) : null;
    $todayDate = new DateTime($today);
    $currentStreak = (int) $streak['current_streak'];
    $longestStreak = (int) $streak['longest_streak'];
    $totalDays = (int) $streak['total_days_active'];
    $weeklyActivity = json_decode($streak['weekly_activity'] ?? '[]', true) ?: array_fill(0, 7, false);
    
    $isNewDay = true;
    $xpAwarded = 0;
    
    if ($lastDate) {
        $daysDiff = (int) $todayDate->diff($lastDate)->days;
        
        if ($daysDiff === 0) {
            // Same day, no change
            $isNewDay = false;
        } elseif ($daysDiff === 1) {
            // Consecutive day - extend streak
            $currentStreak++;
            $longestStreak = max($longestStreak, $currentStreak);
            $totalDays++;
            $xpAwarded = 10 + min($currentStreak, 10); // Bonus XP for streak
            
            // Update weekly activity
            array_shift($weeklyActivity);
            $weeklyActivity[] = true;
        } else {
            // Streak broken - reset
            $currentStreak = 1;
            $totalDays++;
            $xpAwarded = 10;
            
            // Update weekly activity (shift by days missed + today)
            for ($i = 0; $i < min($daysDiff, 7); $i++) {
                array_shift($weeklyActivity);
                $weeklyActivity[] = ($i === $daysDiff - 1);
            }
        }
    }
    
    if ($isNewDay) {
        // Update database
        $stmt = $pdo->prepare("
            UPDATE user_streaks 
            SET current_streak = ?,
                longest_streak = ?,
                last_activity_date = ?,
                total_days_active = ?,
                weekly_activity = ?
            WHERE user_id = ?
        ");
        $stmt->execute([
            $currentStreak,
            $longestStreak,
            $today,
            $totalDays,
            json_encode($weeklyActivity),
            $userId
        ]);
        
        // Award XP
        if ($xpAwarded > 0) {
            awardXP($pdo, $userId, $xpAwarded, 'daily_activity');
        }
        
        // Check streak achievements
        checkStreakAchievements($pdo, $userId, $currentStreak);
    }
    
    echo json_encode([
        'current_streak' => $currentStreak,
        'longest_streak' => $longestStreak,
        'is_new_day' => $isNewDay,
        'xp_awarded' => $xpAwarded,
        'weekly_activity' => $weeklyActivity,
        'streak_emoji' => getStreakEmoji($currentStreak),
        'streak_message' => getStreakMessage($currentStreak)
    ]);
    exit;
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);

// Helper functions
function ensureStreaksTable(PDO $pdo): void {
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS user_streaks (
            user_id INT PRIMARY KEY,
            current_streak INT DEFAULT 0,
            longest_streak INT DEFAULT 0,
            last_activity_date DATE,
            total_days_active INT DEFAULT 0,
            weekly_activity JSON,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ");
}

function getStreakEmoji(int $streak): string {
    if ($streak >= 30) return "🔥🔥🔥";
    if ($streak >= 14) return "🔥🔥";
    if ($streak >= 7) return "🔥";
    if ($streak >= 3) return "✨";
    return "⚡️";
}

function getStreakMessage(int $streak): string {
    if ($streak >= 30) return "Legendary streak!";
    if ($streak >= 14) return "On fire!";
    if ($streak >= 7) return "Hot streak!";
    if ($streak >= 3) return "Keep it up!";
    if ($streak === 0) return "Start your streak!";
    return "Building momentum!";
}

function awardXP(PDO $pdo, int $userId, int $amount, string $source): void {
    // Ensure XP columns exist
    try {
        $pdo->exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS xp INT DEFAULT 0");
        $pdo->exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS level INT DEFAULT 1");
    } catch (Exception $e) {
        // Columns might already exist
    }
    
    $stmt = $pdo->prepare("UPDATE users SET xp = xp + ? WHERE id = ?");
    $stmt->execute([$amount, $userId]);
    
    // Recalculate level
    $stmt = $pdo->prepare("SELECT xp FROM users WHERE id = ?");
    $stmt->execute([$userId]);
    $xp = (int) $stmt->fetchColumn();
    
    $level = 1;
    $xpRequired = 500;
    while ($xp >= $xpRequired) {
        $level++;
        $xpRequired += 500;
    }
    
    $stmt = $pdo->prepare("UPDATE users SET level = ? WHERE id = ?");
    $stmt->execute([$level, $userId]);
}

function checkStreakAchievements(PDO $pdo, int $userId, int $streak): void {
    $achievements = [
        'week_warrior' => 7,
        'monthly_master' => 30,
        'year_legend' => 365
    ];
    
    foreach ($achievements as $achievementId => $required) {
        if ($streak >= $required) {
            // Unlock achievement if not already unlocked
            $stmt = $pdo->prepare("
                INSERT IGNORE INTO user_achievements (user_id, achievement_id, progress, unlocked_at)
                VALUES (?, ?, ?, NOW())
                ON DUPLICATE KEY UPDATE progress = GREATEST(progress, ?), unlocked_at = COALESCE(unlocked_at, NOW())
            ");
            $stmt->execute([$userId, $achievementId, $streak, $streak]);
        }
    }
}


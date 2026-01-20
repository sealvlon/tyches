<?php
/**
 * Daily Challenges API
 * GET: Fetch today's challenges with progress
 * POST: Update challenge progress
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
$today = date('Y-m-d');

// Ensure daily challenges table exists
ensureDailyChallengesTable($pdo);

// Define daily challenges
$dailyChallenges = [
    ['id' => 'daily_bet', 'title' => 'Daily Trader', 'description' => 'Place 3 bets today', 'emoji' => '📈', 'reward' => 100, 'target' => 3],
    ['id' => 'daily_gossip', 'title' => 'Chatterbox', 'description' => 'Post 2 gossip messages', 'emoji' => '💬', 'reward' => 50, 'target' => 2],
    ['id' => 'daily_explore', 'title' => 'Explorer', 'description' => 'View 5 different events', 'emoji' => '🔍', 'reward' => 50, 'target' => 5],
];

if ($method === 'GET') {
    // Calculate actual progress from today's activity
    $actualProgress = calculateDailyProgress($pdo, $userId, $today);
    
    // Get stored completion status
    $stmt = $pdo->prepare("
        SELECT challenge_id, completed_at
        FROM user_daily_challenges
        WHERE user_id = ? AND challenge_date = ?
    ");
    $stmt->execute([$userId, $today]);
    $completions = $stmt->fetchAll(PDO::FETCH_KEY_PAIR);
    
    $challenges = [];
    $totalReward = 0;
    $completedCount = 0;
    
    foreach ($dailyChallenges as $challenge) {
        $id = $challenge['id'];
        $progress = $actualProgress[$id] ?? 0;
        $completedAt = $completions[$id] ?? null;
        $isCompleted = $completedAt !== null || $progress >= $challenge['target'];
        
        // Auto-complete if progress meets target
        if ($progress >= $challenge['target'] && !$completedAt) {
            $completedAt = date('Y-m-d H:i:s');
            $stmt = $pdo->prepare("
                INSERT INTO user_daily_challenges (user_id, challenge_id, progress, completed_at, challenge_date)
                VALUES (?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE progress = ?, completed_at = COALESCE(completed_at, ?)
            ");
            $stmt->execute([$userId, $id, $progress, $completedAt, $today, $progress, $completedAt]);
            
            // Award XP
            $stmt = $pdo->prepare("UPDATE users SET xp = xp + ? WHERE id = ?");
            $stmt->execute([$challenge['reward'], $userId]);
            
            // Award tokens
            $stmt = $pdo->prepare("UPDATE users SET tokens_balance = tokens_balance + ? WHERE id = ?");
            $stmt->execute([$challenge['reward'], $userId]);
        }
        
        if ($isCompleted) {
            $completedCount++;
            $totalReward += $challenge['reward'];
        }
        
        $challenges[] = [
            'id' => $challenge['id'],
            'title' => $challenge['title'],
            'description' => $challenge['description'],
            'emoji' => $challenge['emoji'],
            'reward' => $challenge['reward'],
            'target' => $challenge['target'],
            'progress' => min($progress, $challenge['target']),
            'is_completed' => $isCompleted,
            'completed_at' => $completedAt
        ];
    }
    
    // Calculate time until reset
    $tomorrow = new DateTime('tomorrow');
    $now = new DateTime();
    $diff = $now->diff($tomorrow);
    $hoursUntilReset = $diff->h + ($diff->days * 24);
    $minutesUntilReset = $diff->i;
    
    echo json_encode([
        'challenges' => $challenges,
        'total_challenges' => count($challenges),
        'completed_count' => $completedCount,
        'total_reward_earned' => $totalReward,
        'resets_in' => "{$hoursUntilReset}h {$minutesUntilReset}m",
        'date' => $today
    ]);
    exit;
}

if ($method === 'POST') {
    // Update challenge progress
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (empty($input['challenge_id'])) {
        http_response_code(400);
        echo json_encode(['error' => 'challenge_id required']);
        exit;
    }
    
    $challengeId = $input['challenge_id'];
    $incrementBy = (int) ($input['increment'] ?? 1);
    
    // Find challenge definition
    $challenge = null;
    foreach ($dailyChallenges as $c) {
        if ($c['id'] === $challengeId) {
            $challenge = $c;
            break;
        }
    }
    
    if (!$challenge) {
        http_response_code(404);
        echo json_encode(['error' => 'Challenge not found']);
        exit;
    }
    
    // Update or insert progress
    $stmt = $pdo->prepare("
        INSERT INTO user_daily_challenges (user_id, challenge_id, progress, challenge_date)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE progress = progress + ?
    ");
    $stmt->execute([$userId, $challengeId, $incrementBy, $today, $incrementBy]);
    
    // Check if completed
    $stmt = $pdo->prepare("SELECT progress, completed_at FROM user_daily_challenges WHERE user_id = ? AND challenge_id = ? AND challenge_date = ?");
    $stmt->execute([$userId, $challengeId, $today]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    $progress = (int) $result['progress'];
    $justCompleted = false;
    $rewardEarned = 0;
    
    if ($progress >= $challenge['target'] && !$result['completed_at']) {
        $stmt = $pdo->prepare("UPDATE user_daily_challenges SET completed_at = NOW() WHERE user_id = ? AND challenge_id = ? AND challenge_date = ?");
        $stmt->execute([$userId, $challengeId, $today]);
        $justCompleted = true;
        $rewardEarned = $challenge['reward'];
        
        // Award XP and tokens
        $stmt = $pdo->prepare("UPDATE users SET xp = xp + ?, tokens_balance = tokens_balance + ? WHERE id = ?");
        $stmt->execute([$rewardEarned, $rewardEarned, $userId]);
    }
    
    echo json_encode([
        'challenge_id' => $challengeId,
        'progress' => min($progress, $challenge['target']),
        'target' => $challenge['target'],
        'is_completed' => $progress >= $challenge['target'],
        'just_completed' => $justCompleted,
        'reward_earned' => $rewardEarned
    ]);
    exit;
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);

// Helper functions
function ensureDailyChallengesTable(PDO $pdo): void {
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS user_daily_challenges (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            challenge_id VARCHAR(50) NOT NULL,
            progress INT DEFAULT 0,
            completed_at DATETIME,
            challenge_date DATE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY unique_user_challenge_date (user_id, challenge_id, challenge_date)
        )
    ");
}

function calculateDailyProgress(PDO $pdo, int $userId, string $today): array {
    $progress = [];
    
    // Count bets placed today
    $stmt = $pdo->prepare("SELECT COUNT(*) FROM bets WHERE user_id = ? AND DATE(created_at) = ?");
    $stmt->execute([$userId, $today]);
    $progress['daily_bet'] = (int) $stmt->fetchColumn();
    
    // Count gossip posted today
    $stmt = $pdo->prepare("SELECT COUNT(*) FROM gossip WHERE user_id = ? AND DATE(created_at) = ?");
    $stmt->execute([$userId, $today]);
    $progress['daily_gossip'] = (int) $stmt->fetchColumn();
    
    // Count events viewed today (we'll track this via event_views table or estimate)
    // For now, count unique events where user placed a bet
    $stmt = $pdo->prepare("SELECT COUNT(DISTINCT event_id) FROM bets WHERE user_id = ? AND DATE(created_at) = ?");
    $stmt->execute([$userId, $today]);
    $progress['daily_explore'] = (int) $stmt->fetchColumn();
    
    return $progress;
}


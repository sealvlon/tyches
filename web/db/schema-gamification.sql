-- Gamification Schema Updates for Tyches
-- Run this script to add gamification tables and columns
-- Note: Foreign keys removed for compatibility - the PHP code handles data integrity

-- User Streaks table
CREATE TABLE IF NOT EXISTS user_streaks (
    user_id INT PRIMARY KEY,
    current_streak INT DEFAULT 0,
    longest_streak INT DEFAULT 0,
    last_activity_date DATE,
    total_days_active INT DEFAULT 0,
    weekly_activity JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- User Achievements table
CREATE TABLE IF NOT EXISTS user_achievements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    achievement_id VARCHAR(50) NOT NULL,
    progress INT DEFAULT 0,
    unlocked_at DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_user_achievement (user_id, achievement_id),
    INDEX idx_user_id (user_id)
);

-- Daily Challenges Progress table
CREATE TABLE IF NOT EXISTS user_daily_challenges (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    challenge_id VARCHAR(50) NOT NULL,
    progress INT DEFAULT 0,
    completed_at DATETIME,
    challenge_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_user_challenge_date (user_id, challenge_id, challenge_date),
    INDEX idx_user_id (user_id)
);

-- Notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT,
    data JSON,
    read_at DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_created (user_id, created_at),
    INDEX idx_user_unread (user_id, read_at)
);

-- Add XP and Level columns to users table if they don't exist
ALTER TABLE users 
    ADD COLUMN IF NOT EXISTS xp INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS level INT DEFAULT 1;

-- Add avatar columns to markets table if they don't exist
ALTER TABLE markets 
    ADD COLUMN IF NOT EXISTS avatar_emoji VARCHAR(10) DEFAULT '🎯',
    ADD COLUMN IF NOT EXISTS avatar_color VARCHAR(20) DEFAULT '#6366F1';

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_streaks_last_activity ON user_streaks(last_activity_date);
CREATE INDEX IF NOT EXISTS idx_achievements_unlocked ON user_achievements(unlocked_at);
CREATE INDEX IF NOT EXISTS idx_daily_challenges_date ON user_daily_challenges(challenge_date);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);

-- Achievement definitions for reference (these are hardcoded in achievements.php but documented here)
/*
Achievement IDs:
Trading:
- first_bet: Place your first bet (1)
- high_roller: Place 50 bets (50)
- whale: Bet 10,000 tokens total (10000)
- diversified: Bet on 10 different events (10)

Prediction:
- oracle: Win 10 predictions (10)
- fortune_teller: Win 5 in a row (5)
- psychic: Achieve 80% accuracy (80)

Social:
- social_butterfly: Add 5 friends (5)
- gossip_queen: Post 20 gossip messages (20)
- event_creator: Create your first event (1)
- market_maker: Create a market (1)

Streak:
- week_warrior: 7 day streak (7)
- monthly_master: 30 day streak (30)
- year_legend: 365 day streak (365)

Special:
- early_adopter: Join Tyches in 2024 (1)
- perfect_week: Bet every day for a week (7)
*/

-- Notification types reference:
/*
- bet_placed: Someone bet on an event you're in
- bet_won: You won a bet
- bet_lost: You lost a bet
- event_created: New event in your market
- event_closing: Event closing soon
- event_resolved: Event was resolved
- gossip_mention: Someone mentioned you in gossip
- gossip_reply: Someone replied to your gossip
- friend_request: Someone sent you a friend request
- friend_accepted: Someone accepted your friend request
- market_invite: Invited to join a market
- streak_reminder: Don't lose your streak
- achievement_unlocked: You unlocked an achievement
- challenge_completed: You completed a daily challenge
*/


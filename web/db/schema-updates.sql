-- Tyches Schema Updates (v3)
-- Run these additions to support new features

-- ========== RESOLUTION VOTES ==========
-- Track participant votes on event outcomes

CREATE TABLE IF NOT EXISTS resolution_votes (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  event_id INT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL,
  voted_outcome VARCHAR(64) NOT NULL,
  reason TEXT DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_resvotes_event FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  CONSTRAINT fk_resvotes_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT uq_resolution_vote UNIQUE (event_id, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========== RESOLUTION DISPUTES ==========
-- Track disputes against resolved events

CREATE TABLE IF NOT EXISTS resolution_disputes (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  event_id INT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL,
  reason TEXT NOT NULL,
  status ENUM('pending','reviewed','resolved','rejected') NOT NULL DEFAULT 'pending',
  admin_notes TEXT DEFAULT NULL,
  resolved_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_disputes_event FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  CONSTRAINT fk_disputes_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_disputes_event ON resolution_disputes (event_id, status);

-- ========== NOTIFICATIONS ==========
-- Store user notifications for push/in-app

CREATE TABLE IF NOT EXISTS notifications (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  type VARCHAR(50) NOT NULL,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  url VARCHAR(512) DEFAULT NULL,
  is_read TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_notifications_user ON notifications (user_id, is_read, created_at);

-- ========== PUSH SUBSCRIPTIONS ==========
-- Store web push notification subscriptions

CREATE TABLE IF NOT EXISTS push_subscriptions (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  endpoint VARCHAR(512) NOT NULL,
  p256dh_key VARCHAR(255) NOT NULL,
  auth_key VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_pushsub_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT uq_push_endpoint UNIQUE (endpoint(255))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========== PASSWORD RESET TOKENS ==========
-- Separate table for password reset tokens with expiry

CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  token VARCHAR(64) NOT NULL UNIQUE,
  expires_at DATETIME NOT NULL,
  used_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_pwreset_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_pwreset_token ON password_reset_tokens (token, expires_at);

-- ========== PERFORMANCE INDEXES ==========
-- Additional indexes for better query performance

CREATE INDEX IF NOT EXISTS idx_bets_created ON bets (created_at);
CREATE INDEX IF NOT EXISTS idx_events_status ON events (status, closes_at);
CREATE INDEX IF NOT EXISTS idx_events_market_status ON events (market_id, status);
CREATE INDEX IF NOT EXISTS idx_users_tokens ON users (tokens_balance DESC);

-- ========== UPDATE EXISTING TABLES ==========

-- Add reputation fields to users if not exists
-- Note: Run these ALTER statements individually if needed

-- ALTER TABLE users ADD COLUMN IF NOT EXISTS reputation_score DECIMAL(10,2) NOT NULL DEFAULT 0;
-- ALTER TABLE users ADD COLUMN IF NOT EXISTS total_wins INT UNSIGNED NOT NULL DEFAULT 0;
-- ALTER TABLE users ADD COLUMN IF NOT EXISTS total_losses INT UNSIGNED NOT NULL DEFAULT 0;


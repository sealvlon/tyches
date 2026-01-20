-- Tyches full schema (v2)
-- Run this whole file in your MySQL database (e.g. via phpMyAdmin).
-- This will DROP and recreate the core tables for the new architecture.

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS bets;
DROP TABLE IF EXISTS gossip;
DROP TABLE IF EXISTS user_notes;
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS market_members;
DROP TABLE IF EXISTS markets;
DROP TABLE IF EXISTS friends;
DROP TABLE IF EXISTS users;

SET FOREIGN_KEY_CHECKS = 1;

-- ========== USERS ==========
-- Core user accounts. Authentication is via email + password, sessions on the PHP side.

CREATE TABLE users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  username VARCHAR(32) NOT NULL UNIQUE,
  email VARCHAR(255) NOT NULL UNIQUE,
  phone VARCHAR(32) DEFAULT NULL,
  password_hash VARCHAR(255) NOT NULL,
  email_verified_at DATETIME DEFAULT NULL,
  verification_token VARCHAR(64) DEFAULT NULL,
  is_admin TINYINT(1) NOT NULL DEFAULT 0,
  -- Admin / risk controls
  status ENUM('active','restricted','suspended') NOT NULL DEFAULT 'active',
  tokens_balance DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  profile_image_url VARCHAR(255) DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Notes left by admins on user accounts (for KYC / risk / support)
CREATE TABLE user_notes (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  admin_user_id INT UNSIGNED DEFAULT NULL,
  note TEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_user_notes_user  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_user_notes_admin FOREIGN KEY (admin_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========== FRIENDS ==========
-- Lightweight directed friendships with status. We store each pair once with user_id < friend_user_id
-- and treat status='accepted' as mutual friendship.

CREATE TABLE friends (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  friend_user_id INT UNSIGNED NOT NULL,
  status ENUM('pending','accepted','blocked') NOT NULL DEFAULT 'pending',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_friends_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_friends_friend FOREIGN KEY (friend_user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT uq_friend_pair UNIQUE (user_id, friend_user_id),
  CONSTRAINT chk_friend_pair CHECK (user_id < friend_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========== MARKETS ==========
-- Friend groups / audiences. Each market is a group of users.

CREATE TABLE markets (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  owner_id INT UNSIGNED NOT NULL,
  name VARCHAR(150) NOT NULL,
  description TEXT,
  visibility ENUM('private','invite_only','link_only') NOT NULL DEFAULT 'private',
  avatar_emoji VARCHAR(8) DEFAULT NULL,
  avatar_color VARCHAR(16) DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_markets_owner FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========== MARKET MEMBERS ==========
-- Users that belong to a given market (group).

CREATE TABLE market_members (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  market_id INT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL,
  role ENUM('owner','member') NOT NULL DEFAULT 'member',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_members_market FOREIGN KEY (market_id) REFERENCES markets(id) ON DELETE CASCADE,
  CONSTRAINT fk_members_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT uq_market_member UNIQUE (market_id, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========== EVENTS ==========
-- Prediction questions that live inside a market.

CREATE TABLE events (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  market_id INT UNSIGNED NOT NULL,
  creator_id INT UNSIGNED NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  event_type ENUM('binary','multiple') NOT NULL DEFAULT 'binary',
  status ENUM('open','closed','resolved') NOT NULL DEFAULT 'open',
  closes_at DATETIME NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- Binary event fields
  yes_price INT UNSIGNED DEFAULT NULL,     -- cents; 1–100
  no_price INT UNSIGNED DEFAULT NULL,      -- cents; 1–100
  yes_percent INT UNSIGNED DEFAULT NULL,   -- 0–100
  no_percent INT UNSIGNED DEFAULT NULL,    -- 0–100
  -- Multiple-choice event fields; outcomes as JSON array
  outcomes_json JSON DEFAULT NULL,
  -- Trading stats
  volume DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  traders_count INT UNSIGNED NOT NULL DEFAULT 0,
  -- Resolution (for admin)
  winning_side ENUM('YES','NO') DEFAULT NULL,
  winning_outcome_id VARCHAR(64) DEFAULT NULL,
  settled_at DATETIME DEFAULT NULL,
  CONSTRAINT fk_events_market FOREIGN KEY (market_id) REFERENCES markets(id) ON DELETE CASCADE,
  CONSTRAINT fk_events_creator FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========== BETS ==========
-- Simple order log / positions. For this version we do not maintain a live order book;
-- bets just record intent and update event volume + trader counts.

CREATE TABLE bets (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  event_id INT UNSIGNED NOT NULL,
  side ENUM('YES','NO') DEFAULT NULL,          -- used for binary events
  outcome_id VARCHAR(64) DEFAULT NULL,         -- used for multiple-choice events
  shares INT UNSIGNED NOT NULL,
  price INT UNSIGNED NOT NULL,                 -- cents; 1–100 per share
  notional DECIMAL(12,2) NOT NULL,             -- shares * price / 100
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_bets_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_bets_event FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_bets_event ON bets (event_id);
CREATE INDEX idx_bets_user ON bets (user_id);

-- ========== GOSSIP ==========
-- Event-level comments / chat.

CREATE TABLE gossip (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  event_id INT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL,
  message TEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_gossip_event FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  CONSTRAINT fk_gossip_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_gossip_event_created ON gossip (event_id, created_at);

-- ========== ADMIN USER ==========
-- Default admin account (password: TychesAdmin123!)

INSERT INTO users (name, username, email, phone, password_hash, email_verified_at, is_admin)
VALUES (
  'Admin',
  'adminuser',
  'admin@domain.com',
  NULL,
  'password123', // Change to your password
  NOW(),
  1
);


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
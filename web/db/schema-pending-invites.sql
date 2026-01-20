-- Pending Market Invites Table
-- Run this SQL to add support for inviting new users who don't have accounts yet.
-- When they sign up with the invited email, they'll automatically be added to the market.

CREATE TABLE IF NOT EXISTS pending_market_invites (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    market_id INT UNSIGNED NOT NULL,
    invited_by INT UNSIGNED NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_invite (email, market_id),
    INDEX idx_email (email),
    INDEX idx_market (market_id),
    INDEX idx_invited_by (invited_by)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Note: Foreign keys are omitted for compatibility.
-- The application code handles cleanup when markets/users are deleted.


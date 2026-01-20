-- Pool-based Betting Schema Updates for Tyches
-- Adds support for parimutuel pool betting system

-- Ensure resolution_votes table exists (for voting on event outcomes)
CREATE TABLE IF NOT EXISTS resolution_votes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    event_id INT NOT NULL,
    user_id INT NOT NULL,
    voted_outcome VARCHAR(64) NOT NULL,
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_vote (event_id, user_id),
    INDEX idx_event (event_id)
);

-- Ensure resolution_disputes table exists
CREATE TABLE IF NOT EXISTS resolution_disputes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    event_id INT NOT NULL,
    user_id INT NOT NULL,
    reason TEXT NOT NULL,
    status ENUM('pending', 'resolved', 'rejected') DEFAULT 'pending',
    resolved_by INT,
    resolved_at DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_event (event_id)
);

-- Add pool tracking columns to events (optional, for caching)
-- The actual pools are calculated from bets table, but we can cache here
ALTER TABLE events 
    ADD COLUMN IF NOT EXISTS yes_pool DECIMAL(15,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS no_pool DECIMAL(15,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total_pool DECIMAL(15,2) DEFAULT 0;

-- Ensure bets table has all needed columns
-- The 'notional' column represents the actual bet amount
-- In parimutuel, shares = notional (1 token = 1 share)

-- Add index for efficient pool calculations
CREATE INDEX IF NOT EXISTS idx_bets_event_side ON bets(event_id, side);
CREATE INDEX IF NOT EXISTS idx_bets_event_outcome ON bets(event_id, outcome_id);

-- View to get pool summaries (optional, for convenience)
CREATE OR REPLACE VIEW event_pools AS
SELECT 
    event_id,
    SUM(CASE WHEN side = 'YES' THEN notional ELSE 0 END) as yes_pool,
    SUM(CASE WHEN side = 'NO' THEN notional ELSE 0 END) as no_pool,
    SUM(CASE WHEN side IS NULL AND outcome_id IS NOT NULL THEN notional ELSE 0 END) as multi_pool,
    SUM(notional) as total_pool,
    COUNT(DISTINCT user_id) as unique_bettors
FROM bets
GROUP BY event_id;

-- Example of how odds work (for documentation):
/*
PARIMUTUEL ODDS EXAMPLE:

Event: "Will it rain tomorrow?"
YES pool: 1,000 tokens (from 5 users)
NO pool: 500 tokens (from 3 users)
Total pool: 1,500 tokens

Implied probabilities:
- YES: 1000/1500 = 66.7%
- NO: 500/1500 = 33.3%

Odds (payout multiplier):
- YES: 1500/1000 = 1.5x (bet 100 → get 150 if YES wins)
- NO: 1500/500 = 3.0x (bet 100 → get 300 if NO wins)

If YES wins:
- Each token in YES pool gets: 1500/1000 = 1.5 tokens
- User A bet 200 on YES → gets 300 tokens (profit: 100)
- User B bet 500 on YES → gets 750 tokens (profit: 250)

If NO wins:
- Each token in NO pool gets: 1500/500 = 3.0 tokens
- User C bet 300 on NO → gets 900 tokens (profit: 600)

The house takes 0% (all tokens go to winners).
This is different from traditional bookmaker odds where the house keeps a margin.
*/


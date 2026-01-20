-- Migration: Add requester_id to friends table
-- Purpose: Track who initiated the friend request so only the recipient can accept
-- Run this migration on your database before deploying the updated code.

-- Step 1: Add requester_id column (nullable initially for existing rows)
ALTER TABLE friends 
ADD COLUMN requester_id INT UNSIGNED DEFAULT NULL
AFTER status;

-- Step 2: Add foreign key constraint
ALTER TABLE friends 
ADD CONSTRAINT fk_friends_requester 
FOREIGN KEY (requester_id) REFERENCES users(id) ON DELETE SET NULL;

-- Step 3: Update status enum to include 'declined'
ALTER TABLE friends 
MODIFY COLUMN status ENUM('pending','accepted','blocked','declined') NOT NULL DEFAULT 'pending';

-- Step 4: For existing pending requests, we can't know who sent them,
-- so they will have requester_id = NULL. These will need to be handled
-- gracefully in the code (treat as if either party can accept, or require re-request).
-- New requests going forward will always have requester_id set.

-- Note: If you want to clean up old pending requests that lack requester_id:
-- DELETE FROM friends WHERE status = 'pending' AND requester_id IS NULL;


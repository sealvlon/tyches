-- Tyches Schema Update: Event Visibility, Resolver & Participants
-- Run this migration to add event ownership and visibility features

-- ========== UPDATE EVENTS TABLE ==========
-- Add visibility: 'public' (all market members) or 'private' (invite-only within market)
-- Add resolver_id: who determines the outcome (defaults to creator)
-- Add resolution_type: 'manual' (human decides) or 'automatic' (system decides)

ALTER TABLE events 
ADD COLUMN IF NOT EXISTS visibility ENUM('public', 'private') NOT NULL DEFAULT 'public' AFTER status;

ALTER TABLE events 
ADD COLUMN IF NOT EXISTS resolver_id INT UNSIGNED DEFAULT NULL AFTER creator_id;

ALTER TABLE events 
ADD COLUMN IF NOT EXISTS resolution_type ENUM('manual', 'automatic') NOT NULL DEFAULT 'manual' AFTER visibility;

-- Add foreign key for resolver
ALTER TABLE events 
ADD CONSTRAINT fk_events_resolver FOREIGN KEY (resolver_id) REFERENCES users(id) ON DELETE SET NULL;

-- ========== EVENT PARTICIPANTS TABLE ==========
-- For private events: track who can see and participate
-- If event is 'public', this table is not used (all market members can participate)
-- If event is 'private', only users in this table can see/participate

CREATE TABLE IF NOT EXISTS event_participants (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  event_id INT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL,
  role ENUM('participant', 'host') NOT NULL DEFAULT 'participant',
  invited_by INT UNSIGNED DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_evpart_event FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  CONSTRAINT fk_evpart_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_evpart_inviter FOREIGN KEY (invited_by) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT uq_event_participant UNIQUE (event_id, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Index for faster lookups
CREATE INDEX idx_evpart_event ON event_participants (event_id);
CREATE INDEX idx_evpart_user ON event_participants (user_id);

-- ========== EVENT HOSTS TABLE ==========
-- Optional: additional hosts who can help manage the event
-- Hosts can invite participants and help with resolution

CREATE TABLE IF NOT EXISTS event_hosts (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  event_id INT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_evhost_event FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  CONSTRAINT fk_evhost_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT uq_event_host UNIQUE (event_id, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========== UPDATE EXISTING EVENTS ==========
-- Set resolver_id to creator_id for existing events (creator resolves by default)
UPDATE events SET resolver_id = creator_id WHERE resolver_id IS NULL;


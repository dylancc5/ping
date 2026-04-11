-- ============================================================
-- 001_initial_schema.sql
-- Core schema for Ping: profiles, contacts, interactions,
-- nudges, goals — plus all indexes.
--
-- ORDERING NOTE: pgvector (002) must logically precede this
-- file, but the Supabase CLI runs migrations alphabetically
-- (001 before 002). To ensure VECTOR(768) works, this file
-- bootstraps the extension itself as its very first statement.
-- 002_enable_pgvector.sql repeats the same idempotent statement
-- as a standalone, auditable artifact.
-- ============================================================

-- Enable pgvector extension (idempotent — safe to run multiple times)
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================
-- ENUM TYPES
-- Defined before tables that reference them.
-- Postgres 14+ (which Supabase provides) supports DO $$ blocks
-- for idempotent enum creation.
-- ============================================================

DO $$ BEGIN
  CREATE TYPE interaction_type AS ENUM (
    'met',        -- Initial meeting / contact creation event
    'message',    -- User sent a message to this contact
    'call',       -- Phone call or video meeting
    'note',       -- User added a freeform note (no outreach)
    'nudge_sent'  -- System-generated nudge was acted on
  );
EXCEPTION
  WHEN duplicate_object THEN NULL; -- Already exists — skip silently
END $$;

DO $$ BEGIN
  CREATE TYPE nudge_status AS ENUM (
    'pending',    -- Created by CRON, push not yet sent
    'delivered',  -- APNs push notification sent to device
    'opened',     -- User tapped the notification
    'acted',      -- User sent a message (acted_at timestamp set)
    'snoozed',    -- User deferred; snoozed_until timestamp set
    'dismissed'   -- User explicitly dismissed without acting
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- TABLE: profiles
-- One row per authenticated user. Mirrors auth.users by PK.
-- Auto-created on signup by trigger in 005_triggers.sql —
-- the app never needs to manually insert a profile.
-- ============================================================

CREATE TABLE IF NOT EXISTS profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name     TEXT,
  avatar_url    TEXT,
  -- Array of user's own writing samples, injected into Gemini
  -- system prompt for tone-calibrated message drafting
  tone_samples  TEXT[],
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()  -- Maintained by set_updated_at trigger
);

-- ============================================================
-- TABLE: contacts
-- Core entity. One row per contact per user.
-- embedding: VECTOR(768) from Gemini text-embedding-004.
--   NULL until iOS background task completes after save.
-- warmth_score: 0.0 (cold) → 1.0 (hot).
--   Decays via CRON edge function; resets to 1.0 on interaction.
-- ============================================================

CREATE TABLE IF NOT EXISTS contacts (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name              TEXT        NOT NULL,
  company           TEXT,
  title             TEXT,
  -- Required: short context string like "SCET career fair" or "CS 189 class"
  how_met           TEXT        NOT NULL,
  notes             TEXT,
  linkedin_url      TEXT,
  email             TEXT,
  phone             TEXT,
  -- Optional taxonomy: ["VC", "Berkeley", "ML"]
  tags              TEXT[],
  -- Gemini text-embedding-004 output (768 dimensions).
  -- NULL until background embedding generation completes on iOS.
  embedding         VECTOR(768),
  -- Relationship health proxy. Decays on nudge creation (* 0.9),
  -- resets to 1.0 when user logs an interaction. Used by WarmthDot UI.
  warmth_score      FLOAT       DEFAULT 1.0,
  last_contacted_at TIMESTAMPTZ,
  met_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()  -- Maintained by set_updated_at trigger
);

-- IVFFlat approximate nearest-neighbor index for cosine similarity search.
-- lists=100 is appropriate for up to ~1M vectors. For MVP (<10k total rows)
-- this is overbuilt but cheap. When total rows exceed ~100k, set lists to
-- roughly sqrt(row_count).
CREATE INDEX IF NOT EXISTS contacts_embedding_idx
  ON contacts USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

-- Composite index for "get this user's contacts ordered by warmth" —
-- the primary Network tab query.
CREATE INDEX IF NOT EXISTS contacts_user_warmth_idx
  ON contacts (user_id, warmth_score DESC);

-- ============================================================
-- TABLE: interactions
-- Append-only log of every meaningful event with a contact.
-- Never update rows here — always INSERT new ones to preserve
-- the historical record used by the nudge scoring algorithm.
-- ============================================================

CREATE TABLE IF NOT EXISTS interactions (
  id          UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id  UUID             NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  user_id     UUID             NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type        interaction_type NOT NULL,
  notes       TEXT,
  -- When the interaction occurred, not when it was logged (may differ)
  occurred_at TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
  created_at  TIMESTAMPTZ      DEFAULT NOW()
);

-- Supports "get all interactions for a contact, newest first"
-- — used by ContactDetailView and the nudge scoring edge function.
CREATE INDEX IF NOT EXISTS interactions_contact_idx
  ON interactions (contact_id, occurred_at DESC);

-- ============================================================
-- TABLE: nudges
-- Records created by the score-contacts CRON edge function.
-- draft_message is intentionally NULL at creation time —
-- iOS generates it on-demand via Gemini when the user opens
-- the nudge card, to avoid burning Gemini quota on unseen nudges.
-- ============================================================

CREATE TABLE IF NOT EXISTS nudges (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id    UUID         NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  user_id       UUID         NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  -- Full lifecycle tracked here; see nudge_status enum above
  status        nudge_status DEFAULT 'pending',
  -- Human-readable reason shown on nudge card: "You haven't reached
  -- out in 3 weeks"
  reason        TEXT,
  -- AI draft generated on iOS; null until user opens the card
  draft_message TEXT,
  scheduled_at  TIMESTAMPTZ  NOT NULL,
  delivered_at  TIMESTAMPTZ,
  acted_at      TIMESTAMPTZ,
  -- Set when user taps "Snooze"; CRON respects this via hasOpenNudge check
  snoozed_until TIMESTAMPTZ,
  created_at    TIMESTAMPTZ  DEFAULT NOW()
);

-- Partial index: only index pending nudges.
-- Delivered/dismissed/acted nudges are never queried in hot paths;
-- excluding them keeps this index tiny and fast over time.
CREATE INDEX IF NOT EXISTS nudges_user_pending_idx
  ON nudges (user_id, scheduled_at)
  WHERE status = 'pending';

-- ============================================================
-- TABLE: goals
-- User-defined intent strings for goal-triggered contact surfacing.
-- Example: "Applying to Stripe for PM role"
-- embedding is set by iOS in the background after insert (same
-- pattern as contacts.embedding).
-- ============================================================

CREATE TABLE IF NOT EXISTS goals (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  -- Natural language goal text; embedded as-is (user already wrote it clearly)
  text       TEXT        NOT NULL,
  -- Gemini text-embedding-004 output, matched against contacts.embedding
  embedding  VECTOR(768),
  active     BOOLEAN     DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

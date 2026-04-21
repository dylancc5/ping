-- ======================================================================
-- 007_app_config.sql
-- Single-row remote config table. Lets us tweak thresholds, model names,
-- and feature flags without shipping a new build.
--
-- Design: one row (id=1), one JSONB blob, one version integer.
-- RLS: all authenticated users can SELECT; writes via service role only.
-- The singleton CHECK constraint prevents accidental second rows.
-- ======================================================================

CREATE TABLE IF NOT EXISTS app_config (
    id          INTEGER PRIMARY KEY DEFAULT 1,
    version     INTEGER NOT NULL DEFAULT 1,
    data        JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT app_config_singleton CHECK (id = 1)
);

ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'app_config' AND policyname = 'app_config_read'
    ) THEN
        CREATE POLICY app_config_read ON app_config
            FOR SELECT TO authenticated USING (true);
    END IF;
END $$;

-- Seed with current production defaults (matches Swift/TS fallbacks exactly).
INSERT INTO app_config (id, version, data) VALUES (
    1, 1,
    jsonb_build_object(
        -- Client-side: warmth / cooling
        'cooling_warmth_threshold',  0.5,
        'cooling_idle_days',         7,
        'warmth_hot_threshold',      0.8,
        'warmth_warm_threshold',     0.5,
        'warmth_cool_threshold',     0.2,
        -- Client-side: Gemini
        'gemini_generation_model',   'gemini-2.0-flash',
        'gemini_embedding_model',    'gemini-embedding-2-preview',
        'gemini_draft_temperature',  0.7,
        'gemini_draft_max_tokens',   200,
        -- Client-side: semantic matching
        'contact_match_threshold',   0.5,
        'goal_match_threshold',      0.45,
        -- Server-side: scoring (also read by score-contacts edge function)
        'nudge_threshold',           0.65,
        'max_daily_nudges',          3,
        'warmth_decay_factor',       0.9
    )
) ON CONFLICT (id) DO NOTHING;

-- Auto-bump version + updated_at whenever data changes.
CREATE OR REPLACE FUNCTION bump_app_config_version()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.data IS DISTINCT FROM OLD.data THEN
        NEW.version = OLD.version + 1;
        NEW.updated_at = NOW();
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS app_config_version_bump ON app_config;
CREATE TRIGGER app_config_version_bump
    BEFORE UPDATE ON app_config
    FOR EACH ROW EXECUTE FUNCTION bump_app_config_version();

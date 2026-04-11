-- ============================================================
-- 003_rls_policies.sql
-- Row Level Security for all Ping tables.
--
-- Design principle: every user can only read/write their own
-- data. The Supabase service role key (used only by Edge
-- Functions) bypasses RLS entirely — no special policies
-- needed for server-side operations.
--
-- Note: Postgres does not support CREATE POLICY IF NOT EXISTS.
-- We check pg_policies before creating each policy to achieve
-- idempotency.
-- ============================================================

-- Enable RLS on all tables (idempotent — safe to call multiple times)
ALTER TABLE profiles      ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts      ENABLE ROW LEVEL SECURITY;
ALTER TABLE interactions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE nudges        ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals         ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- profiles
-- Profile id IS auth.uid() — ownership is a direct equality check.
-- ============================================================

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'profiles'
      AND policyname = 'users_own_profile'
  ) THEN
    CREATE POLICY "users_own_profile"
      ON profiles
      FOR ALL
      USING (id = auth.uid());
  END IF;
END $$;

-- ============================================================
-- contacts
-- ============================================================

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'contacts'
      AND policyname = 'users_own_contacts'
  ) THEN
    CREATE POLICY "users_own_contacts"
      ON contacts
      FOR ALL
      USING (user_id = auth.uid());
  END IF;
END $$;

-- ============================================================
-- interactions
-- ============================================================

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'interactions'
      AND policyname = 'users_own_interactions'
  ) THEN
    CREATE POLICY "users_own_interactions"
      ON interactions
      FOR ALL
      USING (user_id = auth.uid());
  END IF;
END $$;

-- ============================================================
-- nudges
-- ============================================================

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'nudges'
      AND policyname = 'users_own_nudges'
  ) THEN
    CREATE POLICY "users_own_nudges"
      ON nudges
      FOR ALL
      USING (user_id = auth.uid());
  END IF;
END $$;

-- ============================================================
-- goals
-- ============================================================

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'goals'
      AND policyname = 'users_own_goals'
  ) THEN
    CREATE POLICY "users_own_goals"
      ON goals
      FOR ALL
      USING (user_id = auth.uid());
  END IF;
END $$;

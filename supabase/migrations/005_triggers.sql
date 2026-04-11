-- ============================================================
-- 005_triggers.sql
-- Two trigger functions:
--   1. handle_new_user   — auto-create profiles row on signup
--   2. set_updated_at    — maintain updated_at on profiles/contacts
-- ============================================================

-- ============================================================
-- FUNCTION: handle_new_user
--
-- Fires AFTER INSERT on auth.users (Supabase's internal auth table).
-- Creates the corresponding public.profiles row automatically so
-- the iOS app never needs to manually insert a profile on signup.
--
-- SECURITY DEFINER: Required. The trigger fires in the context of
-- Supabase's internal auth system, whose role lacks INSERT permission
-- on public.profiles. SECURITY DEFINER causes the function to run
-- as its owner (postgres), which has the necessary privilege.
-- This is the standard Supabase-recommended pattern for profile
-- auto-creation.
--
-- SET search_path = '': Mandatory companion to SECURITY DEFINER.
-- Prevents search_path injection attacks where a malicious user
-- creates a function in a schema that shadows public. All table
-- references below are fully schema-qualified (public.*) as a result.
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, avatar_url)
  VALUES (
    NEW.id,
    -- Supabase Auth stores display name in raw_user_meta_data.
    -- Google sign-in: "full_name" key.
    -- Apple sign-in: "name" key (only provided on first authorization).
    -- COALESCE tries Google first, falls back to Apple, then NULL.
    COALESCE(
      NEW.raw_user_meta_data->>'full_name',
      NEW.raw_user_meta_data->>'name'
    ),
    -- Google sign-in provides a profile picture URL.
    -- Apple does not provide one.
    NEW.raw_user_meta_data->>'avatar_url'
  )
  -- Guard against duplicate inserts (e.g., migration re-runs on a
  -- seeded database, or edge cases in Supabase's auth system).
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- DROP + CREATE for idempotency — CREATE OR REPLACE TRIGGER exists in
-- Postgres 14+ but only replaces the function binding, not the event
-- or table. DROP IF EXISTS + CREATE is the safe, universal pattern.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- FUNCTION: set_updated_at
--
-- Generic trigger function to auto-maintain updated_at columns.
-- Applied to profiles and contacts — the two tables with this
-- column. (interactions is append-only; nudges/goals don't have
-- updated_at because their mutations are tracked via dedicated
-- timestamp columns like acted_at, snoozed_until.)
--
-- SECURITY INVOKER (default): no elevated privilege needed.
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Apply to profiles
DROP TRIGGER IF EXISTS set_profiles_updated_at ON public.profiles;

CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- Apply to contacts
DROP TRIGGER IF EXISTS set_contacts_updated_at ON public.contacts;

CREATE TRIGGER set_contacts_updated_at
  BEFORE UPDATE ON public.contacts
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

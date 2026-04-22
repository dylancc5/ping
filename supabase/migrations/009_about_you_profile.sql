-- ============================================================
-- Migration 009: About You profile fields
-- Extends profiles table with career, location, interests,
-- and a freeform about_me field for improved matching quality.
-- ============================================================

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS career_role      TEXT,
  ADD COLUMN IF NOT EXISTS career_company   TEXT,
  ADD COLUMN IF NOT EXISTS career_industry  TEXT,
  ADD COLUMN IF NOT EXISTS career_seniority TEXT,
  ADD COLUMN IF NOT EXISTS interests        TEXT[],
  ADD COLUMN IF NOT EXISTS city             TEXT,
  ADD COLUMN IF NOT EXISTS hometown         TEXT,
  ADD COLUMN IF NOT EXISTS school           TEXT,
  ADD COLUMN IF NOT EXISTS about_me         TEXT;

-- ============================================================
-- 002_enable_pgvector.sql
-- Enables the pgvector extension for VECTOR type support.
--
-- ORDERING NOTE: Logically this must execute before
-- 001_initial_schema.sql (which uses VECTOR(768)). When run
-- via `supabase db push` (alphabetical order), 001 runs first
-- — so 001 also includes this CREATE EXTENSION statement as
-- its very first line to self-bootstrap.
--
-- This file exists as an explicit, auditable artifact for:
--   - Manual execution contexts
--   - `supabase db reset` on a fresh project
--   - Clarity that pgvector is a conscious dependency
-- ============================================================

CREATE EXTENSION IF NOT EXISTS vector;

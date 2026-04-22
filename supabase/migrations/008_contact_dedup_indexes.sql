-- ============================================================
-- 008_contact_dedup_indexes.sql
-- Partial unique indexes for server-side dedup enforcement.
-- WHERE clauses exclude NULLs so contacts without email or
-- LinkedIn URL remain unrestricted (no false conflicts).
-- These complement client-side dedup in LinkedInImportService
-- and catch any bug that bypasses the Swift layer.
-- ============================================================

CREATE UNIQUE INDEX IF NOT EXISTS contacts_linkedin_url_unique
    ON contacts (user_id, lower(linkedin_url))
    WHERE linkedin_url IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS contacts_email_unique
    ON contacts (user_id, lower(email))
    WHERE email IS NOT NULL;

-- ============================================================
-- 004_vector_search_functions.sql
-- pgvector similarity search RPCs called from iOS via
--   supabase.rpc("match_contacts", ...)
--   supabase.rpc("match_contacts_for_goal", ...)
--
-- Both functions are LANGUAGE sql STABLE (read-only, safe to
-- cache across a transaction within the same query).
-- CREATE OR REPLACE is inherently idempotent.
--
-- Security: SECURITY INVOKER (default). RLS on contacts and
-- goals tables enforces user isolation — these functions cannot
-- leak another user's data even if called with a forged UUID.
-- The user_id_filter parameter is an explicit pre-filter that
-- scopes the pgvector index scan to one user's rows before the
-- distance operator runs, improving performance significantly.
-- ============================================================

-- ============================================================
-- match_contacts
-- Semantic search: find contacts similar to a query embedding.
--
-- Called from iOS SearchViewModel when the user types a natural
-- language query. iOS embeds the query via Gemini
-- text-embedding-004 (task type: RETRIEVAL_QUERY) and passes
-- the result as query_embedding.
--
-- Parameters:
--   query_embedding  768-dim query vector from Gemini
--   user_id_filter   auth.uid() from the iOS client
--   match_threshold  minimum cosine similarity (0.0–1.0)
--                    default 0.5 — filters low-quality matches
--   match_count      max results to return, default 10
--
-- Returns contacts ordered by similarity descending (highest first).
-- ============================================================

CREATE OR REPLACE FUNCTION match_contacts(
  query_embedding  VECTOR(768),
  user_id_filter   UUID,
  match_threshold  FLOAT DEFAULT 0.5,
  match_count      INT   DEFAULT 10
)
RETURNS TABLE (
  id                UUID,
  name              TEXT,
  company           TEXT,
  title             TEXT,
  how_met           TEXT,
  warmth_score      FLOAT,
  last_contacted_at TIMESTAMPTZ,
  similarity        FLOAT
)
LANGUAGE sql STABLE
AS $$
  SELECT
    id,
    name,
    company,
    title,
    how_met,
    warmth_score,
    last_contacted_at,
    -- Cosine similarity = 1 - cosine distance.
    -- <=> operator returns cosine distance; subtracting from 1
    -- gives similarity in range [0, 1] for normalized vectors.
    1 - (embedding <=> query_embedding) AS similarity
  FROM contacts
  WHERE user_id = user_id_filter
    AND embedding IS NOT NULL            -- Skip contacts without embeddings yet
    AND 1 - (embedding <=> query_embedding) > match_threshold
  ORDER BY embedding <=> query_embedding -- ASC distance = DESC similarity
  LIMIT match_count;
$$;

-- ============================================================
-- match_contacts_for_goal
-- Goal-triggered surfacing: find contacts relevant to a goal.
--
-- Called from iOS GoalsPanelView for each active goal.
-- Uses an implicit cross-join between contacts and goals,
-- scoped to a single goal row and a single user.
--
-- Lower default threshold (0.45 vs 0.5) because goal→contact
-- semantic similarity is inherently looser than a direct
-- search query. A PM-focused goal should surface adjacent
-- contacts (founders, engineers) not just exact role matches.
--
-- Parameters:
--   goal_id_param   UUID of the specific goal to match against
--   user_id_filter  auth.uid() from iOS
--   match_threshold minimum cosine similarity, default 0.45
--   match_count     max results per goal card, default 5
-- ============================================================

CREATE OR REPLACE FUNCTION match_contacts_for_goal(
  goal_id_param   UUID,
  user_id_filter  UUID,
  match_threshold FLOAT DEFAULT 0.45,
  match_count     INT   DEFAULT 5
)
RETURNS TABLE (
  id         UUID,
  name       TEXT,
  company    TEXT,
  title      TEXT,
  similarity FLOAT
)
LANGUAGE sql STABLE
AS $$
  SELECT
    c.id,
    c.name,
    c.company,
    c.title,
    1 - (c.embedding <=> g.embedding) AS similarity
  FROM contacts c, goals g
  WHERE g.id        = goal_id_param
    AND c.user_id   = user_id_filter
    AND c.embedding IS NOT NULL    -- Contact must have been embedded
    AND g.embedding IS NOT NULL    -- Goal must have been embedded
    AND 1 - (c.embedding <=> g.embedding) > match_threshold
  ORDER BY c.embedding <=> g.embedding
  LIMIT match_count;
$$;

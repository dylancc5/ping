# Ping — Architecture

## Stack Overview

```
┌─────────────────────────────────────────────────────────┐
│                    iOS App (Swift/SwiftUI)               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │
│  │ Ping Tab │  │ Network  │  │  Search  │  │Profile │  │
│  └──────────┘  └──────────┘  └──────────┘  └────────┘  │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              SwiftUI + Swift Concurrency            │ │
│  └─────────────────────────────────────────────────────┘ │
│  ┌────────────────────┐  ┌──────────────────────────┐    │
│  │   Supabase Swift   │  │      Gemini SDK (iOS)    │    │
│  │       Client       │  │  Flash + Embedding-004   │    │
│  └────────────────────┘  └──────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
                    │                    │
                    ▼                    ▼
┌─────────────────────────┐    ┌──────────────────────┐
│       Supabase          │    │    Google Gemini API  │
│  ┌──────────────────┐   │    │  text-embedding-004  │
│  │  Postgres +      │   │    │  gemini-2.0-flash    │
│  │  pgvector        │   │    └──────────────────────┘
│  └──────────────────┘   │
│  ┌──────────────────┐   │
│  │  Supabase Auth   │   │
│  │  (Apple + Google)│   │
│  └──────────────────┘   │
│  ┌──────────────────┐   │
│  │  Edge Functions  │   │
│  │  (Nudge CRON)    │   │
│  └──────────────────┘   │
│  ┌──────────────────┐   │
│  │  Realtime        │   │
│  │  (live updates)  │   │
│  └──────────────────┘   │
└─────────────────────────┘
```

## Technology Decisions

| Layer | Choice | Rationale |
|-------|--------|-----------|
| iOS framework | SwiftUI | Modern, declarative, iOS 17+ features (NavigationStack, Observable) |
| iOS min version | iOS 17 | Needed for `@Observable`, `NavigationStack`, Swift Concurrency |
| Package manager | Swift Package Manager | Built-in, no CocoaPods/Carthage complexity |
| Backend | Supabase | Postgres + auth + realtime + storage + edge functions in one free-tier service |
| Vector DB | pgvector (on Supabase) | Zero additional cost, no separate Pinecone/Weaviate. Good enough for < 100k contacts |
| AI - Embeddings | Gemini text-embedding-004 | Free tier, 768-dim, strong semantic quality, same API ecosystem as drafts |
| AI - Drafts | Gemini 2.0 Flash | Free tier (15 RPM / 1M TPM / 1500 RPD), fast (~1-2s), large context |
| AI key location | iOS Keychain | Acceptable for MVP/TestFlight. Not in source code. Migrate to Edge Functions post-launch if needed. |
| Auth | Supabase Auth (Apple + Google) | Apple required by App Store. Google enables OAuth scopes for Calendar/Gmail. |
| Push notifications | APNs via Supabase Edge Function | Supabase has native APNs support through Edge Functions |
| Voice transcription | iOS Speech framework (SFSpeechRecognizer) | On-device, free, privacy-preserving, no network needed for transcription |

## Database Schema

### Overview
All tables live in Supabase Postgres with Row Level Security (RLS) enabled. Every user can only read/write their own data.

### `profiles`
Extension of Supabase `auth.users`. Created automatically on signup via trigger.

```sql
CREATE TABLE profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name     TEXT,
  avatar_url    TEXT,
  tone_samples  TEXT[],          -- Array of user's writing samples for tone calibration
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);
```

### `contacts`
Core entity. One row per contact per user.

```sql
CREATE TABLE contacts (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name                TEXT NOT NULL,
  company             TEXT,
  title               TEXT,
  how_met             TEXT NOT NULL,     -- "SCET career fair", "Berkeley CS 189 class"
  notes               TEXT,              -- Free-form context
  linkedin_url        TEXT,
  email               TEXT,
  phone               TEXT,
  tags                TEXT[],            -- Optional: ["VC", "Berkeley", "ML"]
  embedding           VECTOR(768),       -- Gemini text-embedding-004
  warmth_score        FLOAT DEFAULT 1.0, -- 0.0 (cold) to 1.0 (hot), computed
  last_contacted_at   TIMESTAMPTZ,
  met_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Index for vector similarity search
CREATE INDEX contacts_embedding_idx ON contacts
  USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Index for user's contacts ordered by recency
CREATE INDEX contacts_user_warmth_idx ON contacts (user_id, warmth_score DESC);
```

### `interactions`
Log of every meaningful event with a contact.

```sql
CREATE TYPE interaction_type AS ENUM (
  'met',        -- Initial meeting
  'message',    -- Sent a message
  'call',       -- Had a call/meeting
  'note',       -- Added a note
  'nudge_sent'  -- Ping sent a nudge
);

CREATE TABLE interactions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id   UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type         interaction_type NOT NULL,
  notes        TEXT,
  occurred_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX interactions_contact_idx ON interactions (contact_id, occurred_at DESC);
```

### `nudges`
Scheduled nudge records. Created by the Edge Function CRON job.

```sql
CREATE TYPE nudge_status AS ENUM ('pending', 'delivered', 'opened', 'acted', 'snoozed', 'dismissed');

CREATE TABLE nudges (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id      UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status          nudge_status DEFAULT 'pending',
  reason          TEXT,               -- "You haven't reached out in 3 weeks"
  draft_message   TEXT,               -- AI-generated draft, null until generated
  scheduled_at    TIMESTAMPTZ NOT NULL,
  delivered_at    TIMESTAMPTZ,
  acted_at        TIMESTAMPTZ,
  snoozed_until   TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX nudges_user_pending_idx ON nudges (user_id, scheduled_at)
  WHERE status = 'pending';
```

### `goals`
User-defined intent for goal-triggered contact surfacing.

```sql
CREATE TABLE goals (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  text        TEXT NOT NULL,      -- "Applying to Stripe for PM role"
  embedding   VECTOR(768),        -- Embedded for similarity matching against contacts
  active      BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

### Row Level Security

```sql
-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE nudges ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;

-- Policies: users can only access their own data
CREATE POLICY "users_own_profile" ON profiles
  FOR ALL USING (id = auth.uid());

CREATE POLICY "users_own_contacts" ON contacts
  FOR ALL USING (user_id = auth.uid());

CREATE POLICY "users_own_interactions" ON interactions
  FOR ALL USING (user_id = auth.uid());

CREATE POLICY "users_own_nudges" ON nudges
  FOR ALL USING (user_id = auth.uid());

CREATE POLICY "users_own_goals" ON goals
  FOR ALL USING (user_id = auth.uid());
```

## Data Flows

### 1. Contact Capture Flow

```
User taps "+" → Quick-Capture sheet opens
  │
  ├── Text mode: fills form fields
  │
  └── Voice mode: iOS SFSpeechRecognizer transcribes on-device
                     │
                     └── iOS sends transcript to Gemini Flash
                           → Gemini extracts: name, company, title, how_met, notes
                           → Fields auto-populated in form

User taps "Save"
  │
  ├── Contact record inserted into Supabase (contacts table)
  │
  └── Background Task: iOS calls Gemini text-embedding-004
        → 768-dim embedding generated from: name + company + title + how_met + notes
        → PATCH contacts SET embedding = [...] WHERE id = ?
```

### 2. Semantic Search Flow

```
User types in Search tab: "who do I know at Google in product"
  │
  └── iOS calls Gemini text-embedding-004 on the query
        → 768-dim query embedding
        │
        └── Supabase RPC: match_contacts(query_embedding, threshold, limit)
              → pgvector cosine similarity search
              → Returns top-K contacts ordered by similarity
              │
              └── iOS renders results with similarity-derived snippets
```

### 3. Goal-Triggered Surfacing Flow

```
User adds goal: "Applying to Stripe for PM role"
  │
  ├── Goal record inserted into goals table
  │
  └── Background: iOS embeds goal text → stores in goals.embedding

Goals Panel (Search tab):
  │
  └── For each active goal:
        Supabase RPC: match_contacts_for_goal(goal_id, threshold, limit)
        → Cosine similarity between goal.embedding and contacts.embedding
        → Returns relevant contacts with score
        → iOS renders as "Relevant for: Applying to Stripe"
```

### 4. Nudge Scheduling Flow (Edge Function CRON)

```
Daily CRON job (Supabase Edge Function, runs at 9am user local time):
  │
  └── For each user, score all contacts:
        score = f(
          days_since_last_contact,     -- recency decay
          interaction_frequency,       -- engagement history
          meeting_context_urgency,     -- "follow up asap" vs casual
          warmth_score                 -- current warmth trend
        )
        │
        └── Contacts above nudge threshold:
              → Check: no pending nudge already exists
              → INSERT INTO nudges (contact_id, scheduled_at, reason)
              → Trigger APNs push notification to user's device
```

### 5. AI Draft Generation Flow

```
User opens nudge card or contact detail
  │
  └── iOS calls Gemini 2.0 Flash with:
        - System prompt: tone calibration from profile.tone_samples
        - Contact context: name, company, how_met, notes, last interaction
        - Nudge reason: "You haven't reached out since meeting at SCET fair"
        - Draft instructions: "Write a casual, warm, 2-3 sentence follow-up"
        │
        └── Gemini returns 1-2 draft options
              → iOS presents in Draft screen for editing
              → User edits and sends manually via Messages/Gmail/LinkedIn
```

## Supabase Edge Functions

### `score-contacts` (CRON: daily)
- Recalculates `warmth_score` for all contacts based on interaction recency/frequency
- Creates pending nudge records for contacts crossing the nudge threshold
- Triggers APNs push notifications via Supabase push service

### `send-push` (triggered)
- Sends APNs push notification with nudge preview
- Payload: contact name, last context snippet, draft preview (first ~80 chars)

## iOS App Architecture (Swift)

### Pattern: MVVM + Swift Concurrency

```
App
├── PingApp.swift              — @main, Supabase client init, auth state
├── Models/
│   ├── Contact.swift          — struct Contact, Codable, Identifiable
│   ├── Interaction.swift      — struct Interaction
│   ├── Nudge.swift            — struct Nudge
│   └── Goal.swift             — struct Goal
├── Services/
│   ├── SupabaseService.swift  — CRUD operations, realtime subscriptions
│   ├── GeminiService.swift    — embeddings + draft generation
│   ├── NudgeService.swift     — nudge scheduling logic (local fallback)
│   └── SpeechService.swift    — SFSpeechRecognizer wrapper
├── ViewModels/
│   ├── PingViewModel.swift    — @Observable, nudges feed state
│   ├── NetworkViewModel.swift — @Observable, contacts list + search
│   ├── SearchViewModel.swift  — @Observable, semantic search + goals
│   └── ContactViewModel.swift — @Observable, single contact detail
├── Views/
│   ├── Tabs/
│   │   ├── PingTabView.swift
│   │   ├── NetworkTabView.swift
│   │   ├── SearchTabView.swift
│   │   └── ProfileTabView.swift
│   ├── Contacts/
│   │   ├── ContactListView.swift
│   │   ├── ContactCardView.swift
│   │   ├── ContactDetailView.swift
│   │   └── QuickCaptureView.swift
│   ├── Nudges/
│   │   ├── NudgeCardView.swift
│   │   └── MessageDraftView.swift
│   ├── Search/
│   │   ├── SemanticSearchView.swift
│   │   └── GoalsPanelView.swift
│   └── Components/
│       ├── WarmthDot.swift
│       ├── ContactRowView.swift
│       └── PingButton.swift
└── Extensions/
    ├── Color+Ping.swift       — design token colors
    └── Date+Ping.swift        — "3 weeks ago" formatting
```

## Security Notes

- **Gemini API key:** Stored in iOS Keychain, never in source code or Info.plist. Injected at first launch via a setup screen (user pastes key, or we provide a pooled key for MVP).
- **Supabase anon key:** Safe to be in the app bundle (protected by RLS policies). Not a secret.
- **RLS on all tables:** No user can read another user's data, even with a valid JWT.
- **Google OAuth tokens:** Stored in Keychain via iOS credential store, not Supabase.
- **No PII in embeddings:** Contact embeddings are opaque vectors — cannot be reversed to reconstruct contact data without the source text.

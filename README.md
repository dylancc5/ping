# Ping

**Your relationship memory.**

Ping remembers who you met, when to reach out, and what to say — so your network works for you without the anxiety of figuring it all out yourself.

---

## What It Is

A native iOS app for students and early-career professionals who meet valuable people but lose touch because they don't know when or what to say.

Core loop: **Meet → Log (< 30s) → Get nudged → Edit AI draft → Send**

The user always sends manually. Authenticity is everything.

---

## Design Docs

All architecture, design, and product decisions live in [`/design-docs/`](./design-docs/):

| Doc                                                                     | Contents                                                  |
| ----------------------------------------------------------------------- | --------------------------------------------------------- |
| [01 — Product Vision](./design-docs/01-product-vision.md)               | What Ping is, who it's for, JTBD, competitive positioning |
| [02 — Architecture](./design-docs/02-architecture.md)                   | Stack, Supabase schema, data flows, iOS structure         |
| [03 — Design System](./design-docs/03-design-system.md)                 | Colors, typography, components, motion                    |
| [04 — Navigation & Screens](./design-docs/04-navigation-and-screens.md) | Screen inventory, wireframes, user flows                  |
| [05 — AI Pipeline](./design-docs/05-ai-pipeline.md)                     | Embeddings, nudge algorithm, draft generation             |
| [06 — Integrations](./design-docs/06-integrations.md)                   | LinkedIn, Google (Contacts/Calendar/Gmail), Share Sheet   |
| [07 — Engineering Setup](./design-docs/07-engineering-setup.md)         | Xcode setup, Supabase config, secrets management          |

---

## Stack

- **iOS** — Swift / SwiftUI, iOS 17+
- **Backend** — Supabase (Postgres + pgvector + Edge Functions)
- **AI** — HuggingFace inference (drafts + contact extraction from voice) + Gemini text-embedding-004 (semantic search)
- **Auth** — Sign in with Apple + Sign in with Google

---

## Features

### Core Loop

1. **Frictionless contact capture** — voice (hold-to-speak) or text, under 30 seconds. AI extracts name, company, title, and notes from speech.
2. **Semantic search** — natural language + goal-triggered contact surfacing using pgvector embeddings.
3. **Smart adaptive nudges** — AI-scored timing, push notification with draft preview.
4. **AI message drafting** — tone-calibrated via user writing samples, always user-edited and user-sent.
5. **LinkedIn sync** — CSV import + iOS Share Sheet extension.
6. **Google sync** — Contacts import, Calendar scan, Gmail suggestions.

### Onboarding

- **Guided interactive tutorial** — 5-step walkthrough (Welcome → Import → About You → First Capture → Done) that teaches by doing. Users finish with real data in the app. Replayable from Profile → Replay Tutorial.

### Voice Input (STT)

- **VoiceInputField** — reusable hold-to-speak mic component embedded in all freeform text fields:
  - QuickCapture Notes
  - Edit Contact: How You Met + Notes
  - Log Interaction: Note and Interaction Notes
- Streams partial transcripts live; appends to existing text rather than replacing it.
- Uses `SFSpeechRecognizer` + `AVAudioEngine` with full permission handling and Settings deep-link fallback.

### About You Profile

- Users describe themselves (career role/company/industry/seniority, interests, city, hometown, school, freeform "what I'm looking for").
- Editable from Profile tab → About You, and presented as a skippable tutorial step.
- Feeds into the recommendation engine: `CommonalityMatcher` surfaces contacts who share interests, industry, school, or company with the user; `RecommendationViewModel` personalizes the position-tier heuristic based on user seniority.

---

## Architecture Notes

### Navigation

TabView with 4 tabs: **Ping** (nudges), **Network** (contacts), **Search** (semantic + recommendations), **You** (profile).

### State Management

Modern Swift `@Observable` macro throughout (not `ObservableObject` in new code). `AuthViewModel` is `ObservableObject` for legacy compatibility with `@StateObject` / `@ObservedObject` in the TabView host.

### Persistence

- **Supabase** — all contacts, interactions, nudges, goals, and user profiles.
- **Keychain** — auth tokens via `KeychainHelper`.
- **`@AppStorage`** — `hasCompletedTutorial`, tone sample cache flag, UI preferences.

### Database Schema (migrations)

| Migration | Contents                                                         |
| --------- | ---------------------------------------------------------------- |
| 001       | Initial schema (contacts, profiles, interactions, nudges, goals) |
| 002       | Enable pgvector extension                                        |
| 003       | RLS policies                                                     |
| 004       | Vector search functions                                          |
| 005       | Triggers (updated_at, profile auto-create on signup)             |
| 006       | Device token for push notifications                              |
| 007       | App config (remote config table)                                 |
| 008       | Contact dedup indexes                                            |
| 009       | About You profile fields (career, interests, location)           |

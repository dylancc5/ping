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
- **AI** — Gemini 2.0 Flash (drafts) + Gemini text-embedding-004 (semantic search)
- **Auth** — Sign in with Apple + Sign in with Google

---

## V1 Features

1. Frictionless contact capture — voice or text, under 30 seconds
2. Semantic search — natural language + goal-triggered contact surfacing
3. Smart adaptive nudges — AI-scored timing, push notification with draft preview
4. AI message drafting — tone-calibrated, always user-edited and user-sent
5. LinkedIn sync — CSV import + iOS Share Sheet extension
6. Google sync — Contacts import, Calendar scan, Gmail suggestions

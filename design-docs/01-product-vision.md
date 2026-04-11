# Ping — Product Vision

## What Is Ping?

Ping is a relationship memory app for students and early-career professionals. It remembers who you've met, tracks the context of those relationships, and nudges you at the right time with an AI-drafted message ready to edit and send — so your network works for you without the anxiety of figuring it all out yourself.

## The Problem

The moment you meet someone valuable — at a career fair, a class, a networking event — the clock starts ticking. Within days, you've lost the context. Within weeks, reaching out starts to feel awkward. Within months, the connection is gone.

The failure isn't lack of intent. Everyone means to follow up. The failures are:

1. **Context loss** — who you met, where, what you talked about, what was relevant
2. **Timing blindness** — not knowing when the right moment to reach out is
3. **Composition anxiety** — not knowing what to say, overthinking it, procrastinating
4. **Fragmentation** — contacts are scattered across LinkedIn, notes apps, texts, memory

Existing tools don't solve this. LinkedIn is a broadcasting platform, not a relationship tool. Notes apps are digital graveyards. CRMs feel like work. Ping is none of those things.

## The Solution

Ping is relationship memory infrastructure. It:
- Captures who you met in under 30 seconds (voice or text)
- Stores the context — where, what was relevant, what you want to do with this relationship
- Surfaces the right person at the right moment through smart adaptive nudges
- Drafts a message calibrated to your voice and the relationship context
- Gets out of the way — you always review and send manually

The result: reconnections feel like they just happened to happen. Your network starts working for you.

## Value Proposition

> "Ping is your relationship memory — it remembers who you met, when to reach out, and what to say, so your network works for you without the anxiety of figuring it out yourself."

## Target User

**Persona: The Overthinking Networker**

A student or early-career professional (undergrad, grad student, new grad, entry-level analyst or engineer) who:
- Meets valuable people regularly at classes, career fairs, clubs, events, internships
- Has strong intent to follow up but consistently doesn't
- Fears reaching out at the wrong time or sounding transactional
- Is scattered across 4-6 tools with no single system for tracking relationships
- Values authenticity — would never want contacts to know they're using a tool

**Where they live:** LinkedIn, Apple Notes, phone contacts, Luma/Partiful, Google Calendar

**What they say:**
- "My notes app is basically a graveyard."
- "I always tell myself I'll follow up later... and later never comes."
- "I applied for a job and realized too late my friend's dad worked there."
- "If I had a reminder and a suggested message that sounds normal, I'd just send it."

## Jobs To Be Done

**Primary JTBD:**
> When a student or early-career professional meets someone valuable, they want to maintain that connection and activate it at the right moment — so they can access warm referrals, mentorship, and off-market opportunities — without the anxiety, procrastination, and friction of figuring out when and how to reach out.

**Secondary JTBDs:**
- When applying for a job, surface everyone I know at that company
- When attending an event, remember who I've met in this context before
- When someone I haven't talked to in months reaches out, have context on who they are

## The Customer Journey

| Stage | What Happens | What Ping Does |
|-------|-------------|----------------|
| **Meet** | Career fair, class, event | Quick-capture: log name, where, key detail in < 30 seconds |
| **Forget** | 1-3 weeks pass, life gets busy | Holds context so the follow-up window doesn't quietly close |
| **Hesitate** | Wants to reach out but doesn't know what to say | Nudges at the right moment with a draft message calibrated to the relationship |
| **Miss** | Sees a job posting, realizes too late they know someone | Goal-triggered surfacing: "You're applying to Stripe — you met a PM there" |
| **Activate** | Receives a nudge, edits the draft, sends it | Confident, low-anxiety reconnection — feels natural |
| **Compound** | Connection responds, relationship deepens | Tracks the relationship going forward — no connection falls through the cracks |

## Brand Identity

**Name:** Ping — active, kinetic, precise. Like a sonar ping: you send a signal, it comes back.

**Personality:** Calm, confident, warm. Not a hustle-culture networking tool. Not a corporate CRM. More like a brilliant friend who remembers everything and knows when to nudge you.

**Positioning:** Anti-CRM. Anti-broadcast. Anti-transactional. Pro-human. Pro-serendipity. Pro-warmth.

**One-word essence:** Intentional.

## Hard Constraints

These are non-negotiable product principles:

1. **No auto-send, ever.** Every message is drafted for the user to edit and send. Authenticity is existential to the brand. Contacts must never feel like they're receiving automated outreach.

2. **< 30 second capture.** If logging a contact feels like work, nobody will do it. The capture flow must be effortless at a loud networking event with one free thumb.

3. **Feels human, not CRM.** No scores, pipelines, or "relationship stages." No language borrowed from sales tooling. Every UI decision should feel like a personal notebook, not a database.

4. **Privacy-first.** Contact data is personal. No third-party tracking. No selling data. User controls their network completely.

## Success Metrics (v1)

- **Capture rate:** % of users who log ≥ 5 contacts in first week
- **Nudge response rate:** % of nudges where user opens draft (target: > 40%)
- **Message send rate:** % of opened drafts where user sends the message (target: > 25%)
- **Day-30 retention:** % of users active 30 days after signup (target: > 35%)
- **Qualitative:** User says "Ping helped me reconnect with someone I would have lost touch with"

## Competitive Landscape

| Tool | What it does | Why it's not Ping |
|------|-------------|-------------------|
| LinkedIn | Professional broadcasting + connection graph | Storage, not activation. No relationship context. No nudges. |
| Clay | Power-user CRM with data enrichment | Complex, expensive, feels like work. Overkill for students. |
| Notion/Apple Notes | Manual note-taking | You have to go back to them. Nobody does. |
| Dex | Personal CRM with reminders | Closer, but manual, no AI drafts, generic reminders. |
| Covve | AI networking assistant | Exists but poor UX, not iOS-native, limited AI depth. |

**Ping's wedge:** AI-drafted messages + smart timing + sub-30-second capture. Everything else is table stakes.

## V1 Scope

**Ship in v1:**
1. Frictionless contact capture (voice + text, < 30s)
2. Semantic search over contacts (natural language + goal-triggered surfacing)
3. Smart adaptive nudges with AI timing
4. AI message drafting (Gemini Flash, tone-calibrated, always user-sent)
5. LinkedIn sync (CSV import + iOS Share Sheet extension)
6. Google sync (Contacts import, Calendar scan, Gmail contact suggestions)
7. Push notifications (preview + one-tap to open draft)

**Not in v1:**
- Relationship health scoring UI
- Cohort/group views
- Twitter/X or other social platform sync
- Auto-send or scheduling
- Web app
- Android

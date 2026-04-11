# Ping — Navigation & Screens

## Navigation Architecture

### Root: Tab Bar (4 tabs)

```
┌─────────────────────────────────────────┐
│                                         │
│          [ Content Area ]               │
│                                         │
├─────────────────────────────────────────┤
│  🔔 Ping   👥 Network  🔍 Search  👤 You │
└─────────────────────────────────────────┘
```

**Tab order rationale:**
- **Ping** (bell): The daily driver. "What should I do today?" — nudges and cooling relationships
- **Network** (people): "Who do I know?" — full contact list, card view, quick-add FAB
- **Search** (magnifying glass): "Who's relevant right now?" — semantic search + active goals
- **You** (person circle): Settings, integrations, tone calibration, profile

Active tab indicator: `accent` coral color on icon + label. All other tabs: `text-muted`.

### Navigation Patterns
- **Tab bar** — root navigation between the 4 main areas
- **NavigationStack** — within each tab for drill-down (list → detail)
- **Sheet** — Quick-Capture (bottom sheet), Message Draft (full-screen sheet), goal add
- **NavigationLink** — contact row → contact detail

No hamburger menus, no sidebars, no nested tab bars.

---

## Screen Inventory

---

### 1. Onboarding / Auth

#### 1a. Welcome Screen

**Purpose:** First impression. Set the brand tone. Get them signed in.

```
┌────────────────────────────────────────┐
│                                        │
│                                        │
│           ●  Ping                      │
│                                        │
│   Your relationship memory.            │
│                                        │
│   Remember who you met.                │
│   Know when to reach out.              │
│   Say exactly the right thing.         │
│                                        │
│                                        │
│   ┌──────────────────────────────┐     │
│   │     Sign in with Apple  🍎   │     │
│   └──────────────────────────────┘     │
│   ┌──────────────────────────────┐     │
│   │    Continue with Google  G   │     │
│   └──────────────────────────────┘     │
│                                        │
│   By signing in, you agree to our      │
│   Terms of Service and Privacy Policy  │
└────────────────────────────────────────┘
```

**Design notes:**
- Warm white background, minimal decoration
- App icon (coral dot) above the wordmark
- Tagline in `.title2` weight
- Three benefit lines in `.body`, `text-secondary`
- Apple button: black fill (required by Apple HIG)
- Google button: `surface-2` fill, `text-primary`

#### 1b. Tone Setup (post-login, first-time only)

**Purpose:** Capture 2-3 sentences in the user's voice so AI drafts sound like them.

```
┌────────────────────────────────────────┐
│                                        │
│  How do you usually write?             │
│                                        │
│  Paste or type a few sentences from    │
│  a recent message you sent — so Ping   │
│  can match your voice.                 │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ "Hey! Great catching up at the   │  │
│  │ event — let's grab coffee soon.  │  │
│  │ I'll send you a link to the      │  │
│  │ article we talked about."        │  │
│  └──────────────────────────────────┘  │
│                                        │
│  This is only used to calibrate your   │
│  message drafts. Never shared.         │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │           Continue               │  │
│  └──────────────────────────────────┘  │
│              Skip for now              │
└────────────────────────────────────────┘
```

---

### 2. Ping Tab (Nudge Feed)

**Purpose:** "What should I do today?" — The daily driver screen.

```
┌────────────────────────────────────────┐
│  Ping                              ⚙   │
├────────────────────────────────────────┤
│                                        │
│  TODAY                                 │
│  ──────────────────────────────────    │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ [MC]  Marcus Chen           🔔   │  │
│  │       PM at Google               │  │
│  │       Met at SCET fair · 9d ago  │  │
│  │  ─────────────────────────────   │  │
│  │  "Hey Marcus, it was really      │  │
│  │   great meeting you at..."       │  │
│  │                [Draft message →] │  │
│  └──────────────────────────────────┘  │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ [SK]  Sarah Kim             🔔   │  │
│  │       Stripe · PM                │  │
│  │       Met at Cal Hacks · 12d ago │  │
│  │  ─────────────────────────────   │  │
│  │  "Hi Sarah! I wanted to follow   │  │
│  │   up from Cal Hacks..."          │  │
│  │                [Draft message →] │  │
│  └──────────────────────────────────┘  │
│                                        │
│  COOLING DOWN                          │
│  ──────────────────────────────────    │
│                                        │
│  [JP] Jordan Park · 3 weeks ──── ● →  │
│  [AR] Alex Rivera · 5 weeks ──── ● →  │
│                                        │
└────────────────────────────────────────┘
```

**Sections:**
- **TODAY** — contacts with pending nudges (scheduled for today)
- **COOLING DOWN** — contacts with `warmth_score` dropping, no active nudge yet (compact list rows, warmth dot)

**Empty state:**
- If no nudges and no cooling contacts: "All caught up — your network looks great today 🌿"
- Full-width, centered, with a soft illustration

**Interactions:**
- Tap nudge card → expands / navigates to `MessageDraftView` with pre-loaded draft
- Tap cooling row → navigates to `ContactDetailView`
- Swipe nudge card right → Snooze (show date picker)
- Swipe nudge card left → Dismiss

---

### 3. Network Tab

**Purpose:** "Who do I know?" — browse, search, add contacts.

#### 3a. Network List (default view)

```
┌────────────────────────────────────────┐
│  Network                          ⊞    │  ← toggle card view
├────────────────────────────────────────┤
│  🔍 Search by name or company...       │
├────────────────────────────────────────┤
│                                        │
│  ALL (24)                              │
│  ──────────────────────────────────    │
│                                        │
│  [MC] Marcus Chen               ● →   │
│       Google · PM · 9 days ago         │
│                                        │
│  [SK] Sarah Kim                 ● →   │
│       Stripe · PM · 12 days ago        │
│                                        │
│  [JP] Jordan Park               ● →   │
│       YC W24 · Founder · 3 weeks       │
│                                        │
│  [AR] Alex Rivera               ● →   │
│       Sequoia · Analyst · 5 weeks      │
│                                        │
│  ────────────────── more ──────────    │
│                                        │
│                         ┌───┐          │
│                         │ + │          │
│                         └───┘          │
└────────────────────────────────────────┘
```

**Notes:**
- Local text search filters list in real-time (not semantic search — that's in the Search tab)
- Sorted by `last_contacted_at` descending by default
- Warmth dot is the colored circle after the name
- `⊞` icon toggles to card view
- FAB (`+`) opens `QuickCaptureView` sheet

#### 3b. Network Card View (toggle)

```
┌────────────────────────────────────────┐
│  Network                          ☰    │  ← toggle list view
├────────────────────────────────────────┤
│  🔍 Search...                          │
├────────────────────────────────────────┤
│                                        │
│  ┌─────────────┐  ┌─────────────┐     │
│  │    [MC]     │  │    [SK]     │     │
│  │ Marcus Chen │  │  Sarah Kim  │     │
│  │  Google PM  │  │  Stripe PM  │     │
│  │      ●      │  │      ●      │     │
│  │  9 days ago │  │ 12 days ago │     │
│  └─────────────┘  └─────────────┘     │
│                                        │
│  ┌─────────────┐  ┌─────────────┐     │
│  │    [JP]     │  │    [AR]     │     │
│  │Jordan Park  │  │ Alex Rivera │     │
│  │ YC Founder  │  │  Sequoia ✦  │     │
│  │      ●      │  │      ●      │     │
│  │  3 weeks    │  │  5 weeks    │     │
│  └─────────────┘  └─────────────┘     │
│                                        │
└────────────────────────────────────────┘
```

- 2-column grid
- Cards: 14pt radius, `surface` background, `pingCardShadow()`
- Warmth dot centered below name

---

### 4. Contact Detail Screen

**Purpose:** "Who is this person and what should I do right now?"

```
┌────────────────────────────────────────┐
│ ← Network                              │
├────────────────────────────────────────┤
│                                        │
│          [MC]   ●                      │
│        Marcus Chen                     │
│      PM at Google · Hot                │
│   marcus@google.com  (linkedin icon)   │
│                                        │
├────────────────────────────────────────┤
│                                        │
│  ┌──────────────────────────────────┐  │
│  │  "Hey Marcus! It was so great    │  │
│  │   meeting you at the SCET fair.  │  │
│  │   Would love to stay in touch —  │  │
│  │   open to a quick coffee chat?"  │  │
│  │                                  │  │
│  │          [Edit & Send →]         │  │
│  └──────────────────────────────────┘  │
│         ↺ Regenerate draft             │
│                                        │
├────────────────────────────────────────┤
│                                        │
│  CONTEXT                               │
│  ──────────────────────────────────    │
│  📍 Met at SCET Career Fair            │
│  📅 March 24, 2026                     │
│  📝 Interested in ML infra roles,      │
│     has Berkeley connections           │
│  🏷  [ML] [Berkeley] [Google]          │
│                                        │
├────────────────────────────────────────┤
│                                        │
│  HISTORY                               │
│  ──────────────────────────────────    │
│  • Apr 2   Nudge sent                  │
│  • Mar 24  Met at SCET fair            │
│                                        │
│  [+ Add note]  [Log interaction]       │
│                                        │
└────────────────────────────────────────┘
```

**Design notes:**
- Avatar: large initials circle (56pt), warmth dot in top-right of avatar
- Draft card is the visual hero — highest contrast, most prominent
- Context and history sections are secondary (`surface-2` grouped style)
- "Edit & Send →" → navigates to full `MessageDraftView`
- "Regenerate draft" → calls Gemini again with same context, different temperature

---

### 5. Quick Capture Sheet

**Purpose:** Log a contact in under 30 seconds.

**Presentation:** `.sheet` from FAB or anywhere, `.presentationDetents([.large])`

```
┌────────────────────────────────────────┐
│          [── drag handle ──]           │
│                                        │
│  Log a Contact                    ✕   │
│                                        │
│  Name *                                │
│  ┌──────────────────────────────────┐  │
│  │                                  │  │
│  └──────────────────────────────────┘  │
│                                        │
│  Where did you meet? *                 │
│  ┌──────────────────────────────────┐  │
│  │                                  │  │
│  └──────────────────────────────────┘  │
│                                        │
│  Notes                                 │
│  ┌──────────────────────────────────┐  │
│  │                                  │  │
│  │                                  │  │
│  └──────────────────────────────────┘  │
│                                        │
│          ┌──────────────────┐          │
│          │   🎤  Speak      │          │
│          └──────────────────┘          │
│          hold to speak, release to fill│
│                                        │
│  ┌──────────────────────────────────┐  │
│  │          Save Contact            │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

**Voice flow:**
1. Hold mic button → pulsing animation, iOS SFSpeechRecognizer starts
2. User speaks: "Met Marcus Chen at the SCET career fair, he's a PM at Google, interested in ML infrastructure"
3. Release → transcript sent to Gemini Flash for structured extraction
4. Fields auto-fill with extracted data, user reviews and edits
5. Tap Save

**On save:**
- Optimistic UI: dismiss sheet, contact appears in list immediately
- Background: Supabase insert → Gemini embedding → patch contact with embedding

---

### 6. Message Draft Screen

**Purpose:** Edit the AI draft and send it.

**Presentation:** Full-screen `.sheet` from nudge card or contact detail

```
┌────────────────────────────────────────┐
│ ✕  Done         Message Draft          │
├────────────────────────────────────────┤
│                                        │
│  ┌──────────────────────────────────┐  │
│  │  Marcus Chen — PM at Google      │  │
│  │  Met at SCET fair · 9 days ago   │  │
│  └──────────────────────────────────┘  │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │                                  │  │
│  │  Hey Marcus! It was really great │  │
│  │  meeting you at the SCET career  │  │
│  │  fair. I'd love to stay in touch │  │
│  │  — would you be open to a quick  │  │
│  │  coffee chat sometime?           │  │
│  │                                  │  │
│  │                                  │  │
│  └──────────────────────────────────┘  │
│                                        │
│         ↺  Try a different tone        │
│                                        │
├────────────────────────────────────────┤
│  Send via:                             │
│                                        │
│  [📱 iMessage] [✉ Email] [in LinkedIn]│
│                                        │
│  [📋 Copy to clipboard]                │
└────────────────────────────────────────┘
```

**"Try a different tone" flow:**
- Loading indicator (shimmer on text area)
- New draft from Gemini with higher temperature / different framing
- User can keep cycling

**"Send via" buttons:**
- iMessage: `sms:` URL scheme, pre-fills body
- Email: `mailto:` URL scheme with pre-filled body
- LinkedIn: deep-link to LinkedIn messaging (if app installed) or copy + open LinkedIn
- Copy: copies to pasteboard, shows "Copied!" confirmation

---

### 7. Search Tab

**Purpose:** "Who's relevant right now?" — Semantic search + goals.

```
┌────────────────────────────────────────┐
│  Search                                │
├────────────────────────────────────────┤
│  ┌──────────────────────────────────┐  │
│  │ 🔍 who do I know at Google in... │  │
│  └──────────────────────────────────┘  │
│                                        │
│  ──── Your Goals ────────────────────  │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ 🎯 Applying to Stripe            │  │
│  │    ─────────────────────────     │  │
│  │    [SK] Sarah Kim — PM · Stripe  │  │
│  │         Met at Cal Hacks · [→]   │  │
│  │    [RT] Ryan Torres — Eng · Stripe│ │
│  │         Intro via Alex · [→]     │  │
│  └──────────────────────────────────┘  │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ 🎯 VC fundraising research    ✕  │  │
│  │    ─────────────────────────     │  │
│  │    [AR] Alex Rivera — Sequoia    │  │
│  │         Met at YC demo day · [→] │  │
│  └──────────────────────────────────┘  │
│                                        │
│           + Add a goal                 │
│                                        │
└────────────────────────────────────────┘
```

**Search results state (after typing):**

```
┌────────────────────────────────────────┐
│  Search                                │
├────────────────────────────────────────┤
│  ┌──────────────────────────────────┐  │
│  │ 🔍 who do I know at google in PM │  │
│  └──────────────────────────────────┘  │
│                                        │
│  3 results                             │
│  ──────────────────────────────────    │
│                                        │
│  [MC] Marcus Chen               ● →   │
│       PM at Google · SCET fair         │
│                                        │
│  [PS] Priya Singh               ● →   │
│       APM at Google · Cal Hacks        │
│                                        │
│  [JL] Jason Liu                 ● →   │
│       TPM at Google · via Sarah        │
│                                        │
└────────────────────────────────────────┘
```

**Add Goal sheet:**
- Text field: "I'm currently..." (e.g., "Applying to Stripe for product roles")
- [Save Goal] button
- On save: embed goal text, store in goals table, immediately surface contacts

---

### 8. Profile Tab

**Purpose:** Settings, integrations, tone, account.

```
┌────────────────────────────────────────┐
│  Profile                               │
├────────────────────────────────────────┤
│                                        │
│          [  DY  ]                      │
│        Dylan Young                     │
│    dylancc5@berkeley.edu               │
│                                        │
├────────────────────────────────────────┤
│  INTEGRATIONS                          │
│  ──────────────────────────────────    │
│  [in] LinkedIn                         │
│       Import CSV · Share Sheet    →    │
│  [G] Google                            │
│       Connected: Calendar + Gmail  →   │
│                                        │
├────────────────────────────────────────┤
│  PREFERENCES                           │
│  ──────────────────────────────────    │
│  Nudge frequency                  →    │
│  Quiet hours                      →    │
│                                        │
├────────────────────────────────────────┤
│  VOICE                                 │
│  ──────────────────────────────────    │
│  My writing style                 →    │
│  (tone samples for AI drafts)          │
│                                        │
├────────────────────────────────────────┤
│  ACCOUNT                               │
│  ──────────────────────────────────    │
│  Privacy Policy                   →    │
│  Terms of Service                 →    │
│  Sign out                              │
│  Delete account                        │
│                                        │
└────────────────────────────────────────┘
```

---

## User Flows

### Flow 1: Core Loop (First Time)
```
Welcome → Sign in → Tone Setup → Network tab (empty state) →
  Tap "+" → Quick Capture → Save → Contact in list →
  Next day: push notification → Tap → Ping tab → Nudge card →
  [Draft message →] → Message Draft → Edit → Send
```

### Flow 2: Goal-Triggered Search
```
Search tab → "+ Add a goal" → "Applying to Stripe" →
  Goal saved → Contacts surface under goal →
  Tap contact → Contact Detail → [Edit & Send →] → Message Draft → Send
```

### Flow 3: LinkedIn Import
```
Profile → LinkedIn → Import CSV →
  File picker → CSV parsed → Contacts preview (how many, any conflicts) →
  [Import X contacts] → Contacts added, embeddings generated in background
```

### Flow 4: Share Sheet Capture (from LinkedIn app)
```
LinkedIn app → Visit profile → Tap ··· → Share → Ping →
  Share Sheet extension opens →
  Profile data parsed (name, company, title) →
  Quick Capture sheet pre-filled →
  User adds "where you met" + notes →
  [Save]
```

---

## Notification Design

### Push Notification Format
```
Ping                          now
────────────────────────────────
Marcus Chen
"Hey Marcus, it was great meeting..."
                          [Send]
```

- Title: contact name
- Body: first ~80 chars of AI draft
- Action button: "Send" → opens MessageDraftView in-app
- Tap notification body → opens Ping tab, scrolled to this nudge

### Notification Permission
- Request on first nudge creation (not on app launch — users hate that)
- Prompt: "Ping works best with notifications — get nudged at the right moment"

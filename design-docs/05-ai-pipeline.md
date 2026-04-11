# Ping — AI Pipeline

## Overview

Ping uses AI in three distinct ways:

1. **Embeddings** — represent contacts as vectors for semantic search and goal matching
2. **Nudge scoring** — decide which contacts to surface and when
3. **Message drafting** — generate tone-calibrated outreach messages

All AI calls are made directly from the iOS client to Google's Gemini API. API key stored in iOS Keychain.

---

## 1. Embeddings

### Model
**Gemini text-embedding-004**
- Dimension: 768
- Free tier: generous (no per-call cost at low volume)
- Task type: `RETRIEVAL_DOCUMENT` for storage, `RETRIEVAL_QUERY` for search queries

### What Gets Embedded

**Contact embedding** — generated on contact save, stored in `contacts.embedding`:
```
{contact.name}, {contact.title} at {contact.company}.
Met at {contact.how_met}.
Notes: {contact.notes}.
Tags: {contact.tags.joined(", ")}.
```

**Goal embedding** — generated when user saves a goal, stored in `goals.embedding`:
```
{goal.text}
```
(raw, since user wrote it in natural language already)

**Search query embedding** — generated at query time, not stored:
```
{user's raw search query}
```

### Embedding Generation in Swift

```swift
// GeminiService.swift

struct GeminiService {
    static let apiKey = KeychainHelper.get("GEMINI_API_KEY")
    static let embeddingEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent"

    static func embed(_ text: String, taskType: EmbeddingTaskType = .retrievalDocument) async throws -> [Float] {
        let body = EmbedRequest(
            model: "models/text-embedding-004",
            content: Content(parts: [Part(text: text)]),
            taskType: taskType.rawValue
        )
        let response: EmbedResponse = try await APIClient.post(embeddingEndpoint, body: body, apiKey: apiKey)
        return response.embedding.values
    }
}

enum EmbeddingTaskType: String {
    case retrievalDocument = "RETRIEVAL_DOCUMENT"
    case retrievalQuery = "RETRIEVAL_QUERY"
    case semanticSimilarity = "SEMANTIC_SIMILARITY"
}
```

### Vector Search in Supabase

```sql
-- Function: match_contacts
-- Called from iOS via supabase.rpc("match_contacts", ...)
CREATE OR REPLACE FUNCTION match_contacts(
  query_embedding VECTOR(768),
  user_id_filter  UUID,
  match_threshold FLOAT DEFAULT 0.5,
  match_count     INT DEFAULT 10
)
RETURNS TABLE (
  id              UUID,
  name            TEXT,
  company         TEXT,
  title           TEXT,
  how_met         TEXT,
  warmth_score    FLOAT,
  last_contacted_at TIMESTAMPTZ,
  similarity      FLOAT
)
LANGUAGE sql STABLE
AS $$
  SELECT
    id, name, company, title, how_met, warmth_score, last_contacted_at,
    1 - (embedding <=> query_embedding) AS similarity
  FROM contacts
  WHERE user_id = user_id_filter
    AND embedding IS NOT NULL
    AND 1 - (embedding <=> query_embedding) > match_threshold
  ORDER BY embedding <=> query_embedding
  LIMIT match_count;
$$;

-- Function: match_contacts_for_goal
CREATE OR REPLACE FUNCTION match_contacts_for_goal(
  goal_id_param   UUID,
  user_id_filter  UUID,
  match_threshold FLOAT DEFAULT 0.45,
  match_count     INT DEFAULT 5
)
RETURNS TABLE (id UUID, name TEXT, company TEXT, title TEXT, similarity FLOAT)
LANGUAGE sql STABLE
AS $$
  SELECT c.id, c.name, c.company, c.title,
    1 - (c.embedding <=> g.embedding) AS similarity
  FROM contacts c, goals g
  WHERE g.id = goal_id_param
    AND c.user_id = user_id_filter
    AND c.embedding IS NOT NULL
    AND g.embedding IS NOT NULL
    AND 1 - (c.embedding <=> g.embedding) > match_threshold
  ORDER BY c.embedding <=> g.embedding
  LIMIT match_count;
$$;
```

---

## 2. Nudge Scoring Algorithm

### Philosophy

The nudge system must feel intelligent, not robotic. A good nudge surfaces the *right* person at the *right* moment with the *right* reason — not just "you haven't talked to them in N days."

The algorithm scores each contact daily and nudges those above a threshold, respecting user-defined quiet hours and avoiding nudge fatigue.

### Scoring Formula

```swift
// NudgeScorer.swift

struct NudgeScorer {
    struct Factors {
        let daysSinceContact: Int        // Lower = more recently contacted = lower urgency
        let initialMeetingUrgency: Double // 0.0-1.0 extracted by AI from how_met + notes
        let interactionFrequency: Double  // How often they've historically engaged
        let hasOpenNudge: Bool           // Never double-nudge
        let daysSinceMet: Int            // Recently met = high priority
    }

    static func score(_ factors: Factors) -> Double {
        guard !factors.hasOpenNudge else { return 0 }

        // Recency decay: urgency rises as days without contact increase
        let recencyScore = recencyDecay(days: factors.daysSinceContact)

        // New contact bonus: met < 14 days ago → high priority
        let newContactBonus = factors.daysSinceMet < 14 ? 0.3 : 0.0

        // Meeting urgency: was this a "follow up ASAP" meeting?
        let urgencyBonus = factors.initialMeetingUrgency * 0.25

        // Interaction pattern: did they respond last time? Boost.
        let engagementBonus = factors.interactionFrequency * 0.15

        return min(1.0, recencyScore + newContactBonus + urgencyBonus + engagementBonus)
    }

    // Logistic curve: score rises steeply after 7 days, peaks around 21 days
    static func recencyDecay(days: Int) -> Double {
        let x = Double(days)
        return 1.0 / (1.0 + exp(-(x - 10) / 4))
    }
}

// Nudge threshold: score > 0.65 → create nudge
static let NUDGE_THRESHOLD = 0.65
// Max nudges per user per day: 3 (to avoid overwhelming)
static let MAX_DAILY_NUDGES = 3
```

### Meeting Urgency Extraction

When a contact is saved, we ask Gemini to extract an urgency signal from the meeting notes:

```swift
static func extractMeetingUrgency(howMet: String, notes: String) async throws -> Double {
    let prompt = """
    Rate the follow-up urgency for this contact from 0.0 to 1.0.
    
    How met: \(howMet)
    Notes: \(notes)
    
    Consider: Did they mention a specific opportunity, timeline, or ask to stay in touch urgently?
    
    Respond with only a number between 0.0 and 1.0.
    Examples: casual hallway chat = 0.1, "follow up next week about the role" = 0.9
    """
    // Call Gemini Flash, parse Float from response
}
```

### Edge Function CRON Implementation

```typescript
// supabase/functions/score-contacts/index.ts

Deno.serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // Get all users
  const { data: users } = await supabase.from('profiles').select('id')

  for (const user of users) {
    // Get contacts with no pending nudge
    const { data: contacts } = await supabase
      .from('contacts')
      .select('*, interactions(*), nudges(*)')
      .eq('user_id', user.id)
      .order('warmth_score', { ascending: true })

    const toNudge = scoreAndRank(contacts).slice(0, MAX_DAILY_NUDGES)

    for (const contact of toNudge) {
      // Create nudge record
      await supabase.from('nudges').insert({
        contact_id: contact.id,
        user_id: user.id,
        scheduled_at: new Date().toISOString(),
        reason: generateReason(contact)
      })

      // Update warmth score
      await supabase.from('contacts')
        .update({ warmth_score: decayWarmth(contact.warmth_score) })
        .eq('id', contact.id)
    }
  }

  return new Response('ok')
})

// Scheduled via pg_cron or Supabase CRON: '0 17 * * *' (9am PST / noon EST)
```

---

## 3. Message Drafting

### Model
**Gemini 2.0 Flash**
- Free tier: 15 RPM, 1M TPM, 1500 RPD
- Context: 1M tokens (way more than needed)
- Latency: ~1-2 seconds
- Strength: fast, cheap, good instruction following

### System Prompt

The system prompt is the most important prompt in the app. It must produce messages that feel human, not AI-generated.

```
You are a personal writing assistant for someone who wants to maintain genuine human relationships.

Your job is to draft a short, warm, authentic message they can send to reconnect with a contact.

STRICT RULES:
- 2-4 sentences maximum. Never more.
- Sound like the user wrote it, not a robot.
- No generic openers like "Hope you're doing well!" or "I wanted to reach out"
- Reference something specific about how they met or what they discussed
- Make the ask (if any) feel natural and low-pressure
- Never sound transactional or like you're using someone for something
- The message should feel like it "just happened to happen"

USER VOICE (match this style):
{tone_samples}

CONTACT CONTEXT:
Name: {name}
Company: {company}
Title: {title}
How you met: {how_met}
Notes from when you met: {notes}
Days since you last had contact: {days_since_contact}

REASON FOR REACHING OUT:
{nudge_reason}

Write a message they can send as-is or lightly edit. Don't include a subject line.
Just the message body. Start directly — no "Here's a draft:" preamble.
```

### Tone Calibration

If the user has provided tone samples, they're injected verbatim into the system prompt. This is the most powerful personalization lever.

Default tone (if no samples provided): conversational, warm, slightly casual — appropriate for a 20-something reaching out to a professional peer.

### Draft Generation in Swift

```swift
// GeminiService.swift

static func generateDraft(
    contact: Contact,
    nudgeReason: String,
    toneSamples: [String]
) async throws -> String {
    let toneText = toneSamples.isEmpty
        ? "Conversational, warm, not overly formal. Short sentences. Human."
        : toneSamples.joined(separator: "\n")

    let systemPrompt = buildDraftSystemPrompt(
        toneSamples: toneText,
        contact: contact,
        nudgeReason: nudgeReason
    )

    let body = GenerateRequest(
        systemInstruction: Content(parts: [Part(text: systemPrompt)]),
        contents: [Content(parts: [Part(text: "Draft the message.")])],
        generationConfig: GenerationConfig(
            temperature: 0.7,
            maxOutputTokens: 200
        )
    )

    let response: GenerateResponse = try await APIClient.post(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent",
        body: body,
        apiKey: apiKey
    )

    return response.candidates.first?.content.parts.first?.text ?? ""
}
```

### "Try a Different Tone" Flow

When the user taps "Regenerate draft":
- Same prompt, temperature bumped from 0.7 → 0.9
- Previous draft preserved below as fallback
- If user taps again: cycle through 3 pre-seeded variations, then reset

### Draft Caching

- First draft generated when user opens nudge card or contact detail
- Cached in-memory (not persisted) during the session
- On `nudges.acted_at` set → clear cache

---

## 4. Voice Capture → Structured Data

### Transcription
Use iOS `SFSpeechRecognizer` (on-device, no network, privacy-preserving).

```swift
// SpeechService.swift

class SpeechService: ObservableObject {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionTask: SFSpeechRecognitionTask?

    func startRecording() async throws -> AsyncStream<String> { ... }
    func stopRecording() { ... }
}
```

### Extraction
Once the user releases the mic, send the transcript to Gemini Flash for structured extraction:

```swift
static func extractContactFromTranscript(_ transcript: String) async throws -> ContactDraft {
    let prompt = """
    Extract contact information from this voice note about someone the user just met.
    
    Voice note: "\(transcript)"
    
    Return JSON with these fields (use null if not mentioned):
    {
      "name": "string",
      "company": "string or null",
      "title": "string or null",
      "how_met": "string",
      "notes": "string or null"
    }
    
    Be concise. Capture the essence, not a transcript.
    For "how_met": describe the context in 3-6 words ("SCET career fair", "Berkeley CS class")
    """

    // Call Gemini Flash, parse JSON response
    // Return ContactDraft struct
}
```

**ContactDraft struct:**
```swift
struct ContactDraft {
    var name: String = ""
    var company: String? = nil
    var title: String? = nil
    var howMet: String = ""
    var notes: String? = nil
}
```

---

## 5. Rate Limits & Error Handling

### Gemini Free Tier Limits
- Embeddings: No hard limit at low volume
- Gemini Flash: 15 RPM, 1500 RPD

### Handling Limits Gracefully
- Embedding failures: retry once, then save contact without embedding (show ⚠️ "Search may not include this contact")
- Draft failures: show "Couldn't generate a draft — try again" with retry button, never block the user from viewing the contact
- Rate limit (429): exponential backoff with jitter, max 3 retries

### Offline Behavior
- Contact capture always works offline — save locally, sync when back online (Core Data or SwiftData local cache)
- AI features degrade gracefully: "Connect to the internet to generate a draft"

---

## 6. Privacy Considerations

- Contact data (name, notes, how_met) is sent to Gemini API for embedding and drafting
- Gemini API does not use free-tier prompts for model training (per Google's policy as of 2024 — verify for production)
- For production release: evaluate Gemini's data retention policy and disclose in privacy policy
- Tone samples are personal — stored encrypted in Supabase, never logged
- No contact embeddings are sent to third parties — they stay in Supabase

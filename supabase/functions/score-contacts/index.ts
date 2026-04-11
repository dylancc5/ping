// supabase/functions/score-contacts/index.ts
//
// Daily CRON edge function: scores all contacts per user and creates
// pending nudge records for those above NUDGE_THRESHOLD.
//
// Schedule (configure via Supabase dashboard → Database → pg_cron):
//   '0 17 * * *'  →  5pm UTC = 9am PST / 12pm EST
//
// Required env vars (Supabase dashboard → Edge Functions → Secrets):
//   SUPABASE_URL              — your project URL
//   SUPABASE_SERVICE_ROLE_KEY — bypasses RLS; NEVER expose to iOS clients
//
// To deploy:
//   supabase functions deploy score-contacts
//
// To invoke manually for testing:
//   supabase functions invoke score-contacts

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ──────────────────────────────────────────────────────────────────────
// CONSTANTS
// Keep in sync with NudgeScorer.swift on iOS.
// ──────────────────────────────────────────────────────────────────────

const NUDGE_THRESHOLD     = 0.65  // Contacts scoring above this get a nudge
const MAX_DAILY_NUDGES    = 3     // Hard cap per user per day (anti-fatigue)
const WARMTH_DECAY_FACTOR = 0.9   // Applied to warmth_score each time a nudge is created

// ──────────────────────────────────────────────────────────────────────
// TYPE DEFINITIONS
// Mirror the Supabase schema — keep in sync with migrations/001.
// ──────────────────────────────────────────────────────────────────────

interface Interaction {
  id: string
  contact_id: string
  type: string
  occurred_at: string
}

interface Nudge {
  id: string
  contact_id: string
  status: 'pending' | 'delivered' | 'opened' | 'acted' | 'snoozed' | 'dismissed'
  snoozed_until: string | null
}

interface Contact {
  id: string
  user_id: string
  name: string
  company: string | null
  title: string | null
  how_met: string
  notes: string | null
  warmth_score: number
  last_contacted_at: string | null
  met_at: string
  created_at: string
  interactions: Interaction[]
  nudges: Nudge[]
}

interface ScoredContact {
  contact: Contact
  score: number
  daysSinceContact: number
  daysSinceMet: number
}

// ──────────────────────────────────────────────────────────────────────
// SCORING FUNCTIONS
// TypeScript port of NudgeScorer.swift — must stay in sync with iOS.
// ──────────────────────────────────────────────────────────────────────

/**
 * Logistic recency curve. Score rises steeply after ~7 days without
 * contact, peaks asymptotically around 21+ days.
 *
 * Sample values:
 *   0 days  → ~0.08  (just contacted — nudge unlikely)
 *   7 days  → ~0.37
 *  10 days  → ~0.50  (inflection point)
 *  14 days  → ~0.73
 *  21 days  → ~0.88
 *  30 days  → ~0.97
 */
function recencyScore(daysSinceContact: number): number {
  return 1.0 / (1.0 + Math.exp(-(daysSinceContact - 10) / 4))
}

/**
 * Normalize interaction frequency to [0, 1].
 * Counts interactions in the past 90 days; caps at 3 for full score.
 *
 * 0 interactions  → 0.00
 * 1 interaction   → 0.33
 * 2 interactions  → 0.67
 * 3+ interactions → 1.00
 */
function interactionFrequency(interactions: Interaction[]): number {
  const cutoff = new Date()
  cutoff.setDate(cutoff.getDate() - 90)

  const recentCount = interactions.filter(
    (i) => new Date(i.occurred_at) >= cutoff
  ).length

  return Math.min(recentCount / 3, 1.0)
}

/**
 * True if this contact has an "open" nudge that should block creating another.
 *
 * Open states:
 *   pending   — nudge created but push not yet sent
 *   delivered — push sent but user hasn't acted
 *   opened    — user tapped notification but hasn't responded
 *   snoozed   — user deferred AND snooze window hasn't expired yet
 *
 * Non-blocking states (new nudge is appropriate):
 *   acted      — user sent a message; healthy to nudge again later
 *   dismissed  — user declined; reasonable to re-surface eventually
 */
function hasOpenNudge(nudges: Nudge[]): boolean {
  const now = new Date()
  return nudges.some((n) => {
    if (n.status === 'pending' || n.status === 'delivered' || n.status === 'opened') {
      return true
    }
    if (n.status === 'snoozed' && n.snoozed_until) {
      return new Date(n.snoozed_until) > now
    }
    return false
  })
}

/**
 * Score a single contact. Returns 0 immediately if hasOpenNudge is true
 * (the most critical guard — never create a duplicate nudge).
 *
 * Score components:
 *   recencyScore      — rises as days without contact increases (0–1)
 *   newContactBonus   — +0.30 if met < 14 days ago (follow up while fresh)
 *   urgencyBonus      — 0.0 currently (see NOTE below)
 *   engagementBonus   — up to +0.15 based on interaction history
 *
 * NOTE on urgencyBonus: The Swift NudgeScorer includes initialMeetingUrgency
 * (extracted by Gemini at contact-save time), but this value is not persisted
 * to the database schema. To enable this bonus server-side, add a column:
 *   meeting_urgency FLOAT DEFAULT 0.0
 * to the contacts table and have iOS write it on contact save.
 */
function scoreContact(contact: Contact): number {
  if (hasOpenNudge(contact.nudges)) return 0

  const now = new Date()

  // Use last_contacted_at if set; otherwise use created_at (never contacted)
  const lastContactDate = contact.last_contacted_at
    ? new Date(contact.last_contacted_at)
    : new Date(contact.created_at)

  const daysSinceContact = Math.floor(
    (now.getTime() - lastContactDate.getTime()) / (1000 * 60 * 60 * 24)
  )

  const daysSinceMet = Math.floor(
    (now.getTime() - new Date(contact.met_at).getTime()) / (1000 * 60 * 60 * 24)
  )

  const rScore       = recencyScore(daysSinceContact)
  const newBonus     = daysSinceMet < 14 ? 0.3 : 0.0
  const urgencyBonus = 0.0  // See NOTE above — add meeting_urgency column to enable
  const engBonus     = interactionFrequency(contact.interactions) * 0.15

  return Math.min(1.0, rScore + newBonus + urgencyBonus + engBonus)
}

/**
 * Score all contacts, filter by threshold, return sorted by score descending.
 */
function scoreAndRank(contacts: Contact[]): ScoredContact[] {
  const now = new Date()
  const scored: ScoredContact[] = []

  for (const contact of contacts) {
    const score = scoreContact(contact)
    if (score < NUDGE_THRESHOLD) continue

    const lastContactDate = contact.last_contacted_at
      ? new Date(contact.last_contacted_at)
      : new Date(contact.created_at)

    scored.push({
      contact,
      score,
      daysSinceContact: Math.floor(
        (now.getTime() - lastContactDate.getTime()) / (1000 * 60 * 60 * 24)
      ),
      daysSinceMet: Math.floor(
        (now.getTime() - new Date(contact.met_at).getTime()) / (1000 * 60 * 60 * 24)
      ),
    })
  }

  return scored.sort((a, b) => b.score - a.score)
}

// ──────────────────────────────────────────────────────────────────────
// WARMTH DECAY
//
// Applied to contacts.warmth_score each time a nudge is created for them.
// Models that a nudge being generated means the relationship has cooled.
// Recovery happens on iOS when the user logs an interaction —
// SupabaseService should:
//   UPDATE contacts SET warmth_score = 1.0, last_contacted_at = NOW()
//   WHERE id = ?
//
// Decay progression (WARMTH_DECAY_FACTOR = 0.9):
//   After  5 nudge cycles without interaction: ~0.59
//   After 10 nudge cycles:                     ~0.35
//   After 20 nudge cycles:                     ~0.12  (effectively cold)
// ──────────────────────────────────────────────────────────────────────

function decayWarmth(currentScore: number): number {
  return Math.max(0.0, currentScore * WARMTH_DECAY_FACTOR)
}

// ──────────────────────────────────────────────────────────────────────
// REASON GENERATION
//
// Human-readable nudge reason shown in the Ping tab card and push
// notification preview. Kept under ~70 chars for APNs display.
// ──────────────────────────────────────────────────────────────────────

function generateReason(sc: ScoredContact): string {
  const { contact, daysSinceContact, daysSinceMet } = sc

  // Recently met and never followed up — the highest-priority scenario
  if (daysSinceMet < 14 && !contact.last_contacted_at) {
    return `You met ${contact.name} recently — follow up while it's fresh`
  }

  // Added to Ping a while ago but never sent a message
  if (!contact.last_contacted_at) {
    return `You haven't reached out since meeting ${contact.name}`
  }

  // More than a month of silence
  if (daysSinceContact >= 30) {
    return `It's been over a month since you connected with ${contact.name}`
  }

  // Two weeks to a month — the most common nudge scenario
  if (daysSinceContact >= 14) {
    return `You haven't reached out to ${contact.name} in ${daysSinceContact} days`
  }

  // Fallback (shouldn't normally reach here given NUDGE_THRESHOLD logic)
  return `Time to reconnect with ${contact.name}`
}

// ──────────────────────────────────────────────────────────────────────
// MAIN HANDLER
// ──────────────────────────────────────────────────────────────────────

Deno.serve(async (_req: Request) => {
  // Service role client — bypasses RLS to process all users.
  // This key must NEVER be exposed to iOS clients.
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const { data: users, error: usersError } = await supabase
    .from('profiles')
    .select('id')

  if (usersError) {
    console.error('Failed to fetch users:', usersError)
    return new Response(JSON.stringify({ error: 'Failed to fetch users' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  if (!users || users.length === 0) {
    return new Response(JSON.stringify({ processed: 0, nudgesCreated: 0 }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  let totalNudgesCreated = 0
  const errors: string[] = []

  for (const user of users) {
    try {
      // Fetch all contacts with their full interaction and nudge history.
      // We need ALL nudges (not just pending) because hasOpenNudge also
      // checks snoozed nudges whose window may not have expired.
      const { data: contacts, error: contactsError } = await supabase
        .from('contacts')
        .select(`
          *,
          interactions (*),
          nudges (*)
        `)
        .eq('user_id', user.id)

      if (contactsError || !contacts) {
        console.error(`Failed to fetch contacts for user ${user.id}:`, contactsError)
        errors.push(`user ${user.id}: contacts fetch failed`)
        continue
      }

      // Fetch the user's APNs device token once per user loop.
      // Null means the user hasn't granted push permission yet — skip push silently.
      const { data: profile } = await supabase
        .from('profiles')
        .select('device_token')
        .eq('id', user.id)
        .single()

      const deviceToken: string | null = profile?.device_token ?? null

      // Score all contacts, filter by threshold, cap at MAX_DAILY_NUDGES
      const toNudge = scoreAndRank(contacts as Contact[]).slice(0, MAX_DAILY_NUDGES)

      for (const sc of toNudge) {
        const { contact } = sc
        const reason = generateReason(sc)

        // Create the nudge record. draft_message is intentionally omitted —
        // iOS generates it on-demand via Gemini when the user opens the card.
        const { data: nudgeRow, error: nudgeError } = await supabase
          .from('nudges')
          .insert({
            contact_id:   contact.id,
            user_id:      user.id,
            status:       'pending',
            reason,
            scheduled_at: new Date().toISOString(),
          })
          .select('id')
          .single()

        if (nudgeError || !nudgeRow) {
          console.error(`Failed to insert nudge for contact ${contact.id}:`, nudgeError)
          errors.push(`contact ${contact.id}: nudge insert failed`)
          continue
        }

        // Decay warmth to reflect that this relationship needs attention.
        // Non-fatal if this update fails — the nudge was already created.
        const { error: warmthError } = await supabase
          .from('contacts')
          .update({ warmth_score: decayWarmth(contact.warmth_score) })
          .eq('id', contact.id)

        if (warmthError) {
          console.error(`Failed to decay warmth for contact ${contact.id}:`, warmthError)
        }

        totalNudgesCreated++

        // Send push notification if the user has registered a device token.
        // send-push is a stub until APNs certificates are configured — it logs
        // the payload and returns 200, so this call is safe in development.
        if (deviceToken) {
          const { error: pushError } = await supabase.functions.invoke('send-push', {
            body: {
              device_token: deviceToken,
              title:        contact.name,
              body:         reason.slice(0, 80),
              data: {
                nudge_id:   nudgeRow.id,
                contact_id: contact.id,
              },
            },
          })
          if (pushError) {
            console.error(`Failed to send push for nudge ${nudgeRow.id}:`, pushError)
          }
        }
      }
    } catch (err) {
      console.error(`Unexpected error processing user ${user.id}:`, err)
      errors.push(`user ${user.id}: unexpected error`)
    }
  }

  const result = {
    processed:     users.length,
    nudgesCreated: totalNudgesCreated,
    ...(errors.length > 0 && { errors }),
  }

  console.log('score-contacts completed:', result)

  return new Response(JSON.stringify(result), {
    headers: { 'Content-Type': 'application/json' },
  })
})

// ──────────────────────────────────────────────────────────────────────
// CRON REGISTRATION
// Run this once in the Supabase SQL editor after deploying the function.
// Requires pg_cron and pg_net extensions (both enabled by default on
// Supabase projects).
//
// SELECT cron.schedule(
//   'score-contacts-daily',
//   '0 17 * * *',
//   $$
//     SELECT net.http_post(
//       url     := current_setting('app.supabase_url') || '/functions/v1/score-contacts',
//       headers := jsonb_build_object(
//         'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
//         'Content-Type', 'application/json'
//       ),
//       body    := '{}'::jsonb
//     );
//   $$
// );
//
// Set the app settings first (run once per project):
//   ALTER DATABASE postgres
//     SET app.supabase_url = 'https://YOUR_PROJECT_REF.supabase.co';
//   ALTER DATABASE postgres
//     SET app.service_role_key = 'YOUR_SERVICE_ROLE_KEY';
// ──────────────────────────────────────────────────────────────────────

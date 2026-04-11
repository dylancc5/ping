// supabase/functions/send-push/index.ts
//
// Sends an APNs push notification to a single device.
//
// Required env vars (Supabase dashboard → Edge Functions → Secrets):
//   APNS_KEY_ID         — Key ID from Apple Developer portal (e.g. 75T2UP4P8H)
//   APNS_TEAM_ID        — Your Apple Developer Team ID (e.g. B5ZA7KN3V5)
//   APNS_BUNDLE_ID      — App bundle ID (com.v1.ping)
//   APNS_PRIVATE_KEY    — Contents of AuthKey_*.p8 (the raw PEM string, newlines as \n)
//
// To deploy:
//   supabase functions deploy send-push
//
// Expected request body:
//   {
//     "device_token": "<hex APNs token>",
//     "title":        "John Smith",
//     "body":         "You met John recently — follow up while it's fresh",
//     "data":         { "nudge_id": "...", "contact_id": "..." }
//   }

const APNS_HOST = 'https://api.push.apple.com'

// ──────────────────────────────────────────────────────────────────────
// JWT HELPERS
// APNs uses JWT signed with ES256 (P-256 ECDSA).
// ──────────────────────────────────────────────────────────────────────

function base64urlEncode(data: ArrayBuffer): string {
  const bytes = new Uint8Array(data)
  let str = ''
  for (const b of bytes) str += String.fromCharCode(b)
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

async function makeJWT(keyId: string, teamId: string, pemKey: string): Promise<string> {
  const header = base64urlEncode(
    new TextEncoder().encode(JSON.stringify({ alg: 'ES256', kid: keyId }))
  )
  const payload = base64urlEncode(
    new TextEncoder().encode(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) }))
  )

  // Strip PEM headers and decode the base64 body
  const pemBody = pemKey
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '')
  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0))

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyData,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  )

  const signingInput = `${header}.${payload}`
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    cryptoKey,
    new TextEncoder().encode(signingInput)
  )

  return `${signingInput}.${base64urlEncode(signature)}`
}

// ──────────────────────────────────────────────────────────────────────
// MAIN HANDLER
// ──────────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 })
  }

  const keyId     = Deno.env.get('APNS_KEY_ID')
  const teamId    = Deno.env.get('APNS_TEAM_ID')
  const bundleId  = Deno.env.get('APNS_BUNDLE_ID')
  const pemKey    = Deno.env.get('APNS_PRIVATE_KEY')

  if (!keyId || !teamId || !bundleId || !pemKey) {
    console.error('send-push: missing required env vars (APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_PRIVATE_KEY)')
    return new Response(JSON.stringify({ error: 'APNs not configured' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  let body: { device_token: string; title: string; body: string; data?: Record<string, string> }
  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const { device_token, title, body: alertBody, data } = body
  if (!device_token || !title || !alertBody) {
    return new Response(JSON.stringify({ error: 'Missing device_token, title, or body' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  let jwt: string
  try {
    jwt = await makeJWT(keyId, teamId, pemKey)
  } catch (err) {
    console.error('send-push: JWT signing failed:', err)
    return new Response(JSON.stringify({ error: 'JWT signing failed' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const apnsPayload = {
    aps: {
      alert: { title, body: alertBody },
      sound: 'default',
      badge: 1,
    },
    ...(data ?? {}),
  }

  const url = `${APNS_HOST}/3/device/${device_token}`
  const apnsResponse = await fetch(url, {
    method: 'POST',
    headers: {
      'authorization':  `bearer ${jwt}`,
      'apns-topic':     bundleId,
      'apns-push-type': 'alert',
      'apns-priority':  '10',
      'content-type':   'application/json',
    },
    body: JSON.stringify(apnsPayload),
  })

  if (!apnsResponse.ok) {
    const reason = await apnsResponse.text()
    console.error(`send-push: APNs rejected (${apnsResponse.status}):`, reason)
    return new Response(JSON.stringify({ error: 'APNs rejected', reason, status: apnsResponse.status }), {
      status: 502,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  console.log(`send-push: delivered to ${device_token.slice(0, 8)}...`)
  return new Response(JSON.stringify({ ok: true }), {
    headers: { 'Content-Type': 'application/json' },
  })
})

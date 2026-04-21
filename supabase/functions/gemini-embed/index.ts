// supabase/functions/gemini-embed/index.ts
//
// Proxies embedding requests from the iOS app to the Gemini Embedding API.
// Accepts { text, taskType?, model? }
// Returns { values: number[] }  (768-dimensional float array)
//
// Required secrets (Supabase dashboard → Edge Functions → Secrets):
//   GEMINI_API_KEY — Google AI Studio API key
//
// To deploy:
//   supabase functions deploy gemini-embed
//   supabase secrets set GEMINI_API_KEY=AIza...

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')!
const DEFAULT_MODEL = 'gemini-embedding-2-preview'
const GEMINI_BASE = 'https://generativelanguage.googleapis.com/v1beta/models'

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
      },
    })
  }

  let body: { text: string; taskType?: string; model?: string }

  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const { text, taskType = 'RETRIEVAL_DOCUMENT', model } = body
  const useModel = model ?? DEFAULT_MODEL

  if (!text) {
    return new Response(JSON.stringify({ error: 'Missing required field: text' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const url = `${GEMINI_BASE}/${useModel}:embedContent?key=${GEMINI_API_KEY}`

  const geminiRes = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: `models/${useModel}`,
      content: { parts: [{ text }] },
      taskType,
      outputDimensionality: 768,
    }),
  })

  if (!geminiRes.ok) {
    const err = await geminiRes.text()
    console.error('Gemini embed error:', geminiRes.status, err)
    return new Response(JSON.stringify({ error: err }), {
      status: geminiRes.status,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const data = await geminiRes.json()
  const values: number[] = data?.embedding?.values ?? []

  return new Response(JSON.stringify({ values }), {
    headers: { 'Content-Type': 'application/json' },
  })
})

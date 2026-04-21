// supabase/functions/hf-generate/index.ts
//
// Proxies text-generation requests from the iOS app to the HF Inference API.
// Accepts { prompt, systemPrompt?, temperature?, maxTokens?, model? }
// Returns { text }
//
// Required secrets (Supabase dashboard → Edge Functions → Secrets):
//   HF_TOKEN — Hugging Face API token with Inference API access
//
// To deploy:
//   supabase functions deploy hf-generate
//   supabase secrets set HF_TOKEN=hf_...

const HF_TOKEN = Deno.env.get('HF_TOKEN')!
const DEFAULT_MODEL = 'meta-llama/Llama-3.1-8B-Instruct'
const HF_BASE = 'https://router.huggingface.co'

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
      },
    })
  }

  let body: {
    prompt: string
    systemPrompt?: string
    temperature?: number
    maxTokens?: number
    model?: string
  }

  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const { prompt, systemPrompt, temperature = 0.7, maxTokens = 200, model } = body
  const useModel = model ?? DEFAULT_MODEL

  if (!prompt) {
    return new Response(JSON.stringify({ error: 'Missing required field: prompt' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const messages: { role: string; content: string }[] = []
  if (systemPrompt) messages.push({ role: 'system', content: systemPrompt })
  messages.push({ role: 'user', content: prompt })

  const hfRes = await fetch(`${HF_BASE}/v1/chat/completions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${HF_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: useModel,
      messages,
      temperature,
      max_tokens: maxTokens,
      stream: false,
    }),
  })

  if (!hfRes.ok) {
    const err = await hfRes.text()
    console.error('HF API error:', hfRes.status, err)
    return new Response(JSON.stringify({ error: err }), {
      status: hfRes.status,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const data = await hfRes.json()
  const text: string = data.choices?.[0]?.message?.content ?? ''

  return new Response(JSON.stringify({ text }), {
    headers: { 'Content-Type': 'application/json' },
  })
})

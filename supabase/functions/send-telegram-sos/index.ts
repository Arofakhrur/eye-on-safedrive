import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const TELEGRAM_BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!

const TELEGRAM_API = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}`

interface SOSPayload {
  chatIds: string[]
  message: string
  lat: number
  lng: number
  videoUrl?: string
}

serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method Not Allowed' }), { status: 405 })
  }

  try {
    // 1. Verify JWT — only authenticated users can trigger SOS
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), { status: 401 })
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    })

    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
    }

    // 2. Parse payload
    const payload: SOSPayload = await req.json()
    const { chatIds, message, lat, lng, videoUrl } = payload

    if (!chatIds || chatIds.length === 0) {
      return new Response(JSON.stringify({ error: 'No chat IDs provided' }), { status: 400 })
    }

    // 3. Send to each Telegram chat
    let successCount = 0
    const errors: string[] = []

    for (const chatId of chatIds) {
      try {
        // Send text message
        if (message) {
          const textRes = await fetch(`${TELEGRAM_API}/sendMessage`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              chat_id: chatId,
              text: message,
              parse_mode: 'HTML',
            }),
          })
          if (!textRes.ok) {
            const errBody = await textRes.text()
            console.error(`sendMessage failed for ${chatId}: ${errBody}`)
          }
        }

        // Send location
        if (lat && lng) {
          const locRes = await fetch(`${TELEGRAM_API}/sendLocation`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              chat_id: chatId,
              latitude: lat,
              longitude: lng,
            }),
          })
          if (!locRes.ok) {
            const errBody = await locRes.text()
            console.error(`sendLocation failed for ${chatId}: ${errBody}`)
          }
        }

        // Send video if URL provided (from Supabase Storage)
        if (videoUrl) {
          const vidRes = await fetch(`${TELEGRAM_API}/sendVideo`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              chat_id: chatId,
              video: videoUrl,
              caption: '🎥 Bukti rekaman insiden dari EYE-ON!',
            }),
          })
          if (!vidRes.ok) {
            const errBody = await vidRes.text()
            console.error(`sendVideo failed for ${chatId}: ${errBody}`)
          }
        }

        successCount++
      } catch (e) {
        errors.push(`Failed for ${chatId}: ${e}`)
      }
    }

    return new Response(
      JSON.stringify({
        success: successCount > 0,
        sent: successCount,
        total: chatIds.length,
        errors,
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  } catch (error) {
    console.error('Edge Function Error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal Server Error' }),
      { status: 500 }
    )
  }
})

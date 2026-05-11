// Follow this setup guide to deploy: https://supabase.com/docs/guides/functions/deploy

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const WHATSAPP_API_URL = "https://graph.facebook.com/v17.0"
const WHATSAPP_PHONE_NUMBER_ID = Deno.env.get('WHATSAPP_PHONE_NUMBER_ID')
const WHATSAPP_ACCESS_TOKEN = Deno.env.get('WHATSAPP_ACCESS_TOKEN')

serve(async (req) => {
  try {
    const { record } = await req.json()
    const { user_id, latitude, longitude } = record

    // 1. Initialize Supabase Client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 2. Fetch the user's primary emergency contact
    const { data: contacts, error: contactError } = await supabaseClient
      .from('emergency_contacts')
      .select('phone, name')
      .eq('user_id', user_id)
      .limit(1)

    if (contactError || !contacts || contacts.length === 0) {
      return new Response(JSON.stringify({ error: 'No contact found' }), { status: 404 })
    }

    const contactPhone = contacts[0].phone.replace(/\D/g, '') // Remove non-digits
    const mapsUrl = `https://www.google.com/maps/search/?api=1&query=${latitude},${longitude}`

    // 3. Send WhatsApp Message via Meta API
    // Note: This uses a Message Template (required by Meta for initiated messages)
    const payload = {
      messaging_product: "whatsapp",
      to: contactPhone,
      type: "template",
      template: {
        name: "sos_alert", // You must create this template in Meta Business Suite
        language: { code: "id" }, // or "en"
        components: [
          {
            type: "body",
            parameters: [
              { type: "text", text: contacts[0].name },
              { type: "text", text: mapsUrl }
            ]
          }
        ]
      }
    }

    const response = await fetch(`${WHATSAPP_API_URL}/${WHATSAPP_PHONE_NUMBER_ID}/messages`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${WHATSAPP_ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    })

    const result = await response.json()

    return new Response(JSON.stringify({ success: true, result }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const TELEGRAM_BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')

serve(async (req) => {
  try {
    // Memastikan request berasal dari POST
    if (req.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 })
    }

    // Parse JSON dari Telegram Webhook
    const update = await req.json()

    // Validasi apakah ada pesan dan pesan berupa teks
    const message = update.message
    if (!message || !message.text) {
      return new Response('OK', { status: 200 }) // Kembalikan 200 agar Telegram tidak retry
    }

    const chatId = message.chat.id
    const text = message.text.trim()

    // Jika user mengirim command /start
    if (text === '/start') {
      const replyText = `Sistem aktif! Chat ID Anda adalah: ${chatId}.\n\nSilakan berikan angka ini kepada pengendara untuk dimasukkan ke aplikasi EYE-ON!.`

      // Kirim balik ke API Telegram
      const telegramApiUrl = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`
      const response = await fetch(telegramApiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          chat_id: chatId,
          text: replyText,
        }),
      })

      if (!response.ok) {
        console.error('Gagal mengirim pesan ke Telegram', await response.text())
      }
    }

    return new Response('OK', { status: 200 })
  } catch (error) {
    console.error('Terjadi kesalahan:', error)
    return new Response('Internal Server Error', { status: 500 })
  }
})
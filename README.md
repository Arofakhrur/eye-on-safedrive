# EYE-ON!

Aplikasi Android untuk membantu keselamatan pengendara motor. Kamera depan ponsel memantau mata pengendara secara real-time — kalau terdeteksi microsleep (mata terpejam terlalu lama), alarm langsung berbunyi. Kalau terjadi kecelakaan, aplikasi otomatis mengirim lokasi dan video kejadian ke kontak darurat lewat Telegram.

Dibuat sebagai bagian dari penelitian skripsi.

## Cara Kerja

**Deteksi microsleep** — Wajah dilacak on-device pakai Google ML Kit Face Mesh. Dari 6 titik kontur per mata, dihitung Eye Aspect Ratio (EAR). Sinyal di-filter pakai exponential low-pass filter supaya stabil. Setiap pengguna dikalibrasi dulu ambang batasnya secara personal. Kalau mata terpejam ≥30 frame berturut-turut (~1.5 detik), alarm berbunyi otomatis.

**Deteksi kecelakaan** — Akselerometer ponsel memantau lonjakan percepatan. Ada speed-gate via GPS untuk menyaring getaran biasa (polisi tidur, jalan rusak) dari benturan sungguhan.

**Kotak hitam** — Kamera terus merekam dalam buffer 5 detik di sisi native Android. Saat benturan terdeteksi, rekaman otomatis dikunci dan disimpan sebagai bukti.

**Respon darurat** — Setelah kecelakaan terdeteksi, ada countdown 10 detik untuk membatalkan (mencegah false alarm). Kalau tidak dibatalkan, pesan SOS dikirim ke bot Telegram berisi titik lokasi Google Maps dan link video kejadian.

**Monitoring perjalanan** — Tampilan split screen (kamera + peta OpenStreetMap), pencatatan riwayat perjalanan, dan skor keselamatan.

## Tech Stack

| Layer | Teknologi |
|---|---|
| Framework | Flutter (Dart) |
| Native Android | Kotlin — CameraX (ImageAnalysis & VideoCapture) |
| ML | Google ML Kit Face Mesh Detection (on-device) |
| Backend & DB | Supabase (PostgreSQL, Auth, Storage, Edge Functions) |
| Peta | Flutter Map + OpenStreetMap, Nominatim API |
| Penyimpanan lokal | SharedPreferences, Sqflite |

## Prasyarat

- Flutter SDK `^3.10.0`
- Android SDK (min SDK 24)
- Akun Supabase yang sudah disetup (PostgreSQL, Auth, Storage)
- Google OAuth client ID (buat di Google Cloud Console)
- Bot Telegram (buat lewat @BotFather)

## Cara Menjalankan

1. Fork repo ini, lalu clone ke lokal:

   ```bash
   git clone https://github.com/<username-kamu>/eye-on-safedrive.git
   cd eye-on-safedrive
   ```

2. Salin `.env.example` jadi `.env`, lalu isi semua kredensialnya:

   ```bash
   cp .env.example .env
   ```

   ```env
   SUPABASE_URL=...
   SUPABASE_ANON_KEY=...
   GOOGLE_WEB_CLIENT_ID=...
   GOOGLE_IOS_CLIENT_ID=...
   TELEGRAM_BOT_TOKEN=...
   ```

3. Taruh file `google-services.json` dari Firebase Console ke `android/app/`.

4. Install dependensi:

   ```bash
   flutter pub get
   ```

5. Jalankan di mode debug (pastikan device/emulator sudah terhubung):

   ```bash
   flutter run
   ```

6. Langkah build APK release:

   ```bash
   flutter build apk --release
   ```

   File APK ada di `build/app/outputs/flutter-apk/app-release.apk`.

## Lisensi

© 2026 — Dibuat untuk keperluan penelitian skripsi.

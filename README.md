# EYE-ON! 🏍️👁️

Sistem keselamatan pengendara sepeda motor secara *real-time* berbasis mobile yang mengintegrasikan deteksi *microsleep* (*facial landmark* & EAR) dan respon darurat otomatis (*emergency response*).

Aplikasi ini dikembangkan untuk keperluan penelitian skripsi.

---

## 📌 Fitur Utama

### 1. Deteksi Microsleep (Real-time Computer Vision)
- Pelacakan wajah lokal (*on-device*) menggunakan **Google ML Kit Face Mesh Detection**.
- Ekstraksi 6 titik kontur per mata untuk menghitung rasio **Eye Aspect Ratio (EAR)**.
- Filter sinyal menggunakan **Exponential Low-Pass Filter (LPF)** ($\alpha = 0.4, \beta = 0.6$).
- **Kalibrasi Personal**: Penyesuaian ambang batas adaptif per pengendara dengan eliminasi *outlier* IQR 1.5 dan koefisien pengali `0.74`.
- Alarm audio bertingkat otomatis jika mata terpejam $\ge 30$ frame kontinu ($\approx 1.5$ detik).

### 2. Deteksi Insiden & Kecelakaan (Sensor Inersial)
- Memantau lonjakan percepatan via akselerometer ponsel.
- Verifikasi kecepatan **Speed-Gate** via GPS untuk menyaring getaran jalan/polisi tidur.
- Mendukung *bypass* sudut kemiringan sepeda motor saat jatuh.

### 3. Kotak Hitam Video (*Rolling Buffer*)
- Merekam video kamera depan secara berulang (*buffer* 5 detik) di sisi *native* Android.
- Otomatis mengunci dan menyimpan rekaman MP4 saat benturan terdeteksi sebagai bukti insiden.

### 4. Respon Darurat Cepat (SOS Telegram & GPS)
- Jeda pembatalan darurat (*countdown*) 10 detik untuk menghindari alarm palsu.
- Mengirim pesan darurat otomatis ke bot Telegram kontak darurat berisi titik lokasi GPS Google Maps dan tautan video insiden.

### 5. Monitoring & Metrik Perjalanan
- Tampilan antarmuka *split screen* (kamera depan + peta rute OpenStreetMap).
- Pencatatan log perjalanan, skor keselamatan (*safety score*), serta riwayat insiden.

---

## 🛠️ Tumpukan Teknologi (Tech Stack)

- **Framework**: Flutter (Dart)
- **Native Android**: Kotlin (CameraX `ImageAnalysis` & `VideoCapture`)
- **Model Machine Learning**: Google ML Kit Face Mesh Detection (On-Device)
- **Backend & Database**: Supabase (PostgreSQL, Auth, Storage, Edge Functions)
- **Peta & Geocoding**: Flutter Map, OpenStreetMap (OSM), Nominatim API
- **Penyimpanan Lokal**: SharedPreferences, Sqflite

---

## ⚙️ Panduan Menjalankan Aplikasi

### 1. Prasyarat
- Flutter SDK (versi ^3.10.0 atau lebih baru)
- Android Studio / VS Code dengan Android SDK (Min SDK: 24, Target SDK: 34)
- Akun dan project Supabase aktif
- Bot Telegram (via @BotFather)

### 2. Konfigurasi Lingkungan (.env)
Buat file bernama `.env` di direktori utama (*root*) project:

```env
SUPABASE_URL=isi_dengan_url_supabase_anda
SUPABASE_ANON_KEY=isi_dengan_anon_key_supabase_anda
```

### 3. Inisialisasi Dependensi & Jalankan
Buka terminal di root project, jalankan:

```bash
flutter pub get
flutter run
```

---

## 🧹 Panduan Sebelum Upload ke Google Drive / GitHub

Agar ukuran folder tidak membengkak (bisa mencapai 2-4 GB jika cache build masih ada) dan aman dari kebocoran kredensial:

1. **Bersihkan File Build (Wajib)**:
   ```bash
   flutter clean
   ```
   *Perintah ini akan menghapus folder `build/` dan `.dart_tool/` sehingga ukuran folder turun drastis menjadi hanya ~30-50 MB.*

2. **Hapus File Sensitif**:
   - Pastikan file `.env` tidak diunggah ke repositori publik GitHub (sudah terdaftar di `.gitignore`).
   - File `google-services.json` dan keystore Android tidak boleh dibagikan sembarangan.

3. **Hapus File Sampah / Log**:
   - Hapus file log crash JVM seperti `hs_err_*.log` atau `replay_*.log` di direktori utama.

---

## 📄 Lisensi & Hak Cipta
Hak Cipta © 2026. Dikembangkan khusus untuk penelitian skripsi.

# 👁️ EYE-ON! - Safe Driving Assistant

**EYE-ON!** is a Flutter-based mobile application designed to enhance rider safety through real-time microsleep detection, accident monitoring, and automatic emergency response.

---

## 🚀 Key Features

### 1. Microsleep Detection (Computer Vision)
- Real-time face tracking using **Google ML Kit Face Mesh Detection**.
- Calculates **Eye Aspect Ratio (EAR)** to detect drowsiness.
- Personalized threshold calibration.
- Automatic high-pitched audio alarm if eyes are closed for a prolonged duration.

### 2. Accident Detection (Inertial Sensors)
- Monitors **Gyroscope** and **Accelerometer** data to track extreme changes in motion.
- Detects high-magnitude rotation events indicative of a crash or sudden fall.
- Smart accident verification using GPS speed gating to prevent false positives when the vehicle is stationary.

### 3. Rolling Video Buffer (Blackbox Evidence)
- Maintains a **rolling buffer** of the front camera during the ride.
- Automatically saves and extracts the video buffer into an `.mp4` file upon accident detection using **FFmpeg**.

### 4. Smart SOS Response via Telegram
- **Automatic Telegram Alerts**: Sends SOS messages with live GPS location and crash video evidence to emergency contacts via Supabase Edge Functions & Telegram Bot API.
- Replaces WhatsApp integration for faster, more reliable bot interactions.

### 5. Comprehensive Safety Tracking
- **Safety Score**: Calculates ride safety based on driving behavior and detected incidents.
- **Incident Logs**: Detailed history of all microsleep events, alarms, and accidents, synchronized to the cloud.

---

## 🛠️ Tech Stack
- **Framework**: Flutter (Dart)
- **Backend & Auth**: Supabase (Auth, PostgreSQL, Storage, Edge Functions)
- **CV Engine**: Google ML Kit (Face Mesh)
- **Media Processing**: FFmpeg Kit
- **State Management**: Provider / ChangeNotifier
- **Maps & Geocoding**: OpenStreetMap / Nominatim (flutter_map)
- **Local Storage**: SharedPreferences, Sqflite

---

## 🛠️ Setup Instructions

### 1. Prerequisites
- Flutter SDK (Latest Stable, ^3.10.0)
- Supabase Project
- Telegram Bot Token

### 2. Environment Variables
Create a `.env` file in the root directory and add your credentials:
```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

### 3. Database Setup
Execute the SQL scripts in your Supabase SQL Editor to create the necessary tables (`users`, `emergency_contacts`, `incident_logs`, `activities`) and their respective RLS policies.

### 4. Edge Functions (Telegram SOS)
Deploy the Edge Function for automatic background messaging to Telegram:
```bash
supabase functions deploy send-telegram-sos
```
*Note: Ensure your Telegram Bot Token is configured in Supabase Secrets for this edge function to work.*

---

## ⚠️ Important Notes

> [!IMPORTANT]
> **Privacy & Permissions**: This app requires access to Camera, Location, Contacts, and Physical Activity sensors. Data is processed locally for detection, but incident videos and logs are uploaded to your private Supabase storage.

> [!WARNING]
> **Sensitive Files**: Do **NOT** commit your `.env` file to public repositories. This is excluded by the current `.gitignore`.

> [!NOTE]
> **Device Placement**: For optimal microsleep detection, the smartphone must be mounted on the motorcycle/vehicle with a clear, stable view of the rider's face.

---

## 📜 License
This project is developed for **Skripsi** purposes. All rights reserved.

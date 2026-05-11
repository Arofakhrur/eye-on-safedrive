# 👁️ EYEON! - Safe Driving Assistant

**EYEON!** is a Flutter-based mobile application designed to enhance rider safety through real-time microsleep detection, accident monitoring, and automatic emergency response.

---

## 🚀 Key Features

### 1. Microsleep Detection (Computer Vision)
- Real-time face tracking using **MediaPipe Face Mesh**.
- Calculates **Eye Aspect Ratio (EAR)** to detect drowsiness.
- Automatic high-pitched audio alarm if eyes are closed for more than 2 seconds.

### 2. Accident Detection (Inertial Sensors)
- Monitors **Gyroscope** and **Accelerometer** data.
- Detects high-magnitude rotation events (> 5 rad/s) indicative of a crash.

### 3. Rolling Video Buffer (Blackbox Evidence)
- Maintains a **10-second rolling buffer** of the front camera during the ride.
- Automatically saves and extracts the video buffer into an `.mp4` file upon accident detection using **FFmpeg**.

### 4. Smart SOS Response
- **Automatic WhatsApp Alerts**: Sends SOS messages with live GPS location to emergency contacts via Supabase Edge Functions & WhatsApp Business API.
- **National Emergency Integration**: Quick access to 112 emergency services.

---

## 🛠️ Tech Stack
- **Framework**: Flutter (Dart)
- **Backend**: Supabase (Auth, PostgreSQL, Storage, Edge Functions)
- **CV Engine**: Google ML Kit (Face Mesh)
- **Media Processing**: FFmpeg Kit
- **State Management**: Provider / ChangeNotifier

---

## 🛠️ Setup Instructions

### 1. Prerequisites
- Flutter SDK (Latest Stable)
- Supabase Project

### 2. Environment Variables
Create a `.env` file in the root directory and add your Supabase credentials:
```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

### 3. Database Setup
Execute the SQL script located in `supabase/schema.sql` in your Supabase SQL Editor to create the necessary tables (`emergency_contacts`, `incident_logs`) and RLS policies.

### 4. Edge Functions (WhatsApp SOS)
Deploy the Edge Function for automatic background messaging:
```bash
supabase functions deploy send_sos
```
*Note: Requires Meta WhatsApp Business API credentials configured in Supabase Secrets.*

---

## ⚠️ Important Notes

> [!IMPORTANT]
> **Privacy & Permissions**: This app requires access to Camera, Location, Contacts, and Physical Activity sensors. Data is processed locally for detection, but incident videos and logs are uploaded to your private Supabase storage.

> [!WARNING]
> **Sensitive Files**: Do **NOT** commit your `.env` or `google-services.json` files to public repositories. These are excluded by the current `.gitignore`.

> [!NOTE]
> **Device Placement**: For optimal microsleep detection, the smartphone must be mounted on the motorcycle/vehicle with a clear, stable view of the rider's face.

---

## 📜 License
This project is developed for **Skripsi/Thesis** purposes. All rights reserved.

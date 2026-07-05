-- ============================================================
-- EYEON MASTER SCHEMA — Full Database Setup
-- Versi: 2.0 | Aman dijalankan berulang kali (idempotent)
-- Jalankan SELURUH script ini di Supabase SQL Editor
-- ============================================================
-- Tabel yang dikelola:
--   1. profiles           — Data profil & preferensi rider
--   2. emergency_contacts — Kontak darurat (maks 3 per user)
--   3. ride_logs          — Log setiap sesi berkendara
--   4. incident_logs      — Log insiden kecelakaan per sesi
--   5. evaluation_metrics — Metrik performa SOS (debug/skripsi)
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 1. TABEL: profiles
--    Menyimpan data pribadi, preferensi deteksi, dan kalibrasi
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.profiles (
    -- Primary key = user id dari auth.users (1:1)
    id                      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Informasi pribadi
    full_name               TEXT,
    blood_type              TEXT CHECK (blood_type IN ('A', 'B', 'AB', 'O', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')),
    address                 TEXT,
    origin                  TEXT,
    emergency_medical_notes TEXT,

    -- Kalibrasi EAR (Eye Aspect Ratio)
    ear_threshold           DOUBLE PRECISION
                                CHECK (ear_threshold IS NULL OR (ear_threshold >= 0.05 AND ear_threshold <= 0.5)),

    -- Preferensi deteksi (disinkronisasi dari SharedPreferences)
    shock_sensitivity       DOUBLE PRECISION DEFAULT 30.0
                                CHECK (shock_sensitivity > 0),
    alarm_sound             TEXT DEFAULT 'Sound 1'
                                CHECK (alarm_sound IN ('Sound 1', 'Sound 2', 'Sound 3', 'Sound 4')),
    save_to_gallery         BOOLEAN DEFAULT false,

    -- Timestamps
    created_at              TIMESTAMPTZ DEFAULT now(),
    updated_at              TIMESTAMPTZ DEFAULT now()
);

-- Tambah kolom jika tabel sudah ada tapi kolom belum ada (safe migration)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='ear_threshold') THEN
        ALTER TABLE public.profiles ADD COLUMN ear_threshold DOUBLE PRECISION CHECK (ear_threshold IS NULL OR (ear_threshold >= 0.05 AND ear_threshold <= 0.5));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='shock_sensitivity') THEN
        ALTER TABLE public.profiles ADD COLUMN shock_sensitivity DOUBLE PRECISION DEFAULT 30.0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='alarm_sound') THEN
        ALTER TABLE public.profiles ADD COLUMN alarm_sound TEXT DEFAULT 'Sound 1';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='save_to_gallery') THEN
        ALTER TABLE public.profiles ADD COLUMN save_to_gallery BOOLEAN DEFAULT false;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='created_at') THEN
        ALTER TABLE public.profiles ADD COLUMN created_at TIMESTAMPTZ DEFAULT now();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='blood_type') THEN
        ALTER TABLE public.profiles ADD COLUMN blood_type TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='address') THEN
        ALTER TABLE public.profiles ADD COLUMN address TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='origin') THEN
        ALTER TABLE public.profiles ADD COLUMN origin TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='emergency_medical_notes') THEN
        ALTER TABLE public.profiles ADD COLUMN emergency_medical_notes TEXT;
    END IF;
END $$;

-- RLS: profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles: user can select own" ON public.profiles;
CREATE POLICY "profiles: user can select own"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

DROP POLICY IF EXISTS "profiles: user can insert own" ON public.profiles;
CREATE POLICY "profiles: user can insert own"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles: user can update own" ON public.profiles;
CREATE POLICY "profiles: user can update own"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Service Role (Edge Functions & server-side) bisa baca semua profil
DROP POLICY IF EXISTS "profiles: service role full access" ON public.profiles;
CREATE POLICY "profiles: service role full access"
    ON public.profiles FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);


-- ════════════════════════════════════════════════════════════
-- 2. TABEL: emergency_contacts
--    Kontak darurat per user, maksimal 3 (enforced di app)
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.emergency_contacts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    name            TEXT NOT NULL
                        CHECK (char_length(name) >= 2 AND char_length(name) <= 100),
    phone           TEXT NOT NULL
                        CHECK (phone ~ '^\+62[0-9]{7,13}$'),
    telegram_chat_id TEXT,

    -- Timestamps
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

-- Unique: satu nomor telepon per user
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_emergency_contact_user_phone') THEN
        ALTER TABLE public.emergency_contacts
            ADD CONSTRAINT uq_emergency_contact_user_phone UNIQUE (user_id, phone);
    END IF;
END $$;

-- Index untuk query cepat per user
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user_id
    ON public.emergency_contacts(user_id);

-- RLS: emergency_contacts
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "emergency_contacts: user can select own" ON public.emergency_contacts;
CREATE POLICY "emergency_contacts: user can select own"
    ON public.emergency_contacts FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "emergency_contacts: user can insert own" ON public.emergency_contacts;
CREATE POLICY "emergency_contacts: user can insert own"
    ON public.emergency_contacts FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "emergency_contacts: user can update own" ON public.emergency_contacts;
CREATE POLICY "emergency_contacts: user can update own"
    ON public.emergency_contacts FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "emergency_contacts: user can delete own" ON public.emergency_contacts;
CREATE POLICY "emergency_contacts: user can delete own"
    ON public.emergency_contacts FOR DELETE
    USING (auth.uid() = user_id);

-- Service role untuk Edge Functions (kirim Telegram SOS)
DROP POLICY IF EXISTS "emergency_contacts: service role full access" ON public.emergency_contacts;
CREATE POLICY "emergency_contacts: service role full access"
    ON public.emergency_contacts FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);


-- ════════════════════════════════════════════════════════════
-- 3. TABEL: ride_logs
--    Satu baris = satu sesi berkendara
--    INSERT saat ride mulai, UPDATE saat ride selesai
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.ride_logs (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    start_time          TIMESTAMPTZ NOT NULL,
    end_time            TIMESTAMPTZ NOT NULL,

    microsleep_alerts   INTEGER NOT NULL DEFAULT 0 CHECK (microsleep_alerts >= 0),
    accident_alerts     INTEGER NOT NULL DEFAULT 0 CHECK (accident_alerts >= 0),
    distance            DOUBLE PRECISION NOT NULL DEFAULT 0.0 CHECK (distance >= 0),
    video_url           TEXT,

    -- Timestamps
    created_at          TIMESTAMPTZ DEFAULT now()
);

-- Tambah kolom jika tabel sudah ada (safe migration)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ride_logs' AND column_name='video_url') THEN
        ALTER TABLE public.ride_logs ADD COLUMN video_url TEXT;
    END IF;
END $$;

-- Constraint: end_time harus >= start_time
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_ride_time_order') THEN
        ALTER TABLE public.ride_logs
            ADD CONSTRAINT chk_ride_time_order CHECK (end_time >= start_time);
    END IF;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ride_logs_user_id
    ON public.ride_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_ride_logs_start_time
    ON public.ride_logs(user_id, start_time DESC);

-- RLS: ride_logs
ALTER TABLE public.ride_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ride_logs: user can select own" ON public.ride_logs;
CREATE POLICY "ride_logs: user can select own"
    ON public.ride_logs FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "ride_logs: user can insert own" ON public.ride_logs;
CREATE POLICY "ride_logs: user can insert own"
    ON public.ride_logs FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- UPDATE wajib ada: microsleep/accident count diupdate saat ride selesai
DROP POLICY IF EXISTS "ride_logs: user can update own" ON public.ride_logs;
CREATE POLICY "ride_logs: user can update own"
    ON public.ride_logs FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "ride_logs: user can delete own" ON public.ride_logs;
CREATE POLICY "ride_logs: user can delete own"
    ON public.ride_logs FOR DELETE
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "ride_logs: service role full access" ON public.ride_logs;
CREATE POLICY "ride_logs: service role full access"
    ON public.ride_logs FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);


-- ════════════════════════════════════════════════════════════
-- 4. TABEL: incident_logs
--    Satu baris = satu kejadian insiden/kecelakaan
--    Terhubung ke ride_logs via ride_id (nullable)
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.incident_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Lokasi GPS saat insiden
    latitude    DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude   DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),

    -- Kekuatan benturan dari akselerometer (m/s²)
    magnitude   DOUBLE PRECISION NOT NULL CHECK (magnitude > 0),

    -- Bukti video (URL ke Supabase Storage)
    video_url   TEXT,

    -- Relasi ke sesi berkendara (nullable jika ride gagal dicatat)
    ride_id     UUID REFERENCES public.ride_logs(id) ON DELETE SET NULL,

    -- Timestamps
    timestamp   TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at  TIMESTAMPTZ DEFAULT now()
);

-- Tambah kolom jika tabel sudah ada (safe migration)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='incident_logs' AND column_name='video_url') THEN
        ALTER TABLE public.incident_logs ADD COLUMN video_url TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='incident_logs' AND column_name='ride_id') THEN
        ALTER TABLE public.incident_logs ADD COLUMN ride_id UUID REFERENCES public.ride_logs(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_incident_logs_user_id
    ON public.incident_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_incident_logs_ride_id
    ON public.incident_logs(ride_id);
CREATE INDEX IF NOT EXISTS idx_incident_logs_timestamp
    ON public.incident_logs(user_id, timestamp DESC);

-- RLS: incident_logs
ALTER TABLE public.incident_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "incident_logs: user can select own" ON public.incident_logs;
CREATE POLICY "incident_logs: user can select own"
    ON public.incident_logs FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "incident_logs: user can insert own" ON public.incident_logs;
CREATE POLICY "Users can insert their own ride logs" ON public.ride_logs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own ride logs" ON public.ride_logs
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own ride logs" ON public.ride_logs
    FOR UPDATE USING (auth.uid() = user_id);

-- 4. Incident Logs Policies
CREATE POLICY "Users can insert their own incidents" ON public.incident_logs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own incidents" ON public.incident_logs
    FOR SELECT USING (auth.uid() = user_id);

-- 5. Storage Bucket: incident_videos
-- Pastikan bucket dibuat agar video bisa diupload dan diakses Telegram
INSERT INTO storage.buckets (id, name, public) 
VALUES ('incident_videos', 'incident_videos', true)
ON CONFLICT (id) DO NOTHING;

-- Storage Policies for incident_videos
CREATE POLICY "Users can upload their own incident videos" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'incident_videos' AND 
        (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Users can view their own incident videos" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'incident_videos' AND 
        (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Public can view incident videos if they have URL" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'incident_videos'
    );

DROP POLICY IF EXISTS "incident_logs: service role full access" ON public.incident_logs;
CREATE POLICY "incident_logs: service role full access"
    ON public.incident_logs FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);


-- ════════════════════════════════════════════════════════════
-- 5. TABEL: evaluation_metrics
--    Metrik waktu respons SOS untuk evaluasi skripsi (Bab 4)
--    INSERT-only oleh user terautentikasi, baca oleh service_role
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.evaluation_metrics (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Skenario pengujian
    test_scenario       TEXT NOT NULL,

    -- Komponen waktu respons (dalam milidetik)
    sensor_detection_ms INTEGER NOT NULL DEFAULT 0 CHECK (sensor_detection_ms >= 0),
    video_extraction_ms INTEGER NOT NULL DEFAULT 0 CHECK (video_extraction_ms >= 0),
    gallery_save_ms     INTEGER NOT NULL DEFAULT 0 CHECK (gallery_save_ms >= 0),
    telegram_api_ms     INTEGER NOT NULL DEFAULT 0 CHECK (telegram_api_ms >= 0),
    total_mitigation_ms INTEGER NOT NULL DEFAULT 0 CHECK (total_mitigation_ms >= 0),

    -- Timestamps
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS: evaluation_metrics
ALTER TABLE public.evaluation_metrics ENABLE ROW LEVEL SECURITY;

-- Semua user terautentikasi bisa INSERT (log metrik dari app)
DROP POLICY IF EXISTS "evaluation_metrics: authenticated can insert" ON public.evaluation_metrics;
CREATE POLICY "evaluation_metrics: authenticated can insert"
    ON public.evaluation_metrics FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Service role bisa baca untuk analisis
DROP POLICY IF EXISTS "evaluation_metrics: service role full access" ON public.evaluation_metrics;
CREATE POLICY "evaluation_metrics: service role full access"
    ON public.evaluation_metrics FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);


-- ════════════════════════════════════════════════════════════
-- 6. TRIGGER: Auto-buat profil saat user baru mendaftar
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, created_at, updated_at)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name'),
        now(),
        now()
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ════════════════════════════════════════════════════════════
-- 7. TRIGGER: Auto-update updated_at di profiles
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_emergency_contacts_updated_at ON public.emergency_contacts;
CREATE TRIGGER trg_emergency_contacts_updated_at
    BEFORE UPDATE ON public.emergency_contacts
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ════════════════════════════════════════════════════════════
-- 8. BACKFILL: Buat profil untuk user yang sudah ada
--    (User yang daftar sebelum trigger dibuat)
-- ════════════════════════════════════════════════════════════
INSERT INTO public.profiles (id, full_name, created_at, updated_at)
SELECT
    u.id,
    COALESCE(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name'),
    now(),
    now()
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = u.id
)
ON CONFLICT (id) DO NOTHING;


-- ════════════════════════════════════════════════════════════
-- 9. STORAGE BUCKET: incident_videos
--    (Bucket untuk menyimpan video bukti kecelakaan)
-- ════════════════════════════════════════════════════════════
INSERT INTO storage.buckets (id, name, public) 
VALUES ('incident_videos', 'incident_videos', true)
ON CONFLICT (id) DO NOTHING;

-- Hapus policy lama jika ada
DROP POLICY IF EXISTS "Users can upload their own incident videos" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own incident videos" ON storage.objects;
DROP POLICY IF EXISTS "Public can view incident videos if they have URL" ON storage.objects;

-- RLS untuk Bucket:
-- 1. Insert: Hanya user (auth.uid) yang bisa upload ke foldernya sendiri
CREATE POLICY "Users can upload their own incident videos" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'incident_videos' AND 
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- 2. Select (User): Bisa lihat videonya sendiri
CREATE POLICY "Users can view their own incident videos" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'incident_videos' AND 
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- 3. Select (Public): Karena bucket public, kita beri izin select general
CREATE POLICY "Public can view incident videos if they have URL" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'incident_videos'
    );


-- ════════════════════════════════════════════════════════════
-- VERIFIKASI HASIL — Cek semua policy & tabel
-- ════════════════════════════════════════════════════════════
SELECT
    t.tablename,
    p.policyname,
    p.roles,
    p.cmd,
    p.qual
FROM pg_tables t
LEFT JOIN pg_policies p ON t.tablename = p.tablename
WHERE t.schemaname = 'public'
  AND t.tablename IN ('profiles','emergency_contacts','ride_logs','incident_logs','evaluation_metrics')
ORDER BY t.tablename, p.cmd;


-- EYEON DATABASE SCHEMA
-- Consolidation of all requirements: Emergency Contacts, Incident Logs, Ride Logs, and Profiles.

-- 1. Create Emergency Contacts table
CREATE TABLE IF NOT EXISTS public.emergency_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    telegram_chat_id TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Add telegram_chat_id if table exists without it
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='emergency_contacts' AND column_name='telegram_chat_id') THEN
        ALTER TABLE public.emergency_contacts ADD COLUMN telegram_chat_id TEXT;
    END IF;
END $$;

-- Unique constraint: one phone per user (Task 7)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'unique_user_phone') THEN
        ALTER TABLE public.emergency_contacts ADD CONSTRAINT unique_user_phone UNIQUE (user_id, phone);
    END IF;
END $$;

-- Phone format constraint: E.164 starting with +62 (Task 7)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'phone_e164_format') THEN
        ALTER TABLE public.emergency_contacts ADD CONSTRAINT phone_e164_format CHECK (phone ~ '^\+62[0-9]{8,13}$');
    END IF;
END $$;

-- Enable RLS for emergency_contacts
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;

-- Clean and recreate policies for emergency_contacts
DROP POLICY IF EXISTS "Users can view their own contacts" ON public.emergency_contacts;
CREATE POLICY "Users can view their own contacts" ON public.emergency_contacts FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own contacts" ON public.emergency_contacts;
CREATE POLICY "Users can insert their own contacts" ON public.emergency_contacts FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own contacts" ON public.emergency_contacts;
CREATE POLICY "Users can update their own contacts" ON public.emergency_contacts FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own contacts" ON public.emergency_contacts;
CREATE POLICY "Users can delete their own contacts" ON public.emergency_contacts FOR DELETE USING (auth.uid() = user_id);


-- 2. Create Ride Logs table (Summary of trips) — MUST come before incident_logs for FK
CREATE TABLE IF NOT EXISTS public.ride_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    microsleep_alerts INTEGER DEFAULT 0,
    accident_alerts INTEGER DEFAULT 0,
    distance DOUBLE PRECISION DEFAULT 0.0,
    video_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Ensure video_url exists in ride_logs
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='ride_logs' AND column_name='video_url') THEN
        ALTER TABLE public.ride_logs ADD COLUMN video_url TEXT;
    END IF;
END $$;

-- Enable RLS for ride_logs
ALTER TABLE public.ride_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own ride logs" ON public.ride_logs;
CREATE POLICY "Users can view their own ride logs" ON public.ride_logs FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own ride logs" ON public.ride_logs;
CREATE POLICY "Users can insert their own ride logs" ON public.ride_logs FOR INSERT WITH CHECK (auth.uid() = user_id);


-- 3. Create Incident Logs table (Detailed events with coordinates and video)
CREATE TABLE IF NOT EXISTS public.incident_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    magnitude DOUBLE PRECISION NOT NULL,
    video_url TEXT,
    ride_id UUID REFERENCES public.ride_logs(id) ON DELETE SET NULL,
    timestamp TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Ensure video_url and ride_id columns exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='incident_logs' AND column_name='video_url') THEN
        ALTER TABLE public.incident_logs ADD COLUMN video_url TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='incident_logs' AND column_name='ride_id') THEN
        ALTER TABLE public.incident_logs ADD COLUMN ride_id UUID REFERENCES public.ride_logs(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Index for efficient ride→incident lookups (Task 8)
CREATE INDEX IF NOT EXISTS idx_incident_ride ON public.incident_logs(ride_id);

-- Enable RLS for incident_logs
ALTER TABLE public.incident_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own incidents" ON public.incident_logs;
CREATE POLICY "Users can view their own incidents" ON public.incident_logs FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own incidents" ON public.incident_logs;
CREATE POLICY "Users can insert their own incidents" ON public.incident_logs FOR INSERT WITH CHECK (auth.uid() = user_id);


-- 4. Create Profiles table — Isolated medical info (Task 9)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    blood_type TEXT,
    address TEXT,
    origin TEXT,
    emergency_medical_notes TEXT,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS for profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Auto-create profile on signup (trigger)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- STORAGE BUCKET NOTE:
-- Please ensure you have a PUBLIC bucket named 'incident_videos' in your Supabase Storage.
-- You can create this in the Supabase Dashboard -> Storage -> New Bucket.

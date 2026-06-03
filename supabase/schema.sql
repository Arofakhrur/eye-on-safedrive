-- EYEON DATABASE SCHEMA
-- Consolidation of all requirements: Emergency Contacts, Incident Logs, and Ride Logs.

-- 1. Create Emergency Contacts table
CREATE TABLE IF NOT EXISTS public.emergency_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

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


-- 2. Create Incident Logs table (Detailed events with coordinates and video)
CREATE TABLE IF NOT EXISTS public.incident_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    magnitude DOUBLE PRECISION NOT NULL,
    video_url TEXT,
    timestamp TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Ensure video_url exists if table was created previously without it
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='incident_logs' AND column_name='video_url') THEN
        ALTER TABLE public.incident_logs ADD COLUMN video_url TEXT;
    END IF;
END $$;

-- Enable RLS for incident_logs
ALTER TABLE public.incident_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own incidents" ON public.incident_logs;
CREATE POLICY "Users can view their own incidents" ON public.incident_logs FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own incidents" ON public.incident_logs;
CREATE POLICY "Users can insert their own incidents" ON public.incident_logs FOR INSERT WITH CHECK (auth.uid() = user_id);


-- 3. Create Ride Logs table (Summary of trips)
CREATE TABLE IF NOT EXISTS public.ride_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    microsleep_alerts INTEGER DEFAULT 0,
    accident_alerts INTEGER DEFAULT 0,
    distance DOUBLE PRECISION DEFAULT 0.0,
    video_url TEXT, -- Added to link incident video directly to the ride log
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


-- STORAGE BUCKET NOTE:
-- Please ensure you have a PUBLIC bucket named 'incident_videos' in your Supabase Storage.
-- You can create this in the Supabase Dashboard -> Storage -> New Bucket.

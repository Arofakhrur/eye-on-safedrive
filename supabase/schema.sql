-- 
-- EYE-ON! Database Schema
-- Run this in your Supabase SQL Editor to set up the necessary tables.
--

-- 1. Create Emergency Contacts table
CREATE TABLE IF NOT EXISTS public.emergency_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;

-- Create Policies
CREATE POLICY "Users can view their own contacts" 
ON public.emergency_contacts FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own contacts" 
ON public.emergency_contacts FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own contacts" 
ON public.emergency_contacts FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own contacts" 
ON public.emergency_contacts FOR DELETE 
USING (auth.uid() = user_id);


-- 2. Create Incident Logs table
CREATE TABLE IF NOT EXISTS public.incident_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    magnitude DOUBLE PRECISION NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.incident_logs ENABLE ROW LEVEL SECURITY;

-- Create Policies
CREATE POLICY "Users can view their own incidents" 
ON public.incident_logs FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own incidents" 
ON public.incident_logs FOR INSERT 
WITH CHECK (auth.uid() = user_id);

# Supabase Setup Guide

To use this application, you need to set up the database tables in your Supabase project.

### Instructions:
1. Go to your [Supabase Dashboard](https://app.supabase.com/).
2. Select your project.
3. Click on the **SQL Editor** in the left sidebar.
4. Click **New query**.
5. Copy the contents of `supabase/schema.sql` and paste them into the editor.
6. Click **Run**.

This will create the `emergency_contacts` and `incident_logs` tables and set up Row Level Security (RLS) so that users can only see and manage their own data.

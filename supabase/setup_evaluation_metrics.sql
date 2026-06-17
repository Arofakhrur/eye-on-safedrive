# Setup Tables: `evaluation_metrics`
```sql
CREATE TABLE IF NOT EXISTS evaluation_metrics (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  test_scenario text NOT NULL,
  gps_latency_ms integer NOT NULL DEFAULT 0,
  ffmpeg_render_ms integer NOT NULL DEFAULT 0,
  telegram_latency_ms integer NOT NULL DEFAULT 0,
  total_response_ms integer NOT NULL DEFAULT 0
);

-- Enable RLS (Row Level Security)
ALTER TABLE evaluation_metrics ENABLE ROW LEVEL SECURITY;

-- Izinkan user (aplikasi) untuk memasukkan data logging
CREATE POLICY "Allow authenticated users to insert metrics" 
  ON evaluation_metrics FOR INSERT 
  TO authenticated 
  WITH CHECK (true);
```

-- Setup Tables: evaluation_metrics
DROP TABLE IF EXISTS evaluation_metrics;

CREATE TABLE evaluation_metrics (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  test_scenario text NOT NULL,
  sensor_detection_ms integer NOT NULL DEFAULT 0,
  video_extraction_ms integer NOT NULL DEFAULT 0,
  gallery_save_ms integer NOT NULL DEFAULT 0,
  telegram_api_ms integer NOT NULL DEFAULT 0,
  total_mitigation_ms integer NOT NULL DEFAULT 0
);

-- Enable RLS (Row Level Security)
ALTER TABLE evaluation_metrics ENABLE ROW LEVEL SECURITY;

-- Izinkan user (aplikasi) untuk memasukkan data logging
CREATE POLICY "Allow authenticated users to insert metrics" 
  ON evaluation_metrics FOR INSERT 
  TO authenticated 
  WITH CHECK (true);


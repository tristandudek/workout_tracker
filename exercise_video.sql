-- Exercise video fields
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS video_url text;
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS video_type text;

-- Storage bucket
INSERT INTO storage.buckets (id, name, public) VALUES ('exercise-videos', 'exercise-videos', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Users can upload exercise videos" ON storage.objects;
CREATE POLICY "Users can upload exercise videos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'exercise-videos');

DROP POLICY IF EXISTS "Exercise videos are publicly viewable" ON storage.objects;
CREATE POLICY "Exercise videos are publicly viewable"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'exercise-videos');

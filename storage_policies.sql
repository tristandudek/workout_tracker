-- ============================================================
-- Forgd — Supabase Storage Bucket Policies
-- Run this in the Supabase SQL Editor
-- ============================================================

-- AVATARS BUCKET
-- Allow authenticated users to upload to their own folder
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Users can upload own avatar"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can update own avatar"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Anyone can read avatars"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'avatars');

-- PROGRESS PHOTOS BUCKET
INSERT INTO storage.buckets (id, name, public) VALUES ('progress-photos', 'progress-photos', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Users can upload own progress photos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'progress-photos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Anyone can read progress photos"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'progress-photos');

-- POST PHOTOS BUCKET
INSERT INTO storage.buckets (id, name, public) VALUES ('post-photos', 'post-photos', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Users can upload own post photos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'post-photos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Anyone can read post photos"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'post-photos');

-- EXERCISE PHOTOS BUCKET
INSERT INTO storage.buckets (id, name, public) VALUES ('exercise-photos', 'exercise-photos', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Users can upload own exercise photos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'exercise-photos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Anyone can read exercise photos"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'exercise-photos');

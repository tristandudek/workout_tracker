-- Community cover photos
ALTER TABLE communities ADD COLUMN IF NOT EXISTS cover_photo_url text;

-- Storage policy (avatars bucket already exists, this just ensures upload works)
-- The avatars bucket INSERT policy should already allow authenticated uploads
-- If not, run:
-- CREATE POLICY "Admins can upload community covers"
-- ON storage.objects FOR INSERT TO authenticated
-- WITH CHECK (bucket_id = 'avatars');

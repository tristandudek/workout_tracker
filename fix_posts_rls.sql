-- Fix workout_posts RLS policies
DROP POLICY IF EXISTS "Anyone can read public posts" ON workout_posts;
DROP POLICY IF EXISTS "Users can read own posts" ON workout_posts;
DROP POLICY IF EXISTS "Users can insert own posts" ON workout_posts;
DROP POLICY IF EXISTS "Users can update own posts" ON workout_posts;
DROP POLICY IF EXISTS "Users can delete own posts" ON workout_posts;

CREATE POLICY "Anyone can read public posts"
ON workout_posts FOR SELECT TO authenticated
USING (is_public = true OR auth.uid() = user_id);

CREATE POLICY "Users can insert own posts"
ON workout_posts FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own posts"
ON workout_posts FOR UPDATE TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own posts"
ON workout_posts FOR DELETE TO authenticated
USING (auth.uid() = user_id);

-- Fix post-photos storage policies
INSERT INTO storage.buckets (id, name, public) VALUES ('post-photos', 'post-photos', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Users can upload post photos" ON storage.objects;
CREATE POLICY "Users can upload post photos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'post-photos');

DROP POLICY IF EXISTS "Post photos are publicly viewable" ON storage.objects;
CREATE POLICY "Post photos are publicly viewable"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'post-photos');

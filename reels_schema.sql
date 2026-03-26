-- Reels tables
CREATE TABLE IF NOT EXISTS reels (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  video_url text NOT NULL,
  thumbnail_url text,
  caption text,
  linked_plan_id uuid REFERENCES workout_plans(id) ON DELETE SET NULL,
  likes_count int DEFAULT 0,
  comments_count int DEFAULT 0,
  views_count int DEFAULT 0,
  is_public boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS reel_likes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  reel_id uuid NOT NULL REFERENCES reels(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(reel_id, user_id)
);

CREATE TABLE IF NOT EXISTS reel_comments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  reel_id uuid NOT NULL REFERENCES reels(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reels_user ON reels(user_id);
CREATE INDEX IF NOT EXISTS idx_reels_created ON reels(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reel_likes_reel ON reel_likes(reel_id);
CREATE INDEX IF NOT EXISTS idx_reel_comments_reel ON reel_comments(reel_id);

ALTER TABLE reels ENABLE ROW LEVEL SECURITY;
ALTER TABLE reel_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE reel_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read public reels" ON reels FOR SELECT TO authenticated USING (is_public = true OR auth.uid() = user_id);
CREATE POLICY "Users can insert own reels" ON reels FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own reels" ON reels FOR UPDATE TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own reels" ON reels FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Anyone can read reel likes" ON reel_likes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can insert own reel likes" ON reel_likes FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own reel likes" ON reel_likes FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Anyone can read reel comments" ON reel_comments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can insert reel comments" ON reel_comments FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own reel comments" ON reel_comments FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- Triggers for like/comment counts
CREATE OR REPLACE FUNCTION update_reel_likes_count() RETURNS trigger AS $$
BEGIN
  IF TG_OP='INSERT' THEN UPDATE reels SET likes_count=likes_count+1 WHERE id=NEW.reel_id;RETURN NEW;
  ELSIF TG_OP='DELETE' THEN UPDATE reels SET likes_count=GREATEST(likes_count-1,0) WHERE id=OLD.reel_id;RETURN OLD;
  END IF;
END;$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_reel_like_change AFTER INSERT OR DELETE ON reel_likes FOR EACH ROW EXECUTE FUNCTION update_reel_likes_count();

CREATE OR REPLACE FUNCTION update_reel_comments_count() RETURNS trigger AS $$
BEGIN
  IF TG_OP='INSERT' THEN UPDATE reels SET comments_count=comments_count+1 WHERE id=NEW.reel_id;RETURN NEW;
  ELSIF TG_OP='DELETE' THEN UPDATE reels SET comments_count=GREATEST(comments_count-1,0) WHERE id=OLD.reel_id;RETURN OLD;
  END IF;
END;$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_reel_comment_change AFTER INSERT OR DELETE ON reel_comments FOR EACH ROW EXECUTE FUNCTION update_reel_comments_count();

-- Storage
INSERT INTO storage.buckets (id, name, public) VALUES ('reels', 'reels', true) ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Users can upload reels" ON storage.objects;
CREATE POLICY "Users can upload reels" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'reels');

DROP POLICY IF EXISTS "Reels are publicly viewable" ON storage.objects;
CREATE POLICY "Reels are publicly viewable" ON storage.objects FOR SELECT TO public USING (bucket_id = 'reels');

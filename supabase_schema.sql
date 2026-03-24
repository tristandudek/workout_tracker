-- ============================================================
-- IRON LOG — Complete Supabase Schema (v2 — Social Features)
-- Run this entire file in the Supabase SQL Editor
-- ============================================================

-- ============================================================
-- 1. PROFILES
-- ============================================================
CREATE TABLE profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text UNIQUE NOT NULL,
  name text NOT NULL,
  email text NOT NULL,
  gender text NOT NULL CHECK (gender IN ('male','female','other','prefer_not_to_say')),
  avatar_url text,
  bio text,
  is_workouts_public boolean DEFAULT false,
  is_weight_public boolean DEFAULT false,
  is_body_fat_public boolean DEFAULT false,
  is_photos_public boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read all profiles (basic info is always public)
CREATE POLICY "Authenticated users can read all profiles"
  ON profiles FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- ============================================================
-- 2. BODY METRICS
-- ============================================================
CREATE TABLE body_metrics (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  weight numeric,
  weight_unit text CHECK (weight_unit IN ('kg','lbs')),
  body_fat_pct numeric,
  recorded_at timestamptz DEFAULT now(),
  CONSTRAINT at_least_one_metric CHECK (weight IS NOT NULL OR body_fat_pct IS NOT NULL)
);

CREATE INDEX idx_body_metrics_user ON body_metrics(user_id);

ALTER TABLE body_metrics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own metrics"
  ON body_metrics FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Public weight/bf readable"
  ON body_metrics FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = body_metrics.user_id
      AND (profiles.is_weight_public = true OR profiles.is_body_fat_public = true)
    )
  );

CREATE POLICY "Users can insert own metrics"
  ON body_metrics FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own metrics"
  ON body_metrics FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- 3. EXERCISES
-- ============================================================
CREATE TABLE exercises (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  muscle_groups jsonb NOT NULL DEFAULT '[]',
  equipment text NOT NULL,
  instructions text,
  diagram text,
  photo_url text,
  video_url text,
  is_custom boolean DEFAULT false,
  created_by_user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_exercises_custom ON exercises(is_custom);
CREATE INDEX idx_exercises_user ON exercises(created_by_user_id);

ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read default exercises"
  ON exercises FOR SELECT
  USING (created_by_user_id IS NULL);

CREATE POLICY "Users can read own custom exercises"
  ON exercises FOR SELECT
  USING (auth.uid() = created_by_user_id);

CREATE POLICY "Users can insert exercises"
  ON exercises FOR INSERT
  WITH CHECK (auth.uid() = created_by_user_id OR created_by_user_id IS NULL);

CREATE POLICY "Users can update own custom exercises"
  ON exercises FOR UPDATE
  USING (auth.uid() = created_by_user_id);

CREATE POLICY "Users can delete own custom exercises"
  ON exercises FOR DELETE
  USING (auth.uid() = created_by_user_id);

-- ============================================================
-- 4. WORKOUT TEMPLATES
-- ============================================================
CREATE TABLE workout_templates (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name text NOT NULL,
  exercises jsonb NOT NULL DEFAULT '[]',
  source_plan_id uuid,
  is_public boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_workout_templates_user ON workout_templates(user_id);
CREATE INDEX idx_workout_templates_plan ON workout_templates(source_plan_id);

ALTER TABLE workout_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own templates"
  ON workout_templates FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Authenticated can read public templates"
  ON workout_templates FOR SELECT TO authenticated
  USING (is_public = true);

CREATE POLICY "Users can insert own templates"
  ON workout_templates FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own templates"
  ON workout_templates FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own templates"
  ON workout_templates FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- 5. WORKOUT LOGS
-- ============================================================
CREATE TABLE workout_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  workout_name text NOT NULL,
  start_time timestamptz NOT NULL,
  end_time timestamptz,
  exercises jsonb NOT NULL DEFAULT '[]',
  source_plan_id uuid,
  source_plan_owner_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_workout_logs_user ON workout_logs(user_id);
CREATE INDEX idx_workout_logs_start ON workout_logs(user_id, start_time);
CREATE INDEX idx_workout_logs_plan ON workout_logs(source_plan_id);
CREATE INDEX idx_workout_logs_plan_owner ON workout_logs(source_plan_owner_id);

ALTER TABLE workout_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own logs"
  ON workout_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Public workout logs readable"
  ON workout_logs FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = workout_logs.user_id
      AND profiles.is_workouts_public = true
    )
  );

CREATE POLICY "Users can insert own logs"
  ON workout_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own logs"
  ON workout_logs FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- 6. WORKOUT PLANS
-- ============================================================
CREATE TABLE workout_plans (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  workouts jsonb NOT NULL DEFAULT '[]',
  is_public boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_workout_plans_user ON workout_plans(user_id);

ALTER TABLE workout_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own plans"
  ON workout_plans FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Authenticated can read public plans"
  ON workout_plans FOR SELECT TO authenticated
  USING (is_public = true);

CREATE POLICY "Users can insert own plans"
  ON workout_plans FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own plans"
  ON workout_plans FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own plans"
  ON workout_plans FOR DELETE
  USING (auth.uid() = user_id);

-- Add FK now that workout_plans exists
ALTER TABLE workout_templates
  ADD CONSTRAINT fk_templates_source_plan
  FOREIGN KEY (source_plan_id) REFERENCES workout_plans(id) ON DELETE SET NULL;

ALTER TABLE workout_logs
  ADD CONSTRAINT fk_logs_source_plan
  FOREIGN KEY (source_plan_id) REFERENCES workout_plans(id) ON DELETE SET NULL;

-- ============================================================
-- 7. PLAN ADOPTIONS
-- ============================================================
CREATE TABLE plan_adoptions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  plan_id uuid NOT NULL REFERENCES workout_plans(id) ON DELETE CASCADE,
  adopted_by_user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  is_active boolean DEFAULT true,
  adopted_at timestamptz DEFAULT now(),
  UNIQUE(plan_id, adopted_by_user_id)
);

CREATE INDEX idx_plan_adoptions_plan ON plan_adoptions(plan_id);
CREATE INDEX idx_plan_adoptions_user ON plan_adoptions(adopted_by_user_id);

ALTER TABLE plan_adoptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Plan owner can read adoptions"
  ON plan_adoptions FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM workout_plans
      WHERE workout_plans.id = plan_adoptions.plan_id
      AND workout_plans.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can read own adoptions"
  ON plan_adoptions FOR SELECT
  USING (auth.uid() = adopted_by_user_id);

CREATE POLICY "Users can insert own adoptions"
  ON plan_adoptions FOR INSERT
  WITH CHECK (auth.uid() = adopted_by_user_id);

CREATE POLICY "Users can update own adoptions"
  ON plan_adoptions FOR UPDATE
  USING (auth.uid() = adopted_by_user_id);

CREATE POLICY "Users can delete own adoptions"
  ON plan_adoptions FOR DELETE
  USING (auth.uid() = adopted_by_user_id);

-- ============================================================
-- 8. PROGRESS PHOTOS
-- ============================================================
CREATE TABLE progress_photos (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  photo_url text NOT NULL,
  caption text,
  is_public boolean DEFAULT false,
  recorded_at timestamptz DEFAULT now()
);

CREATE INDEX idx_progress_photos_user ON progress_photos(user_id);

ALTER TABLE progress_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own photos"
  ON progress_photos FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Public photos readable"
  ON progress_photos FOR SELECT TO authenticated
  USING (is_public = true);

CREATE POLICY "Users can insert own photos"
  ON progress_photos FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own photos"
  ON progress_photos FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- 9. WORKOUT POSTS
-- ============================================================
CREATE TABLE workout_posts (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  workout_log_id uuid REFERENCES workout_logs(id) ON DELETE SET NULL,
  caption text,
  photo_urls jsonb DEFAULT '[]',
  likes_count int DEFAULT 0,
  comments_count int DEFAULT 0,
  is_public boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_workout_posts_user ON workout_posts(user_id);
CREATE INDEX idx_workout_posts_created ON workout_posts(created_at DESC);

ALTER TABLE workout_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read public posts"
  ON workout_posts FOR SELECT TO authenticated
  USING (is_public = true);

CREATE POLICY "Users can read own posts"
  ON workout_posts FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own posts"
  ON workout_posts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own posts"
  ON workout_posts FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own posts"
  ON workout_posts FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- 10. POST LIKES
-- ============================================================
CREATE TABLE post_likes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  post_id uuid NOT NULL REFERENCES workout_posts(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, post_id)
);

CREATE INDEX idx_post_likes_post ON post_likes(post_id);

ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read likes"
  ON post_likes FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Users can insert own likes"
  ON post_likes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own likes"
  ON post_likes FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- 11. POST COMMENTS
-- ============================================================
CREATE TABLE post_comments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  post_id uuid NOT NULL REFERENCES workout_posts(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_post_comments_post ON post_comments(post_id);

ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read comments"
  ON post_comments FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Users can insert own comments"
  ON post_comments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own comments"
  ON post_comments FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- 12. NOTIFICATIONS
-- ============================================================
CREATE TABLE notifications (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('like','comment','plan_adopted','plan_workout_completed')),
  message text NOT NULL,
  related_id uuid,
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);
CREATE INDEX idx_notifications_created ON notifications(user_id, created_at DESC);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Authenticated can insert notifications"
  ON notifications FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own notifications"
  ON notifications FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- 13. TRIGGER: Auto-create profile on signup
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, username, name, email, gender)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', 'user_' || LEFT(NEW.id::text, 8)),
    COALESCE(NEW.raw_user_meta_data->>'name', 'New User'),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'gender', 'prefer_not_to_say')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- 14. TRIGGER: Update likes_count on workout_posts
-- ============================================================
CREATE OR REPLACE FUNCTION update_likes_count()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE workout_posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE workout_posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_like_change
  AFTER INSERT OR DELETE ON post_likes
  FOR EACH ROW EXECUTE FUNCTION update_likes_count();

-- ============================================================
-- 15. TRIGGER: Update comments_count on workout_posts
-- ============================================================
CREATE OR REPLACE FUNCTION update_comments_count()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE workout_posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE workout_posts SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_comment_change
  AFTER INSERT OR DELETE ON post_comments
  FOR EACH ROW EXECUTE FUNCTION update_comments_count();

-- ============================================================
-- 16. TRIGGER: Notify on like
-- ============================================================
CREATE OR REPLACE FUNCTION notify_on_like()
RETURNS trigger AS $$
DECLARE
  post_owner_id uuid;
  actor_name text;
BEGIN
  SELECT user_id INTO post_owner_id FROM workout_posts WHERE id = NEW.post_id;
  IF post_owner_id IS NULL OR post_owner_id = NEW.user_id THEN RETURN NEW; END IF;
  SELECT name INTO actor_name FROM profiles WHERE id = NEW.user_id;
  INSERT INTO notifications (user_id, type, message, related_id)
  VALUES (post_owner_id, 'like', actor_name || ' liked your workout', NEW.post_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_like_notify
  AFTER INSERT ON post_likes
  FOR EACH ROW EXECUTE FUNCTION notify_on_like();

-- ============================================================
-- 17. TRIGGER: Notify on comment
-- ============================================================
CREATE OR REPLACE FUNCTION notify_on_comment()
RETURNS trigger AS $$
DECLARE
  post_owner_id uuid;
  actor_name text;
  short_content text;
BEGIN
  SELECT user_id INTO post_owner_id FROM workout_posts WHERE id = NEW.post_id;
  IF post_owner_id IS NULL OR post_owner_id = NEW.user_id THEN RETURN NEW; END IF;
  SELECT name INTO actor_name FROM profiles WHERE id = NEW.user_id;
  short_content := LEFT(NEW.content, 50);
  INSERT INTO notifications (user_id, type, message, related_id)
  VALUES (post_owner_id, 'comment', actor_name || ' commented: ' || short_content, NEW.post_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_comment_notify
  AFTER INSERT ON post_comments
  FOR EACH ROW EXECUTE FUNCTION notify_on_comment();

-- ============================================================
-- 18. TRIGGER: Notify on plan adoption
-- ============================================================
CREATE OR REPLACE FUNCTION notify_on_plan_adoption()
RETURNS trigger AS $$
DECLARE
  plan_owner_id uuid;
  plan_name text;
  actor_name text;
BEGIN
  SELECT user_id, name INTO plan_owner_id, plan_name FROM workout_plans WHERE id = NEW.plan_id;
  IF plan_owner_id IS NULL OR plan_owner_id = NEW.adopted_by_user_id THEN RETURN NEW; END IF;
  SELECT name INTO actor_name FROM profiles WHERE id = NEW.adopted_by_user_id;
  INSERT INTO notifications (user_id, type, message, related_id)
  VALUES (plan_owner_id, 'plan_adopted', actor_name || ' is now using your plan: ' || plan_name, NEW.plan_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_plan_adopt_notify
  AFTER INSERT ON plan_adoptions
  FOR EACH ROW EXECUTE FUNCTION notify_on_plan_adoption();

-- ============================================================
-- 19. RPC: Get social feed
-- ============================================================
CREATE OR REPLACE FUNCTION get_feed(p_limit int DEFAULT 20, p_offset int DEFAULT 0)
RETURNS TABLE (
  post_id uuid, post_user_id uuid, workout_log_id uuid, caption text,
  photo_urls jsonb, likes_count int, comments_count int, post_created_at timestamptz,
  author_name text, author_username text, author_avatar_url text,
  workout_name text, workout_duration int, workout_volume numeric,
  workout_exercise_count int, i_liked boolean
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    wp.id, wp.user_id, wp.workout_log_id, wp.caption,
    wp.photo_urls, wp.likes_count, wp.comments_count, wp.created_at,
    p.name, p.username, p.avatar_url,
    wl.workout_name,
    CASE WHEN wl.end_time IS NOT NULL AND wl.start_time IS NOT NULL
      THEN EXTRACT(EPOCH FROM (wl.end_time - wl.start_time))::int / 60
      ELSE 0 END,
    0::numeric,
    COALESCE(jsonb_array_length(wl.exercises), 0),
    EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id = wp.id AND pl.user_id = auth.uid())
  FROM workout_posts wp
  JOIN profiles p ON p.id = wp.user_id
  LEFT JOIN workout_logs wl ON wl.id = wp.workout_log_id
  WHERE wp.is_public = true
  ORDER BY wp.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 20. RPC: Search users
-- ============================================================
CREATE OR REPLACE FUNCTION search_users(query text, p_limit int DEFAULT 20)
RETURNS TABLE (
  user_id uuid, name text, username text, avatar_url text, bio text
) AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.name, p.username, p.avatar_url, p.bio
  FROM profiles p
  WHERE p.name ILIKE '%' || query || '%'
     OR p.username ILIKE '%' || query || '%'
  ORDER BY p.name
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 21. RPC: Get creator stats
-- ============================================================
CREATE OR REPLACE FUNCTION get_creator_stats(p_user_id uuid)
RETURNS TABLE (
  total_plan_adoptions bigint,
  total_workouts_from_plans bigint,
  most_popular_plan_name text,
  most_popular_plan_adoptions bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM plan_adoptions pa
     JOIN workout_plans wp ON wp.id = pa.plan_id
     WHERE wp.user_id = p_user_id),
    (SELECT count(*) FROM workout_logs wl
     WHERE wl.source_plan_owner_id = p_user_id
     AND wl.user_id != p_user_id),
    (SELECT wp.name FROM workout_plans wp
     LEFT JOIN plan_adoptions pa ON pa.plan_id = wp.id
     WHERE wp.user_id = p_user_id
     GROUP BY wp.id, wp.name
     ORDER BY count(pa.id) DESC LIMIT 1),
    (SELECT count(pa.id) FROM workout_plans wp
     LEFT JOIN plan_adoptions pa ON pa.plan_id = wp.id
     WHERE wp.user_id = p_user_id
     GROUP BY wp.id
     ORDER BY count(pa.id) DESC LIMIT 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

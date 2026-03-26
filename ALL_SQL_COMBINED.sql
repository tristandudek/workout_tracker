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
-- ============================================================
-- IRON LOG — Communities Schema Addition
-- Run this in the Supabase SQL Editor AFTER the main schema
-- ============================================================

-- Add bio column to profiles if not exists
DO $$ BEGIN
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bio text;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- ============================================================
-- COMMUNITIES
-- ============================================================
CREATE TABLE IF NOT EXISTS communities (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  description text,
  avatar_url text,
  is_private boolean DEFAULT false,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_communities_creator ON communities(created_by);

ALTER TABLE communities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read public communities"
  ON communities FOR SELECT TO authenticated
  USING (is_private = false);

CREATE POLICY "Members can read private communities"
  ON communities FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM community_members
      WHERE community_members.community_id = communities.id
      AND community_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Authenticated can create communities"
  ON communities FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Admins can update communities"
  ON communities FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM community_members
      WHERE community_members.community_id = communities.id
      AND community_members.user_id = auth.uid()
      AND community_members.role = 'admin'
    )
  );

CREATE POLICY "Admins can delete communities"
  ON communities FOR DELETE TO authenticated
  USING (auth.uid() = created_by);

-- ============================================================
-- COMMUNITY MEMBERS
-- ============================================================
CREATE TABLE IF NOT EXISTS community_members (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  community_id uuid NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role text DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  joined_at timestamptz DEFAULT now(),
  invited_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  UNIQUE(community_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_community_members_community ON community_members(community_id);
CREATE INDEX IF NOT EXISTS idx_community_members_user ON community_members(user_id);

ALTER TABLE community_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can read community memberships"
  ON community_members FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM community_members cm2
      WHERE cm2.community_id = community_members.community_id
      AND cm2.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM communities c
      WHERE c.id = community_members.community_id
      AND c.is_private = false
    )
  );

CREATE POLICY "Users can insert own membership (public join)"
  ON community_members FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can insert members (invites)"
  ON community_members FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM community_members cm2
      WHERE cm2.community_id = community_members.community_id
      AND cm2.user_id = auth.uid()
      AND cm2.role = 'admin'
    )
  );

CREATE POLICY "Admins can update members"
  ON community_members FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM community_members cm2
      WHERE cm2.community_id = community_members.community_id
      AND cm2.user_id = auth.uid()
      AND cm2.role = 'admin'
    )
  );

CREATE POLICY "Users can delete own membership (leave)"
  ON community_members FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can remove members"
  ON community_members FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM community_members cm2
      WHERE cm2.community_id = community_members.community_id
      AND cm2.user_id = auth.uid()
      AND cm2.role = 'admin'
    )
  );

-- ============================================================
-- COMMUNITY INVITES
-- ============================================================
CREATE TABLE IF NOT EXISTS community_invites (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  community_id uuid NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  invited_user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  invited_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_community_invites_user ON community_invites(invited_user_id);
CREATE INDEX IF NOT EXISTS idx_community_invites_community ON community_invites(community_id);

ALTER TABLE community_invites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Invited user can read own invites"
  ON community_invites FOR SELECT TO authenticated
  USING (auth.uid() = invited_user_id);

CREATE POLICY "Admins can read community invites"
  ON community_invites FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM community_members
      WHERE community_members.community_id = community_invites.community_id
      AND community_members.user_id = auth.uid()
      AND community_members.role = 'admin'
    )
  );

CREATE POLICY "Admins can create invites"
  ON community_invites FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = invited_by);

CREATE POLICY "Invited user can update own invites"
  ON community_invites FOR UPDATE TO authenticated
  USING (auth.uid() = invited_user_id);

-- ============================================================
-- TRIGGER: Notify on community invite
-- ============================================================
CREATE OR REPLACE FUNCTION notify_on_community_invite()
RETURNS trigger AS $$
DECLARE
  inviter_name text;
  comm_name text;
BEGIN
  SELECT name INTO inviter_name FROM profiles WHERE id = NEW.invited_by;
  SELECT name INTO comm_name FROM communities WHERE id = NEW.community_id;
  INSERT INTO notifications (user_id, type, message, related_id)
  VALUES (NEW.invited_user_id, 'community_invite',
    inviter_name || ' invited you to join ' || comm_name, NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_community_invite
  AFTER INSERT ON community_invites
  FOR EACH ROW EXECUTE FUNCTION notify_on_community_invite();

-- Update notifications type check to include community_invite
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN ('like','comment','plan_adopted','plan_workout_completed','community_invite'));
-- ============================================================
-- Forgd — Follows Table
-- Run this in the Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS follows (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  follower_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  following_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(follower_id, following_id),
  CONSTRAINT no_self_follow CHECK (follower_id != following_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_follower ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_id);

ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read follows"
  ON follows FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Users can insert own follows"
  ON follows FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can delete own follows"
  ON follows FOR DELETE TO authenticated
  USING (auth.uid() = follower_id);

-- Notification trigger for new follow
CREATE OR REPLACE FUNCTION notify_on_follow()
RETURNS trigger AS $$
DECLARE
  follower_name text;
BEGIN
  IF NEW.follower_id = NEW.following_id THEN RETURN NEW; END IF;
  SELECT name INTO follower_name FROM profiles WHERE id = NEW.follower_id;
  INSERT INTO notifications (user_id, type, message, related_id)
  VALUES (NEW.following_id, 'follow', follower_name || ' started following you', NEW.follower_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_follow_notify
  AFTER INSERT ON follows
  FOR EACH ROW EXECUTE FUNCTION notify_on_follow();

-- Update notifications type check to include follow
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN ('like','comment','plan_adopted','plan_workout_completed','community_invite','follow'));
-- ============================================================
-- Forgd — Saved Plans, Conversations, Messages
-- Run this in Supabase SQL Editor
-- ============================================================

-- SAVED PLANS
CREATE TABLE IF NOT EXISTS saved_plans (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES workout_plans(id) ON DELETE CASCADE,
  saved_at timestamptz DEFAULT now(),
  UNIQUE(user_id, plan_id)
);
CREATE INDEX IF NOT EXISTS idx_saved_plans_user ON saved_plans(user_id);
ALTER TABLE saved_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own saved plans"
  ON saved_plans FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- CONVERSATIONS
CREATE TABLE IF NOT EXISTS conversations (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  participant_1 uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  participant_2 uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  last_message_at timestamptz DEFAULT now(),
  request_status text DEFAULT 'pending' CHECK (request_status IN ('pending','accepted','declined')),
  UNIQUE(participant_1, participant_2)
);
CREATE INDEX IF NOT EXISTS idx_conversations_p1 ON conversations(participant_1);
CREATE INDEX IF NOT EXISTS idx_conversations_p2 ON conversations(participant_2);
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Participants can read own conversations"
  ON conversations FOR SELECT TO authenticated
  USING (auth.uid() = participant_1 OR auth.uid() = participant_2);
CREATE POLICY "Authenticated can create conversations"
  ON conversations FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = participant_1 OR auth.uid() = participant_2);
CREATE POLICY "Participants can update own conversations"
  ON conversations FOR UPDATE TO authenticated
  USING (auth.uid() = participant_1 OR auth.uid() = participant_2);

-- MESSAGES
CREATE TABLE IF NOT EXISTS messages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamptz DEFAULT now(),
  is_read boolean DEFAULT false
);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id, created_at);
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Participants can read conversation messages"
  ON messages FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = messages.conversation_id
      AND (c.participant_1 = auth.uid() OR c.participant_2 = auth.uid())
    )
  );
CREATE POLICY "Participants can insert messages"
  ON messages FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = messages.conversation_id
      AND (c.participant_1 = auth.uid() OR c.participant_2 = auth.uid())
    )
  );

-- Notification trigger for new message
CREATE OR REPLACE FUNCTION notify_on_message()
RETURNS trigger AS $$
DECLARE
  sender_name text;
  recipient_id uuid;
  conv_status text;
BEGIN
  SELECT name INTO sender_name FROM profiles WHERE id = NEW.sender_id;
  SELECT
    CASE WHEN participant_1 = NEW.sender_id THEN participant_2 ELSE participant_1 END,
    request_status INTO recipient_id, conv_status
  FROM conversations WHERE id = NEW.conversation_id;
  IF recipient_id IS NULL OR recipient_id = NEW.sender_id THEN RETURN NEW; END IF;
  IF conv_status = 'pending' THEN
    INSERT INTO notifications (user_id, type, message, related_id)
    VALUES (recipient_id, 'message_request', sender_name || ' wants to send you a message', NEW.conversation_id::text);
  ELSE
    INSERT INTO notifications (user_id, type, message, related_id)
    VALUES (recipient_id, 'message', sender_name || ' sent you a message', NEW.conversation_id::text);
  END IF;
  -- Update last_message_at
  UPDATE conversations SET last_message_at = now() WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_new_message ON messages;
CREATE TRIGGER on_new_message
  AFTER INSERT ON messages
  FOR EACH ROW EXECUTE FUNCTION notify_on_message();

-- Update notifications type constraint
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN ('like','comment','plan_adopted','plan_workout_completed','community_invite','follow','challenge_ended','message','message_request'));
-- Fix community challenges tables and RLS
CREATE TABLE IF NOT EXISTS community_challenges (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  community_id uuid REFERENCES communities(id) ON DELETE CASCADE,
  created_by uuid REFERENCES profiles(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  start_date date NOT NULL,
  end_date date NOT NULL,
  workouts_per_week int DEFAULT 3,
  min_workout_minutes int DEFAULT 0,
  allowed_workout_types text[] DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS challenge_completions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  challenge_id uuid REFERENCES community_challenges(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  workout_log_id uuid,
  completed_at timestamptz DEFAULT now()
);

ALTER TABLE community_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenge_completions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Members can read community challenges" ON community_challenges;
DROP POLICY IF EXISTS "Admins can insert challenges" ON community_challenges;
DROP POLICY IF EXISTS "Admins can update challenges" ON community_challenges;
DROP POLICY IF EXISTS "Admins can delete challenges" ON community_challenges;
DROP POLICY IF EXISTS "Community members can read challenges" ON community_challenges;
DROP POLICY IF EXISTS "Admins can create challenges" ON community_challenges;

CREATE POLICY "Community members can read challenges"
ON community_challenges FOR SELECT TO authenticated
USING (community_id IN (
  SELECT community_id FROM community_members WHERE user_id = auth.uid()
));

CREATE POLICY "Admins can create challenges"
ON community_challenges FOR INSERT TO authenticated
WITH CHECK (created_by = auth.uid() AND community_id IN (
  SELECT community_id FROM community_members WHERE user_id = auth.uid() AND role = 'admin'
));

CREATE POLICY "Admins can update challenges"
ON community_challenges FOR UPDATE TO authenticated
USING (community_id IN (
  SELECT community_id FROM community_members WHERE user_id = auth.uid() AND role = 'admin'
));

CREATE POLICY "Admins can delete challenges"
ON community_challenges FOR DELETE TO authenticated
USING (community_id IN (
  SELECT community_id FROM community_members WHERE user_id = auth.uid() AND role = 'admin'
));

DROP POLICY IF EXISTS "Members can log completions" ON challenge_completions;
DROP POLICY IF EXISTS "Members can read completions" ON challenge_completions;

CREATE POLICY "Members can log completions"
ON challenge_completions FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Members can read completions"
ON challenge_completions FOR SELECT TO authenticated
USING (true);
-- ============================================================
-- Forgd — Challenge Completion Posts
-- Run this in the Supabase SQL Editor
-- ============================================================

-- Add type and challenge_id to workout_posts for special posts
ALTER TABLE workout_posts ADD COLUMN IF NOT EXISTS post_type text DEFAULT 'workout';
ALTER TABLE workout_posts ADD COLUMN IF NOT EXISTS challenge_id uuid REFERENCES community_challenges(id) ON DELETE SET NULL;

-- Update notifications type check to include challenge_ended
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN ('like','comment','plan_adopted','plan_workout_completed','community_invite','follow','challenge_ended'));
-- Add description column to workout_templates
ALTER TABLE workout_templates ADD COLUMN IF NOT EXISTS description text;
-- Add auto-incrementing member number to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS member_number SERIAL;
-- Add tracking_type to exercises
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS tracking_type text DEFAULT 'reps';

-- Add cardio_machine to equipment if not in check constraint
-- (exercises table has no check constraint on equipment, so this is just for reference)
-- Workout folders
CREATE TABLE IF NOT EXISTS workout_folders (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name text NOT NULL,
  color text DEFAULT '#38bdf8',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE workout_folders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own folders"
ON workout_folders FOR ALL TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

ALTER TABLE workout_templates ADD COLUMN IF NOT EXISTS folder_id uuid REFERENCES workout_folders(id) ON DELETE SET NULL;
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
-- ============================================================
-- Forgd — Notifications Table (ensure exists with correct RLS)
-- Run this in Supabase SQL Editor
-- ============================================================

-- Create table if not exists (safe to run multiple times)
CREATE TABLE IF NOT EXISTS notifications (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type text NOT NULL,
  message text NOT NULL,
  related_id text,
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(user_id, created_at DESC);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop and recreate policies to ensure they're correct
DROP POLICY IF EXISTS "Users can read own notifications" ON notifications;
CREATE POLICY "Users can read own notifications"
  ON notifications FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Authenticated can insert notifications" ON notifications;
CREATE POLICY "Authenticated can insert notifications"
  ON notifications FOR INSERT TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
CREATE POLICY "Users can delete own notifications"
  ON notifications FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Ensure follow notification trigger exists
CREATE OR REPLACE FUNCTION notify_on_follow()
RETURNS trigger AS $$
DECLARE
  follower_name text;
BEGIN
  IF NEW.follower_id = NEW.following_id THEN RETURN NEW; END IF;
  SELECT name INTO follower_name FROM profiles WHERE id = NEW.follower_id;
  INSERT INTO notifications (user_id, type, message, related_id)
  VALUES (NEW.following_id, 'follow', follower_name || ' started following you', NEW.follower_id::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_follow_notify ON follows;
CREATE TRIGGER on_follow_notify
  AFTER INSERT ON follows
  FOR EACH ROW EXECUTE FUNCTION notify_on_follow();

-- Ensure community invite notification trigger exists
CREATE OR REPLACE FUNCTION notify_on_community_invite()
RETURNS trigger AS $$
DECLARE
  inviter_name text;
  comm_name text;
BEGIN
  SELECT name INTO inviter_name FROM profiles WHERE id = NEW.invited_by;
  SELECT name INTO comm_name FROM communities WHERE id = NEW.community_id;
  INSERT INTO notifications (user_id, type, message, related_id)
  VALUES (NEW.invited_user_id, 'community_invite',
    inviter_name || ' invited you to join ' || comm_name, NEW.id::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_community_invite ON community_invites;
CREATE TRIGGER on_community_invite
  AFTER INSERT ON community_invites
  FOR EACH ROW EXECUTE FUNCTION notify_on_community_invite();
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
-- Allow participants to mark messages as read
CREATE POLICY "Participants can update messages"
ON messages FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = messages.conversation_id
    AND (c.participant_1 = auth.uid() OR c.participant_2 = auth.uid())
  )
);
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

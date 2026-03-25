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

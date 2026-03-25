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

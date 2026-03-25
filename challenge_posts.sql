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

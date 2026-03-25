-- ============================================================
-- Forgd — Workout Types & Community Challenges Schema
-- Run this in the Supabase SQL Editor
-- ============================================================

-- 1. Add workout_type to exercises
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS workout_type text;

-- 2. Add workout_types array to workout_templates
ALTER TABLE workout_templates ADD COLUMN IF NOT EXISTS workout_types text[] DEFAULT '{}';

-- 3. Community Challenges
CREATE TABLE IF NOT EXISTS community_challenges (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  community_id uuid NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  start_date date NOT NULL,
  end_date date NOT NULL,
  workouts_per_week int DEFAULT 3,
  min_workout_minutes int DEFAULT 30,
  allowed_workout_types text[] DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_challenges_community ON community_challenges(community_id);

ALTER TABLE community_challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can read community challenges"
  ON community_challenges FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM community_members
      WHERE community_members.community_id = community_challenges.community_id
      AND community_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can insert challenges"
  ON community_challenges FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM community_members
      WHERE community_members.community_id = community_challenges.community_id
      AND community_members.user_id = auth.uid()
      AND community_members.role = 'admin'
    )
  );

CREATE POLICY "Admins can update challenges"
  ON community_challenges FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM community_members
      WHERE community_members.community_id = community_challenges.community_id
      AND community_members.user_id = auth.uid()
      AND community_members.role = 'admin'
    )
  );

CREATE POLICY "Admins can delete challenges"
  ON community_challenges FOR DELETE TO authenticated
  USING (auth.uid() = created_by);

-- 4. Challenge Completions
CREATE TABLE IF NOT EXISTS challenge_completions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  challenge_id uuid NOT NULL REFERENCES community_challenges(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  workout_log_id uuid REFERENCES workout_logs(id) ON DELETE SET NULL,
  completed_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_completions_challenge ON challenge_completions(challenge_id);
CREATE INDEX IF NOT EXISTS idx_completions_user ON challenge_completions(user_id);

ALTER TABLE challenge_completions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can read challenge completions"
  ON challenge_completions FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM community_challenges cc
      JOIN community_members cm ON cm.community_id = cc.community_id
      WHERE cc.id = challenge_completions.challenge_id
      AND cm.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own completions"
  ON challenge_completions FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

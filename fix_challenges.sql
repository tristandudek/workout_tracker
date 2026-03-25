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

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

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

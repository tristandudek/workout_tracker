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

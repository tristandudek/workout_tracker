-- Add auto-incrementing member number to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS member_number SERIAL;

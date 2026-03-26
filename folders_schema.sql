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

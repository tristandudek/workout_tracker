-- Add tracking_type to exercises
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS tracking_type text DEFAULT 'reps';

-- Add cardio_machine to equipment if not in check constraint
-- (exercises table has no check constraint on equipment, so this is just for reference)

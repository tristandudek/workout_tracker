-- Add description column to workout_templates
ALTER TABLE workout_templates ADD COLUMN IF NOT EXISTS description text;

-- Add per-workout-type rules to challenges
ALTER TABLE community_challenges ADD COLUMN IF NOT EXISTS workout_type_rules jsonb DEFAULT '[]';

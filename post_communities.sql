-- Add community_ids to workout_posts
ALTER TABLE workout_posts ADD COLUMN IF NOT EXISTS community_ids uuid[] DEFAULT '{}';

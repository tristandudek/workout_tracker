-- Community posts
CREATE TABLE IF NOT EXISTS community_posts (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  community_id uuid NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content text NOT NULL,
  photo_urls text[] DEFAULT '{}',
  likes_count int DEFAULT 0,
  comments_count int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS community_post_likes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id uuid NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(post_id, user_id)
);

CREATE TABLE IF NOT EXISTS community_post_comments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id uuid NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content text NOT NULL,
  photo_urls text[] DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_community_posts_community ON community_posts(community_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_post_likes_post ON community_post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_community_post_comments_post ON community_post_comments(post_id);

ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_post_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Community members can read posts" ON community_posts FOR SELECT TO authenticated
USING (community_id IN (SELECT community_id FROM community_members WHERE user_id = auth.uid()));
CREATE POLICY "Community members can create posts" ON community_posts FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id AND community_id IN (SELECT community_id FROM community_members WHERE user_id = auth.uid()));
CREATE POLICY "Post owners can delete posts" ON community_posts FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Members can read post likes" ON community_post_likes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Members can manage own likes" ON community_post_likes FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Members can delete own likes" ON community_post_likes FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Members can read comments" ON community_post_comments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Members can create comments" ON community_post_comments FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Members can delete own comments" ON community_post_comments FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- Like/comment count triggers
CREATE OR REPLACE FUNCTION update_community_post_likes_count() RETURNS trigger AS $$
BEGIN
  IF TG_OP='INSERT' THEN UPDATE community_posts SET likes_count=likes_count+1 WHERE id=NEW.post_id;RETURN NEW;
  ELSIF TG_OP='DELETE' THEN UPDATE community_posts SET likes_count=GREATEST(likes_count-1,0) WHERE id=OLD.post_id;RETURN OLD;
  END IF;
END;$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE TRIGGER on_community_post_like_change AFTER INSERT OR DELETE ON community_post_likes FOR EACH ROW EXECUTE FUNCTION update_community_post_likes_count();

CREATE OR REPLACE FUNCTION update_community_post_comments_count() RETURNS trigger AS $$
BEGIN
  IF TG_OP='INSERT' THEN UPDATE community_posts SET comments_count=comments_count+1 WHERE id=NEW.post_id;RETURN NEW;
  ELSIF TG_OP='DELETE' THEN UPDATE community_posts SET comments_count=GREATEST(comments_count-1,0) WHERE id=OLD.post_id;RETURN OLD;
  END IF;
END;$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE TRIGGER on_community_post_comment_change AFTER INSERT OR DELETE ON community_post_comments FOR EACH ROW EXECUTE FUNCTION update_community_post_comments_count();

-- Notification triggers
CREATE OR REPLACE FUNCTION notify_community_post_like() RETURNS trigger AS $$
DECLARE post_owner uuid; actor_name text; comm_name text;
BEGIN
  SELECT user_id, community_id INTO post_owner FROM community_posts WHERE id=NEW.post_id;
  IF post_owner IS NULL OR post_owner=NEW.user_id THEN RETURN NEW; END IF;
  SELECT name INTO actor_name FROM profiles WHERE id=NEW.user_id;
  SELECT name INTO comm_name FROM communities WHERE id=(SELECT community_id FROM community_posts WHERE id=NEW.post_id);
  INSERT INTO notifications(user_id,type,message,related_id) VALUES(post_owner,'like',actor_name||' liked your post in '||comm_name,NEW.post_id::text);
  RETURN NEW;
END;$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE TRIGGER on_community_post_like_notify AFTER INSERT ON community_post_likes FOR EACH ROW EXECUTE FUNCTION notify_community_post_like();

CREATE OR REPLACE FUNCTION notify_community_post_comment() RETURNS trigger AS $$
DECLARE post_owner uuid; actor_name text; comm_name text;
BEGIN
  SELECT user_id, community_id INTO post_owner FROM community_posts WHERE id=NEW.post_id;
  IF post_owner IS NULL OR post_owner=NEW.user_id THEN RETURN NEW; END IF;
  SELECT name INTO actor_name FROM profiles WHERE id=NEW.user_id;
  SELECT name INTO comm_name FROM communities WHERE id=(SELECT community_id FROM community_posts WHERE id=NEW.post_id);
  INSERT INTO notifications(user_id,type,message,related_id) VALUES(post_owner,'comment',actor_name||' commented on your post in '||comm_name,NEW.post_id::text);
  RETURN NEW;
END;$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE TRIGGER on_community_post_comment_notify AFTER INSERT ON community_post_comments FOR EACH ROW EXECUTE FUNCTION notify_community_post_comment();

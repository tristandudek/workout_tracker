-- Plan monetization
ALTER TABLE workout_plans ADD COLUMN IF NOT EXISTS visibility text DEFAULT 'public_free';
ALTER TABLE workout_plans ADD COLUMN IF NOT EXISTS price numeric(10,2) DEFAULT 0;
ALTER TABLE workout_plans ADD COLUMN IF NOT EXISTS currency text DEFAULT 'USD';

CREATE TABLE IF NOT EXISTS plan_purchases (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  plan_id uuid NOT NULL REFERENCES workout_plans(id) ON DELETE CASCADE,
  buyer_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  seller_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  price_paid numeric(10,2),
  currency text DEFAULT 'USD',
  purchased_at timestamptz DEFAULT now(),
  payment_status text DEFAULT 'pending',
  UNIQUE(plan_id, buyer_id)
);

CREATE INDEX IF NOT EXISTS idx_purchases_buyer ON plan_purchases(buyer_id);
CREATE INDEX IF NOT EXISTS idx_purchases_seller ON plan_purchases(seller_id);

ALTER TABLE plan_purchases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own purchases"
ON plan_purchases FOR SELECT TO authenticated
USING (auth.uid() = buyer_id OR auth.uid() = seller_id);

CREATE POLICY "Users can insert purchases"
ON plan_purchases FOR INSERT TO authenticated
WITH CHECK (auth.uid() = buyer_id);

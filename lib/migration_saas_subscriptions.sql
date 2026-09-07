-- Upgrade: Add SaaS Subscription & RLS Enhancements

DO $$
BEGIN
    -- 1. Add Subscription Fields to Organization
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_organizations' AND column_name = 'subscription_tier') THEN
        ALTER TABLE omtbl_organizations ADD COLUMN subscription_tier TEXT DEFAULT 'free';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_organizations' AND column_name = 'subscription_status') THEN
        ALTER TABLE omtbl_organizations ADD COLUMN subscription_status TEXT DEFAULT 'active'; -- active, past_due, canceled
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_organizations' AND column_name = 'stripe_customer_id') THEN
        ALTER TABLE omtbl_organizations ADD COLUMN stripe_customer_id TEXT;
    END IF;

    -- 2. Enhanced User Profile Linking
    -- Ensure explicit link to Supabase Auth if not already clear (we usually rely on id=auth.uid(), but an explicit column helps for some queries)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_users' AND column_name = 'auth_id') THEN
        ALTER TABLE omtbl_users ADD COLUMN auth_id UUID REFERENCES auth.users(id);
        -- Start by strictly matching existing IDs if they match auth users (optional, usually we just set it on new inserts)
    END IF;

END $$;

-- 3. RLS Helper Function (Security Critical)
-- Allows policies to quickly check "Does this user belong to the row's organization?"
CREATE OR REPLACE FUNCTION get_my_org_id()
RETURNS BIGINT AS $$
  SELECT organization_id FROM omtbl_users WHERE id::text = auth.uid()::text OR auth_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- 4. Apply RLS Policies (Example for Orders - Idempotent)
-- Ensure RLS is enabled
ALTER TABLE omtbl_orders ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'omtbl_orders' AND policyname = 'Tenant Isolation Select') THEN
        CREATE POLICY "Tenant Isolation Select" ON omtbl_orders
        FOR SELECT USING (
          organization_id = get_my_org_id()
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'omtbl_orders' AND policyname = 'Tenant Isolation Modify') THEN
        CREATE POLICY "Tenant Isolation Modify" ON omtbl_orders
        FOR ALL USING (
          organization_id = get_my_org_id()
        );
    END IF;
END $$;

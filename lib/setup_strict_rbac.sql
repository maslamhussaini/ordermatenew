-- ==============================================================================
-- SETUP STRICT RBAC & MULTI-TENANCY
-- ==============================================================================
-- This script applies strict Row Level Security (RLS) to ensure data isolation.
-- Validated against: Cloud Supabase & Local Flutter App Logic.

-- 1. HELPER FUNCTION (To avoid repetitive Joins)
-- Returns the organization_id for the current authenticated user.
CREATE OR REPLACE FUNCTION get_my_org_id()
RETURNS INTEGER AS $$
DECLARE
  org_id INTEGER;
BEGIN
  -- Attempt to get from JWT metadata first (faster)
  org_id := (auth.jwt() ->> 'organization_id')::INTEGER;
  
  -- If not in JWT, look up in public.omtbl_users
  IF org_id IS NULL THEN
    SELECT organization_id INTO org_id
    FROM public.omtbl_users
    WHERE auth_id = auth.uid();
  END IF;
  
  RETURN org_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. HELPER FUNCTION FOR ROLE CHECK
-- Returns the Role Name (e.g. 'Admin') for logic checks.
CREATE OR REPLACE FUNCTION get_my_role_name()
RETURNS TEXT AS $$
DECLARE
  r_name TEXT;
BEGIN
  SELECT r.role_name INTO r_name
  FROM public.omtbl_users u
  JOIN public.omtbl_roles r ON u.role_id = r.id
  WHERE u.auth_id = auth.uid();
  
  RETURN r_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ==============================================================================
-- APPLY RLS POLICIES
-- ==============================================================================

-- A. USER TABLE (The Gateway)
ALTER TABLE omtbl_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own profile" ON omtbl_users;
CREATE POLICY "Users can view own profile" 
ON omtbl_users FOR SELECT 
TO authenticated 
USING (auth_id = auth.uid());

DROP POLICY IF EXISTS "Users can view colleagues in same Org" ON omtbl_users;
CREATE POLICY "Users can view colleagues in same Org" 
ON omtbl_users FOR SELECT 
TO authenticated 
USING (organization_id = get_my_org_id());


-- B. CORE DATA TABLES (Products, Orders, Partners)
-- Pattern: Users can View/Edit data ONLY if it belongs to their Organization.

-- 1. PRODUCTS
ALTER TABLE omtbl_products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Org Isolation: Products" ON omtbl_products;
CREATE POLICY "Org Isolation: Products"
ON omtbl_products FOR ALL
TO authenticated
USING (organization_id = get_my_org_id())
WITH CHECK (organization_id = get_my_org_id());

-- 2. BUSINESS PARTNERS (Customers/Vendors)
ALTER TABLE omtbl_businesspartners ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Org Isolation: Partners" ON omtbl_businesspartners;
CREATE POLICY "Org Isolation: Partners"
ON omtbl_businesspartners FOR ALL
TO authenticated
USING (organization_id = get_my_org_id())
WITH CHECK (organization_id = get_my_org_id());

-- 3. ORDERS
ALTER TABLE omtbl_orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Org Isolation: Orders" ON omtbl_orders;
CREATE POLICY "Org Isolation: Orders"
ON omtbl_orders FOR ALL
TO authenticated
USING (organization_id = get_my_org_id())
WITH CHECK (organization_id = get_my_org_id());

-- 4. STORES
ALTER TABLE omtbl_stores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Org Isolation: Stores" ON omtbl_stores;
CREATE POLICY "Org Isolation: Stores"
ON omtbl_stores FOR ALL
TO authenticated
USING (organization_id = get_my_org_id()); -- Typically users don't create stores, only Admins. 

-- 5. ORGANIZATIONS
ALTER TABLE omtbl_organizations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Org Isolation: Organizations" ON omtbl_organizations;
CREATE POLICY "Org Isolation: Organizations"
ON omtbl_organizations FOR SELECT
TO authenticated
USING (id = get_my_org_id());


-- C. ACCOUNTING TABLES (GL)
-- These need similar isolation.

-- 1. CHART OF ACCOUNTS
ALTER TABLE omtbl_chart_of_accounts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Org Isolation: COA" ON omtbl_chart_of_accounts;
CREATE POLICY "Org Isolation: COA"
ON omtbl_chart_of_accounts FOR ALL
TO authenticated
USING (organization_id = get_my_org_id())
WITH CHECK (organization_id = get_my_org_id());

-- 2. FINANCIAL TRANSACTIONS
ALTER TABLE omtbl_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Org Isolation: Transactions" ON omtbl_transactions;
CREATE POLICY "Org Isolation: Transactions"
ON omtbl_transactions FOR ALL
TO authenticated
USING (organization_id = get_my_org_id())
WITH CHECK (organization_id = get_my_org_id());

-- 3. GL SETUP
ALTER TABLE omtbl_gl_setup ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Org Isolation: GL Setup" ON omtbl_gl_setup;
CREATE POLICY "Org Isolation: GL Setup"
ON omtbl_gl_setup FOR ALL
TO authenticated
USING (organization_id = get_my_org_id())
WITH CHECK (organization_id = get_my_org_id());


-- D. PERMISSION TABLES (Legacy Support)
-- If the app uses these, we must allow access.
-- Usually these are 'System Data' (shared) or 'Org Data'. 
-- Assuming they are System Data (Read Only for most).

DO $$
BEGIN
   IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'omtbl_role_form_privileges') THEN
       ALTER TABLE omtbl_role_form_privileges ENABLE ROW LEVEL SECURITY;
       DROP POLICY IF EXISTS "Read Privileges" ON omtbl_role_form_privileges;
       CREATE POLICY "Read Privileges" ON omtbl_role_form_privileges FOR SELECT TO authenticated USING (true);
   END IF;

   IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'omtbl_app_forms') THEN
       ALTER TABLE omtbl_app_forms ENABLE ROW LEVEL SECURITY;
       DROP POLICY IF EXISTS "Read Forms" ON omtbl_app_forms;
       CREATE POLICY "Read Forms" ON omtbl_app_forms FOR SELECT TO authenticated USING (true);
   END IF;
   
   -- New Role Tables (From previous migration)
   IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'omtbl_roles') THEN
       ALTER TABLE omtbl_roles ENABLE ROW LEVEL SECURITY;
       DROP POLICY IF EXISTS "Read Roles" ON omtbl_roles;
       CREATE POLICY "Read Roles" ON omtbl_roles FOR SELECT TO authenticated USING (true);
   END IF;
   
   IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'omtbl_privileges') THEN
       ALTER TABLE omtbl_privileges ENABLE ROW LEVEL SECURITY;
       DROP POLICY IF EXISTS "Read Privileges Simple" ON omtbl_privileges;
       CREATE POLICY "Read Privileges Simple" ON omtbl_privileges FOR SELECT TO authenticated USING (true);
   END IF;
END $$;


-- E. INVENTORY LOOKUPS (Categories, Brands, etc.)
-- These often have organization_id. If NOT, they are shared system data.
-- Assuming they have org_id based on previous patterns.
-- (If they don't, we should default to 'true' for now to avoid breakage, or check schema).
-- We will assume they ARE Org specific if the column exists, otherwise Public.

DO $$ 
BEGIN
    -- Brands
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_brands' AND column_name = 'organization_id') THEN
        DROP POLICY IF EXISTS "Org Isolation: Brands" ON omtbl_brands;
        CREATE POLICY "Org Isolation: Brands" ON omtbl_brands FOR ALL TO authenticated USING (organization_id = get_my_org_id()) WITH CHECK (organization_id = get_my_org_id());
    ELSE
        -- Fallback if shared
        DROP POLICY IF EXISTS "Shared Brands" ON omtbl_brands;
        CREATE POLICY "Shared Brands" ON omtbl_brands FOR ALL TO authenticated USING (true);
    END IF;

    -- Categories
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_categories' AND column_name = 'organization_id') THEN
        DROP POLICY IF EXISTS "Org Isolation: Categories" ON omtbl_categories;
        CREATE POLICY "Org Isolation: Categories" ON omtbl_categories FOR ALL TO authenticated USING (organization_id = get_my_org_id()) WITH CHECK (organization_id = get_my_org_id());
    ELSE
        DROP POLICY IF EXISTS "Shared Categories" ON omtbl_categories;
        CREATE POLICY "Shared Categories" ON omtbl_categories FOR ALL TO authenticated USING (true);
    END IF;
END $$;


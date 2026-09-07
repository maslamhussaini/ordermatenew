-- ============================================
-- ALTERNATIVE RLS POLICY (More Permissive)
-- ============================================
-- This allows authenticated users to manage privileges for ANY organization
-- Use this ONLY if you're having trouble with the user-organization matching
-- This is less secure but will allow you to save privileges
-- ============================================

-- Drop existing policies
DROP POLICY IF EXISTS "Read Privileges" ON omtbl_role_form_privileges;
DROP POLICY IF EXISTS "Insert Privileges" ON omtbl_role_form_privileges;
DROP POLICY IF EXISTS "Update Privileges" ON omtbl_role_form_privileges;
DROP POLICY IF EXISTS "Delete Privileges" ON omtbl_role_form_privileges;

-- Create permissive policies that allow all authenticated users
CREATE POLICY "Read Privileges" ON omtbl_role_form_privileges 
FOR SELECT TO authenticated 
USING (true);

CREATE POLICY "Insert Privileges" ON omtbl_role_form_privileges 
FOR INSERT TO authenticated 
WITH CHECK (true);

CREATE POLICY "Update Privileges" ON omtbl_role_form_privileges 
FOR UPDATE TO authenticated 
USING (true)
WITH CHECK (true);

CREATE POLICY "Delete Privileges" ON omtbl_role_form_privileges 
FOR DELETE TO authenticated 
USING (true);

-- Same for store access tables
DROP POLICY IF EXISTS "Read Role Store Access" ON omtbl_role_store_access;
DROP POLICY IF EXISTS "Insert Role Store Access" ON omtbl_role_store_access;
DROP POLICY IF EXISTS "Update Role Store Access" ON omtbl_role_store_access;
DROP POLICY IF EXISTS "Delete Role Store Access" ON omtbl_role_store_access;

CREATE POLICY "Read Role Store Access" ON omtbl_role_store_access 
FOR SELECT TO authenticated USING (true);

CREATE POLICY "Insert Role Store Access" ON omtbl_role_store_access 
FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Update Role Store Access" ON omtbl_role_store_access 
FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Delete Role Store Access" ON omtbl_role_store_access 
FOR DELETE TO authenticated USING (true);

DROP POLICY IF EXISTS "Read User Store Access" ON omtbl_user_store_access;
DROP POLICY IF EXISTS "Insert User Store Access" ON omtbl_user_store_access;
DROP POLICY IF EXISTS "Update User Store Access" ON omtbl_user_store_access;
DROP POLICY IF EXISTS "Delete User Store Access" ON omtbl_user_store_access;

CREATE POLICY "Read User Store Access" ON omtbl_user_store_access 
FOR SELECT TO authenticated USING (true);

CREATE POLICY "Insert User Store Access" ON omtbl_user_store_access 
FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Update User Store Access" ON omtbl_user_store_access 
FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Delete User Store Access" ON omtbl_user_store_access 
FOR DELETE TO authenticated USING (true);

-- IMPORTANT: This is a temporary fix!
-- After this works, you should:
-- 1. Ensure all users exist in omtbl_users table
-- 2. Re-run QUICK_FIX_RLS.sql to restore proper organization-scoped security

-- ============================================
-- FIX omtbl_users TABLE STRUCTURE
-- ============================================
-- The issue is that omtbl_users has both 'id' and 'auth_id' columns
-- But RLS policies use auth.uid() which should match the 'id' column
-- ============================================

-- 1. First, let's see the current structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'omtbl_users'
ORDER BY ordinal_position;

-- 2. Check current data
SELECT id, auth_id, email, organization_id
FROM omtbl_users
WHERE auth_id = 'e186e3e2-e6e3-4f5b-8e9d-605a04fa0308'
   OR id = 'e186e3e2-e6e3-4f5b-8e9d-605a04fa0308';

-- 3. If the 'id' column is NOT the auth UUID, we need to fix the RLS policies
-- to use 'auth_id' instead of 'id'

-- OPTION A: Update RLS policies to use auth_id column
DROP POLICY IF EXISTS "Read Privileges" ON omtbl_role_form_privileges;
DROP POLICY IF EXISTS "Insert Privileges" ON omtbl_role_form_privileges;
DROP POLICY IF EXISTS "Update Privileges" ON omtbl_role_form_privileges;
DROP POLICY IF EXISTS "Delete Privileges" ON omtbl_role_form_privileges;

CREATE POLICY "Read Privileges" ON omtbl_role_form_privileges 
FOR SELECT TO authenticated 
USING (organization_id IN (SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()::text));

CREATE POLICY "Insert Privileges" ON omtbl_role_form_privileges 
FOR INSERT TO authenticated 
WITH CHECK (organization_id IN (SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()::text));

CREATE POLICY "Update Privileges" ON omtbl_role_form_privileges 
FOR UPDATE TO authenticated 
USING (organization_id IN (SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()::text))
WITH CHECK (organization_id IN (SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()::text));

CREATE POLICY "Delete Privileges" ON omtbl_role_form_privileges 
FOR DELETE TO authenticated 
USING (organization_id IN (SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()::text));

-- Same for store access tables
DROP POLICY IF EXISTS "Read Role Store Access" ON omtbl_role_store_access;
DROP POLICY IF EXISTS "Insert Role Store Access" ON omtbl_role_store_access;
DROP POLICY IF EXISTS "Update Role Store Access" ON omtbl_role_store_access;
DROP POLICY IF EXISTS "Delete Role Store Access" ON omtbl_role_store_access;

CREATE POLICY "Read Role Store Access" ON omtbl_role_store_access 
FOR SELECT TO authenticated 
USING (EXISTS (SELECT 1 FROM omtbl_users WHERE auth_id = auth.uid()::text AND organization_id = omtbl_role_store_access.organization_id));

CREATE POLICY "Insert Role Store Access" ON omtbl_role_store_access 
FOR INSERT TO authenticated 
WITH CHECK (EXISTS (SELECT 1 FROM omtbl_users WHERE auth_id = auth.uid()::text AND organization_id = omtbl_role_store_access.organization_id));

CREATE POLICY "Update Role Store Access" ON omtbl_role_store_access 
FOR UPDATE TO authenticated 
USING (EXISTS (SELECT 1 FROM omtbl_users WHERE auth_id = auth.uid()::text AND organization_id = omtbl_role_store_access.organization_id))
WITH CHECK (EXISTS (SELECT 1 FROM omtbl_users WHERE auth_id = auth.uid()::text AND organization_id = omtbl_role_store_access.organization_id));

CREATE POLICY "Delete Role Store Access" ON omtbl_role_store_access 
FOR DELETE TO authenticated 
USING (EXISTS (SELECT 1 FROM omtbl_users WHERE auth_id = auth.uid()::text AND organization_id = omtbl_role_store_access.organization_id));

DROP POLICY IF EXISTS "Read User Store Access" ON omtbl_user_store_access;
DROP POLICY IF EXISTS "Insert User Store Access" ON omtbl_user_store_access;
DROP POLICY IF EXISTS "Update User Store Access" ON omtbl_user_store_access;
DROP POLICY IF EXISTS "Delete User Store Access" ON omtbl_user_store_access;

CREATE POLICY "Read User Store Access" ON omtbl_user_store_access 
FOR SELECT TO authenticated 
USING (EXISTS (SELECT 1 FROM omtbl_users WHERE auth_id = auth.uid()::text AND organization_id = omtbl_user_store_access.organization_id));

CREATE POLICY "Insert User Store Access" ON omtbl_user_store_access 
FOR INSERT TO authenticated 
WITH CHECK (EXISTS (SELECT 1 FROM omtbl_users WHERE auth_id = auth.uid()::text AND organization_id = omtbl_user_store_access.organization_id));

CREATE POLICY "Update User Store Access" ON omtbl_user_store_access 
FOR UPDATE TO authenticated 
USING (EXISTS (SELECT 1 FROM omtbl_users WHERE auth_id = auth.uid()::text AND organization_id = omtbl_user_store_access.organization_id))
WITH CHECK (EXISTS (SELECT 1 FROM omtbl_users WHERE auth_id = auth.uid()::text AND organization_id = omtbl_user_store_access.organization_id));

CREATE POLICY "Delete User Store Access" ON omtbl_user_store_access 
FOR DELETE TO authenticated 
USING (EXISTS (SELECT 1 FROM omtbl_users WHERE auth_id = auth.uid()::text AND organization_id = omtbl_user_store_access.organization_id));

-- Done! This uses auth_id column instead of id column

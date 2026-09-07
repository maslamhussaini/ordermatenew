-- ============================================
-- QUICK FIX: RLS Policies for Privilege Management
-- ============================================
-- Copy and paste this ENTIRE script into Supabase SQL Editor and click RUN
-- This will fix the "row violates row-level security policy" error
-- ============================================

-- 1. Fix omtbl_role_form_privileges
ALTER TABLE omtbl_role_form_privileges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Read Privileges" ON omtbl_role_form_privileges;
DROP POLICY IF EXISTS "Insert Privileges" ON omtbl_role_form_privileges;
DROP POLICY IF EXISTS "Update Privileges" ON omtbl_role_form_privileges;
DROP POLICY IF EXISTS "Delete Privileges" ON omtbl_role_form_privileges;

CREATE POLICY "Read Privileges" ON omtbl_role_form_privileges 
FOR SELECT TO authenticated 
USING (organization_id IN (SELECT organization_id FROM omtbl_users WHERE id = auth.uid()));

CREATE POLICY "Insert Privileges" ON omtbl_role_form_privileges 
FOR INSERT TO authenticated 
WITH CHECK (organization_id IN (SELECT organization_id FROM omtbl_users WHERE id = auth.uid()));

CREATE POLICY "Update Privileges" ON omtbl_role_form_privileges 
FOR UPDATE TO authenticated 
USING (organization_id IN (SELECT organization_id FROM omtbl_users WHERE id = auth.uid()))
WITH CHECK (organization_id IN (SELECT organization_id FROM omtbl_users WHERE id = auth.uid()));

CREATE POLICY "Delete Privileges" ON omtbl_role_form_privileges 
FOR DELETE TO authenticated 
USING (organization_id IN (SELECT organization_id FROM omtbl_users WHERE id = auth.uid()));

-- 2. Fix omtbl_role_store_access
ALTER TABLE omtbl_role_store_access ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Read Role Store Access" ON omtbl_role_store_access;
DROP POLICY IF EXISTS "Insert Role Store Access" ON omtbl_role_store_access;
DROP POLICY IF EXISTS "Update Role Store Access" ON omtbl_role_store_access;
DROP POLICY IF EXISTS "Delete Role Store Access" ON omtbl_role_store_access;

CREATE POLICY "Read Role Store Access" ON omtbl_role_store_access 
FOR SELECT TO authenticated 
USING (EXISTS (SELECT 1 FROM omtbl_users WHERE id = auth.uid() AND organization_id = omtbl_role_store_access.organization_id));

CREATE POLICY "Insert Role Store Access" ON omtbl_role_store_access 
FOR INSERT TO authenticated 
WITH CHECK (EXISTS (SELECT 1 FROM omtbl_users WHERE id = auth.uid() AND organization_id = omtbl_role_store_access.organization_id));

CREATE POLICY "Update Role Store Access" ON omtbl_role_store_access 
FOR UPDATE TO authenticated 
USING (EXISTS (SELECT 1 FROM omtbl_users WHERE id = auth.uid() AND organization_id = omtbl_role_store_access.organization_id))
WITH CHECK (EXISTS (SELECT 1 FROM omtbl_users WHERE id = auth.uid() AND organization_id = omtbl_role_store_access.organization_id));

CREATE POLICY "Delete Role Store Access" ON omtbl_role_store_access 
FOR DELETE TO authenticated 
USING (EXISTS (SELECT 1 FROM omtbl_users WHERE id = auth.uid() AND organization_id = omtbl_role_store_access.organization_id));

-- 3. Fix omtbl_user_store_access
ALTER TABLE omtbl_user_store_access ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Read User Store Access" ON omtbl_user_store_access;
DROP POLICY IF EXISTS "Insert User Store Access" ON omtbl_user_store_access;
DROP POLICY IF EXISTS "Update User Store Access" ON omtbl_user_store_access;
DROP POLICY IF EXISTS "Delete User Store Access" ON omtbl_user_store_access;

CREATE POLICY "Read User Store Access" ON omtbl_user_store_access 
FOR SELECT TO authenticated 
USING (EXISTS (SELECT 1 FROM omtbl_users WHERE id = auth.uid() AND organization_id = omtbl_user_store_access.organization_id));

CREATE POLICY "Insert User Store Access" ON omtbl_user_store_access 
FOR INSERT TO authenticated 
WITH CHECK (EXISTS (SELECT 1 FROM omtbl_users WHERE id = auth.uid() AND organization_id = omtbl_user_store_access.organization_id));

CREATE POLICY "Update User Store Access" ON omtbl_user_store_access 
FOR UPDATE TO authenticated 
USING (EXISTS (SELECT 1 FROM omtbl_users WHERE id = auth.uid() AND organization_id = omtbl_user_store_access.organization_id))
WITH CHECK (EXISTS (SELECT 1 FROM omtbl_users WHERE id = auth.uid() AND organization_id = omtbl_user_store_access.organization_id));

CREATE POLICY "Delete User Store Access" ON omtbl_user_store_access 
FOR DELETE TO authenticated 
USING (EXISTS (SELECT 1 FROM omtbl_users WHERE id = auth.uid() AND organization_id = omtbl_user_store_access.organization_id));

-- Done! You should now be able to save privileges without errors.

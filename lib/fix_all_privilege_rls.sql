-- ============================================
-- FIX PRIVILEGE MANAGEMENT RLS POLICIES
-- ============================================
-- This script fixes Row-Level Security policies for privilege management tables
-- Run this in Supabase SQL Editor to allow INSERT, UPDATE, and DELETE operations
-- ============================================

-- ============================================
-- 1. omtbl_role_form_privileges
-- ============================================

ALTER TABLE omtbl_role_form_privileges ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Read Privileges" ON omtbl_role_form_privileges;
DROP POLICY IF EXISTS "Insert Privileges" ON omtbl_role_form_privileges;
DROP POLICY IF EXISTS "Update Privileges" ON omtbl_role_form_privileges;
DROP POLICY IF EXISTS "Delete Privileges" ON omtbl_role_form_privileges;

-- Allow authenticated users to read all privileges for their organization
CREATE POLICY "Read Privileges" 
ON omtbl_role_form_privileges 
FOR SELECT 
TO authenticated 
USING (
  organization_id IN (
    SELECT organization_id 
    FROM omtbl_users 
    WHERE id = auth.uid()
  )
);

-- Allow authenticated users to insert privileges for their organization
CREATE POLICY "Insert Privileges" 
ON omtbl_role_form_privileges 
FOR INSERT 
TO authenticated 
WITH CHECK (
  organization_id IN (
    SELECT organization_id 
    FROM omtbl_users 
    WHERE id = auth.uid()
  )
);

-- Allow authenticated users to update privileges for their organization
CREATE POLICY "Update Privileges" 
ON omtbl_role_form_privileges 
FOR UPDATE 
TO authenticated 
USING (
  organization_id IN (
    SELECT organization_id 
    FROM omtbl_users 
    WHERE id = auth.uid()
  )
)
WITH CHECK (
  organization_id IN (
    SELECT organization_id 
    FROM omtbl_users 
    WHERE id = auth.uid()
  )
);

-- Allow authenticated users to delete privileges for their organization
CREATE POLICY "Delete Privileges" 
ON omtbl_role_form_privileges 
FOR DELETE 
TO authenticated 
USING (
  organization_id IN (
    SELECT organization_id 
    FROM omtbl_users 
    WHERE id = auth.uid()
  )
);

-- ============================================
-- 2. omtbl_role_store_access
-- ============================================

ALTER TABLE omtbl_role_store_access ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Read Role Store Access" ON omtbl_role_store_access;
DROP POLICY IF EXISTS "Insert Role Store Access" ON omtbl_role_store_access;
DROP POLICY IF EXISTS "Update Role Store Access" ON omtbl_role_store_access;
DROP POLICY IF EXISTS "Delete Role Store Access" ON omtbl_role_store_access;

-- Allow authenticated users to read store access for their organization
CREATE POLICY "Read Role Store Access" 
ON omtbl_role_store_access 
FOR SELECT 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 
    FROM omtbl_users 
    WHERE id = auth.uid()
    AND organization_id = omtbl_role_store_access.organization_id
  )
);

-- Allow authenticated users to insert store access for their organization
CREATE POLICY "Insert Role Store Access" 
ON omtbl_role_store_access 
FOR INSERT 
TO authenticated 
WITH CHECK (
  EXISTS (
    SELECT 1 
    FROM omtbl_users 
    WHERE id = auth.uid()
    AND organization_id = omtbl_role_store_access.organization_id
  )
);

-- Allow authenticated users to update store access for their organization
CREATE POLICY "Update Role Store Access" 
ON omtbl_role_store_access 
FOR UPDATE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 
    FROM omtbl_users 
    WHERE id = auth.uid()
    AND organization_id = omtbl_role_store_access.organization_id
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 
    FROM omtbl_users 
    WHERE id = auth.uid()
    AND organization_id = omtbl_role_store_access.organization_id
  )
);

-- Allow authenticated users to delete store access for their organization
CREATE POLICY "Delete Role Store Access" 
ON omtbl_role_store_access 
FOR DELETE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 
    FROM omtbl_users 
    WHERE id = auth.uid()
    AND organization_id = omtbl_role_store_access.organization_id
  )
);

-- ============================================
-- 3. omtbl_user_store_access
-- ============================================

ALTER TABLE omtbl_user_store_access ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Read User Store Access" ON omtbl_user_store_access;
DROP POLICY IF EXISTS "Insert User Store Access" ON omtbl_user_store_access;
DROP POLICY IF EXISTS "Update User Store Access" ON omtbl_user_store_access;
DROP POLICY IF EXISTS "Delete User Store Access" ON omtbl_user_store_access;

-- Allow authenticated users to read store access for their organization
CREATE POLICY "Read User Store Access" 
ON omtbl_user_store_access 
FOR SELECT 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 
    FROM omtbl_users 
    WHERE id = auth.uid()
    AND organization_id = omtbl_user_store_access.organization_id
  )
);

-- Allow authenticated users to insert store access for their organization
CREATE POLICY "Insert User Store Access" 
ON omtbl_user_store_access 
FOR INSERT 
TO authenticated 
WITH CHECK (
  EXISTS (
    SELECT 1 
    FROM omtbl_users 
    WHERE id = auth.uid()
    AND organization_id = omtbl_user_store_access.organization_id
  )
);

-- Allow authenticated users to update store access for their organization
CREATE POLICY "Update User Store Access" 
ON omtbl_user_store_access 
FOR UPDATE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 
    FROM omtbl_users 
    WHERE id = auth.uid()
    AND organization_id = omtbl_user_store_access.organization_id
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 
    FROM omtbl_users 
    WHERE id = auth.uid()
    AND organization_id = omtbl_user_store_access.organization_id
  )
);

-- Allow authenticated users to delete store access for their organization
CREATE POLICY "Delete User Store Access" 
ON omtbl_user_store_access 
FOR DELETE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 
    FROM omtbl_users 
    WHERE id = auth.uid()
    AND organization_id = omtbl_user_store_access.organization_id
  )
);

-- ============================================
-- VERIFICATION QUERIES
-- ============================================
-- Run these to verify the policies were created successfully

-- Check policies on omtbl_role_form_privileges
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'omtbl_role_form_privileges'
ORDER BY policyname;

-- Check policies on omtbl_role_store_access
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'omtbl_role_store_access'
ORDER BY policyname;

-- Check policies on omtbl_user_store_access
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'omtbl_user_store_access'
ORDER BY policyname;

-- Fix RLS policies for store access tables
-- This allows authenticated users to manage store access for roles and users

-- ============================================
-- omtbl_role_store_access
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
-- omtbl_user_store_access
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

-- Fix RLS policies for omtbl_role_form_privileges table
-- This allows authenticated users to insert, update, and delete privilege records

-- Enable RLS if not already enabled
ALTER TABLE omtbl_role_form_privileges ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Read Privileges" ON omtbl_role_form_privileges;
DROP POLICY IF EXISTS "Insert Privileges" ON omtbl_role_form_privileges;
DROP POLICY IF EXISTS "Update Privileges" ON omtbl_role_form_privileges;
DROP POLICY IF EXISTS "Delete Privileges" ON omtbl_role_form_privileges;

-- Create comprehensive RLS policies

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

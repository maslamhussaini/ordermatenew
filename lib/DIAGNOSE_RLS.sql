-- ============================================
-- DIAGNOSTIC: Check User and Organization Data
-- ============================================
-- Run this in Supabase SQL Editor to diagnose the RLS issue
-- ============================================

-- 1. Check current user's auth.uid()
SELECT auth.uid() as current_auth_uid;

-- 2. Check if user exists in omtbl_users and their organization_id
SELECT id, email, organization_id, role 
FROM omtbl_users 
WHERE id = auth.uid();

-- 3. Check existing policies on omtbl_role_form_privileges
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'omtbl_role_form_privileges'
ORDER BY policyname;

-- 4. Test if the policy condition works
SELECT 
  auth.uid() as my_auth_id,
  u.id as user_id,
  u.organization_id as my_org_id,
  (SELECT organization_id FROM omtbl_users WHERE id = auth.uid()) as policy_check
FROM omtbl_users u
WHERE u.id = auth.uid();

-- 5. Try a manual insert test (replace values with your actual data)
-- IMPORTANT: Replace these values before running:
-- - role_id: your actual role ID
-- - form_id: your actual form ID  
-- - organization_id: your organization ID from query #2 above
-- - store_id: your store ID

-- First, let's see what organization_id you should use:
SELECT DISTINCT organization_id 
FROM omtbl_users 
WHERE id = auth.uid();

-- Then try this insert (UNCOMMENT and replace values):
/*
INSERT INTO omtbl_role_form_privileges (
  role_id,
  form_id,
  organization_id,
  store_id,
  can_view,
  can_add,
  can_edit,
  can_delete,
  can_read,
  can_print
) VALUES (
  1,  -- Replace with actual role_id
  1,  -- Replace with actual form_id
  (SELECT organization_id FROM omtbl_users WHERE id = auth.uid()),  -- Uses your org_id
  1,  -- Replace with actual store_id
  true,
  true,
  true,
  true,
  true,
  true
);
*/

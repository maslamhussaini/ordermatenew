-- ============================================
-- CHECK IF USER EXISTS IN omtbl_users
-- ============================================
-- Replace 'YOUR_AUTH_ID' with your actual auth ID
-- ============================================

-- Check if user exists in omtbl_users with your auth ID
SELECT id, email, organization_id, role, created_at
FROM omtbl_users
WHERE id = 'e186e3e2-e6e3-4f5b-8e9d-605a04fa0308';

-- If the above returns NO ROWS, that's your problem!
-- The RLS policy can't find your organization_id because you don't exist in omtbl_users

-- Check if user exists in auth.users (Supabase auth table)
SELECT id, email, created_at
FROM auth.users
WHERE id = 'e186e3e2-e6e3-4f5b-8e9d-605a04fa0308';

-- If user exists in auth.users but NOT in omtbl_users, run this INSERT:
-- (Replace the values with your actual data)

/*
INSERT INTO omtbl_users (
  id,
  email,
  organization_id,
  role,
  full_name,
  created_at,
  updated_at
)
SELECT 
  'e186e3e2-e6e3-4f5b-8e9d-605a04fa0308',
  email,
  1,  -- REPLACE WITH YOUR ACTUAL ORGANIZATION_ID
  'ADMIN',  -- or 'EMPLOYEE' or 'MANAGER'
  raw_user_meta_data->>'full_name',
  now(),
  now()
FROM auth.users
WHERE id = 'e186e3e2-e6e3-4f5b-8e9d-605a04fa0308';
*/

-- After inserting, verify it worked:
SELECT id, email, organization_id, role
FROM omtbl_users
WHERE id = 'e186e3e2-e6e3-4f5b-8e9d-605a04fa0308';

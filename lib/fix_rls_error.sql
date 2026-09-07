-- Enable RLS on the table if not already enabled
ALTER TABLE omtbl_businesspartners ENABLE ROW LEVEL SECURITY;

-- Create a policy that allows all operations for authenticated users
-- Drop existing implementation-specific policies if needed to avoid conflicts or just create a blanket one
DROP POLICY IF EXISTS "Allow all for authenticated" ON omtbl_businesspartners;

CREATE POLICY "Allow all for authenticated"
ON omtbl_businesspartners
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Also ensure states table has policies
ALTER TABLE omtbl_states ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read for authenticated" ON omtbl_states;
CREATE POLICY "Allow read for authenticated"
ON omtbl_states FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow insert for authenticated" ON omtbl_states;
CREATE POLICY "Allow insert for authenticated"
ON omtbl_states FOR INSERT TO authenticated WITH CHECK (true);

-- FIX GL SETUP RLS (Missing in previous setup)
ALTER TABLE omtbl_gl_setup ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON omtbl_gl_setup;
CREATE POLICY "Allow all for authenticated users"
ON omtbl_gl_setup FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Ensure Chart of Accounts is accessible
ALTER TABLE omtbl_chart_of_accounts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON omtbl_chart_of_accounts;
CREATE POLICY "Allow all for authenticated users"
ON omtbl_chart_of_accounts FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Ensure Account Types and Categories are accessible
ALTER TABLE omtbl_account_types ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON omtbl_account_types;
CREATE POLICY "Allow all for authenticated users"
ON omtbl_account_types FOR ALL TO authenticated USING (true) WITH CHECK (true);

ALTER TABLE omtbl_account_categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON omtbl_account_categories;
CREATE POLICY "Allow all for authenticated users"
ON omtbl_account_categories FOR ALL TO authenticated USING (true) WITH CHECK (true);

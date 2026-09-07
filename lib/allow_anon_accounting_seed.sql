-- Allow anon users to have full access to accounting data for onboarding flow
-- Updated with correct table names (omtbl_app_forms)

-- omtbl_account_types
ALTER TABLE omtbl_account_types ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow onboarding insert" ON omtbl_account_types;
DROP POLICY IF EXISTS "Allow onboarding all" ON omtbl_account_types;
CREATE POLICY "Allow onboarding all" ON omtbl_account_types
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- omtbl_account_categories
ALTER TABLE omtbl_account_categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow onboarding insert" ON omtbl_account_categories;
DROP POLICY IF EXISTS "Allow onboarding all" ON omtbl_account_categories;
CREATE POLICY "Allow onboarding all" ON omtbl_account_categories
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- omtbl_chart_of_accounts
ALTER TABLE omtbl_chart_of_accounts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow onboarding insert" ON omtbl_chart_of_accounts;
DROP POLICY IF EXISTS "Allow onboarding all" ON omtbl_chart_of_accounts;
CREATE POLICY "Allow onboarding all" ON omtbl_chart_of_accounts
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- omtbl_gl_setup
ALTER TABLE omtbl_gl_setup ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow onboarding insert" ON omtbl_gl_setup;
DROP POLICY IF EXISTS "Allow onboarding all" ON omtbl_gl_setup;
CREATE POLICY "Allow onboarding all" ON omtbl_gl_setup
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- omtbl_roles
ALTER TABLE omtbl_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow onboarding insert" ON omtbl_roles;
DROP POLICY IF EXISTS "Allow onboarding all" ON omtbl_roles;
CREATE POLICY "Allow onboarding all" ON omtbl_roles
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- omtbl_role_form_privileges
ALTER TABLE omtbl_role_form_privileges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow onboarding insert" ON omtbl_role_form_privileges;
DROP POLICY IF EXISTS "Allow onboarding all" ON omtbl_role_form_privileges;
CREATE POLICY "Allow onboarding all" ON omtbl_role_form_privileges
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- omtbl_app_forms
-- Need select permission for anon
ALTER TABLE omtbl_app_forms ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow onboarding select" ON omtbl_app_forms;
CREATE POLICY "Allow onboarding select" ON omtbl_app_forms
FOR SELECT
TO anon, authenticated
USING (true);

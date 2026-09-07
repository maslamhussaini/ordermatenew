-- Enable RLS on organizations and add policies for auth_user_id
ALTER TABLE omtbl_organizations ENABLE ROW LEVEL SECURITY;

-- Allow reading organizations where the user is the owner (auth_user_id)
DROP POLICY IF EXISTS "Users can select own organizations" ON omtbl_organizations;
CREATE POLICY "Users can select own organizations" ON omtbl_organizations
    FOR SELECT
    USING (auth.uid() = auth_user_id);

-- Allow reading organization that user belongs to
DROP POLICY IF EXISTS "Users can select assigned organization" ON omtbl_organizations;
CREATE POLICY "Users can select assigned organization" ON omtbl_organizations
    FOR SELECT
    USING (
        id IN (
            SELECT organization_id 
            FROM omtbl_users 
            WHERE auth_id = auth.uid()
        )
    );

-- Allow inserting if user is authenticated (for creating new orgs)
DROP POLICY IF EXISTS "Users can insert organizations" ON omtbl_organizations;
CREATE POLICY "Users can insert organizations" ON omtbl_organizations
    FOR INSERT
    WITH CHECK (auth.uid() = auth_user_id);

-- Allow updating own organizations
DROP POLICY IF EXISTS "Users can update own organizations" ON omtbl_organizations;
CREATE POLICY "Users can update own organizations" ON omtbl_organizations
    FOR UPDATE
    USING (auth.uid() = auth_user_id);

-- Make sure Super Users can see everything (optional, based on role implementation)
-- If you use role-based RLS, you'd add that here.
-- For now, ownership and assignment cover the basics.

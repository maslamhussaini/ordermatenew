-- Enable RLS on financial sessions and add policies for user access
ALTER TABLE omtbl_financial_sessions ENABLE ROW LEVEL SECURITY;

-- Allow reading financial sessions for organizations the user belongs to
DROP POLICY IF EXISTS "Users can select financial sessions for their organizations" ON omtbl_financial_sessions;
CREATE POLICY "Users can select financial sessions for their organizations" ON omtbl_financial_sessions
    FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM omtbl_users 
            WHERE auth_id = auth.uid()
        )
        OR
        organization_id IN (
            SELECT id 
            FROM omtbl_organizations 
            WHERE auth_user_id = auth.uid()
        )
    );

-- Allow inserting financial sessions for organizations the user owns or belongs to
DROP POLICY IF EXISTS "Users can insert financial sessions" ON omtbl_financial_sessions;
CREATE POLICY "Users can insert financial sessions" ON omtbl_financial_sessions
    FOR INSERT
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM omtbl_users 
            WHERE auth_id = auth.uid()
        )
        OR
        organization_id IN (
            SELECT id 
            FROM omtbl_organizations 
            WHERE auth_user_id = auth.uid()
        )
    );

-- Allow updating financial sessions for organizations the user owns or belongs to
DROP POLICY IF EXISTS "Users can update financial sessions" ON omtbl_financial_sessions;
CREATE POLICY "Users can update financial sessions" ON omtbl_financial_sessions
    FOR UPDATE
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM omtbl_users 
            WHERE auth_id = auth.uid()
        )
        OR
        organization_id IN (
            SELECT id 
            FROM omtbl_organizations 
            WHERE auth_user_id = auth.uid()
        )
    );

-- Allow deleting financial sessions for organizations the user owns
DROP POLICY IF EXISTS "Users can delete financial sessions" ON omtbl_financial_sessions;
CREATE POLICY "Users can delete financial sessions" ON omtbl_financial_sessions
    FOR DELETE
    USING (
        organization_id IN (
            SELECT id 
            FROM omtbl_organizations 
            WHERE auth_user_id = auth.uid()
        )
    );

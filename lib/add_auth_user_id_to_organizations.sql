-- Add auth_user_id to omtbl_organizations to track the owner/creator
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_organizations' AND column_name = 'auth_user_id') THEN
        ALTER TABLE omtbl_organizations ADD COLUMN auth_user_id uuid REFERENCES auth.users(id);
    END IF;
END $$;

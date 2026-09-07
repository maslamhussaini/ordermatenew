-- Fix the foreign key constraint to ensure it points to auth.users
DO $$
BEGIN
    -- 1. Drop the constraint if it exists (to be safe and recreate it correctly)
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'omtbl_organizations_auth_user_id_fkey') THEN
        ALTER TABLE omtbl_organizations DROP CONSTRAINT omtbl_organizations_auth_user_id_fkey;
    END IF;

    -- 2. Add the constraint explicitly referencing auth.users
    -- We use ON DELETE SET NULL or CASCADE depending on preference. SET NULL is safer for organization history.
    ALTER TABLE omtbl_organizations 
    ADD CONSTRAINT omtbl_organizations_auth_user_id_fkey 
    FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

END $$;

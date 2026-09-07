-- update_financial_sessions_schema.sql
-- Run this script to update the Financial Sessions table to use a UUID primary key
-- and allow multiple organizations to have sessions for the same year.

-- 1. Drop the existing primary key constraint (which is likely on syear)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'omtbl_financial_sessions_pkey') THEN
        ALTER TABLE omtbl_financial_sessions DROP CONSTRAINT omtbl_financial_sessions_pkey;
    END IF;
END $$;

-- 2. Add a new 'id' column of type UUID if it doesn't represent
ALTER TABLE omtbl_financial_sessions ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();

-- 3. Populate existing rows with a UUID if (though default should handle it for new rows, we ensure existing nulls are filled if any)
UPDATE omtbl_financial_sessions SET id = gen_random_uuid() WHERE id IS NULL;

-- 4. Make the new 'id' column the PRIMARY KEY
ALTER TABLE omtbl_financial_sessions ADD PRIMARY KEY (id);

-- 5. Add a unique constraint on (organization_id, syear) to prevent duplicate years for the SAME organization
-- First, ensure no duplicates exist before adding constraint
-- (Optional cleanup step, but assuming data is currently valid per org)
ALTER TABLE omtbl_financial_sessions ADD CONSTRAINT unique_org_year UNIQUE (organization_id, syear);

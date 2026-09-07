-- Link Products to Business Partners instead of Vendors (which is deprecated)
DO $$
BEGIN
    -- 1. Drop the old foreign key to omtbl_vendors if it exists
    -- We try to guess the constraint name. Standard postgres naming is table_column_fkey
    BEGIN
        ALTER TABLE omtbl_products DROP CONSTRAINT IF EXISTS omtbl_products_vendor_id_fkey;
    EXCEPTION WHEN undefined_object THEN
        -- Link might confirm it doesn't exist
    END;

    -- 2. Add new foreign key to omtbl_businesspartners
    -- We first ensure the constraint doesn't already exist to avoid errors
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_products_business_partner'
    ) THEN
        ALTER TABLE omtbl_products 
        ADD CONSTRAINT fk_products_business_partner 
        FOREIGN KEY (business_partner_id) REFERENCES omtbl_businesspartners(id);
    END IF;
END $$;

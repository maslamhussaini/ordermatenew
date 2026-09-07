DO $$
BEGIN
    -- 1. Organizations
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_organizations' AND column_name = 'created_by') THEN
        ALTER TABLE omtbl_organizations ADD COLUMN created_by uuid REFERENCES auth.users(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_organizations' AND column_name = 'updated_by') THEN
        ALTER TABLE omtbl_organizations ADD COLUMN updated_by uuid REFERENCES auth.users(id);
    END IF;

    -- 2. Stores
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_stores' AND column_name = 'created_by') THEN
        ALTER TABLE omtbl_stores ADD COLUMN created_by uuid REFERENCES auth.users(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_stores' AND column_name = 'updated_by') THEN
        ALTER TABLE omtbl_stores ADD COLUMN updated_by uuid REFERENCES auth.users(id);
    END IF;

    -- 3. Roles
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_roles' AND column_name = 'updated_at') THEN
        ALTER TABLE omtbl_roles ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_roles' AND column_name = 'created_by') THEN
        ALTER TABLE omtbl_roles ADD COLUMN created_by uuid REFERENCES auth.users(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_roles' AND column_name = 'updated_by') THEN
        ALTER TABLE omtbl_roles ADD COLUMN updated_by uuid REFERENCES auth.users(id);
    END IF;

    -- 4. Business Partners (Check created_by)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_businesspartners' AND column_name = 'created_by') THEN
        ALTER TABLE omtbl_businesspartners ADD COLUMN created_by uuid REFERENCES auth.users(id);
    END IF;
    -- updated_by was added in previous migration but no harm checking
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_businesspartners' AND column_name = 'updated_by') THEN
        ALTER TABLE omtbl_businesspartners ADD COLUMN updated_by uuid REFERENCES auth.users(id);
    END IF;
    
    -- 5. Orders (Check created_by)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_orders' AND column_name = 'created_by') THEN
        ALTER TABLE omtbl_orders ADD COLUMN created_by uuid REFERENCES auth.users(id);
    END IF;

    -- 6. Inventory Lookups (Brands, Categories, ProductTypes)
    -- Brands
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_brands' AND column_name = 'created_by') THEN
        ALTER TABLE omtbl_brands ADD COLUMN created_by uuid REFERENCES auth.users(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_brands' AND column_name = 'updated_by') THEN
        ALTER TABLE omtbl_brands ADD COLUMN updated_by uuid REFERENCES auth.users(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_brands' AND column_name = 'updated_at') THEN
        ALTER TABLE omtbl_brands ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());
    END IF;

    -- Categories
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_categories' AND column_name = 'created_by') THEN
        ALTER TABLE omtbl_categories ADD COLUMN created_by uuid REFERENCES auth.users(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_categories' AND column_name = 'updated_by') THEN
        ALTER TABLE omtbl_categories ADD COLUMN updated_by uuid REFERENCES auth.users(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_categories' AND column_name = 'updated_at') THEN
        ALTER TABLE omtbl_categories ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());
    END IF;

    -- Product Types
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_producttypes' AND column_name = 'created_by') THEN
        ALTER TABLE omtbl_producttypes ADD COLUMN created_by uuid REFERENCES auth.users(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_producttypes' AND column_name = 'updated_by') THEN
        ALTER TABLE omtbl_producttypes ADD COLUMN updated_by uuid REFERENCES auth.users(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_producttypes' AND column_name = 'updated_at') THEN
        ALTER TABLE omtbl_producttypes ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());
    END IF;

    -- 7. Geographic Lookups (Cities, States, Countries) - and Business Types
    -- Business Types
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_business_types' AND column_name = 'created_at') THEN
        ALTER TABLE omtbl_business_types ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_business_types' AND column_name = 'updated_at') THEN
        ALTER TABLE omtbl_business_types ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_business_types' AND column_name = 'created_by') THEN
        ALTER TABLE omtbl_business_types ADD COLUMN created_by uuid REFERENCES auth.users(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_business_types' AND column_name = 'updated_by') THEN
        ALTER TABLE omtbl_business_types ADD COLUMN updated_by uuid REFERENCES auth.users(id);
    END IF;

    -- Cities
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_cities' AND column_name = 'created_at') THEN
        ALTER TABLE omtbl_cities ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_cities' AND column_name = 'updated_at') THEN
        ALTER TABLE omtbl_cities ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_cities' AND column_name = 'created_by') THEN
        ALTER TABLE omtbl_cities ADD COLUMN created_by uuid REFERENCES auth.users(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_cities' AND column_name = 'updated_by') THEN
        ALTER TABLE omtbl_cities ADD COLUMN updated_by uuid REFERENCES auth.users(id);
    END IF;
    
    -- States
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_states' AND column_name = 'created_at') THEN
        ALTER TABLE omtbl_states ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_states' AND column_name = 'updated_at') THEN
        ALTER TABLE omtbl_states ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_states' AND column_name = 'created_by') THEN
        ALTER TABLE omtbl_states ADD COLUMN created_by uuid REFERENCES auth.users(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_states' AND column_name = 'updated_by') THEN
        ALTER TABLE omtbl_states ADD COLUMN updated_by uuid REFERENCES auth.users(id);
    END IF;

    -- Countries
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_countries' AND column_name = 'created_at') THEN
        ALTER TABLE omtbl_countries ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_countries' AND column_name = 'updated_at') THEN
        ALTER TABLE omtbl_countries ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_countries' AND column_name = 'created_by') THEN
        ALTER TABLE omtbl_countries ADD COLUMN created_by uuid REFERENCES auth.users(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_countries' AND column_name = 'updated_by') THEN
        ALTER TABLE omtbl_countries ADD COLUMN updated_by uuid REFERENCES auth.users(id);
    END IF;

END $$;

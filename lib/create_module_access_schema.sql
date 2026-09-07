-- create_module_access_schema.sql

-- 1. Create Module Access table (Links Organizations to Modules)
-- Defines which modules are active for an organization
CREATE TABLE IF NOT EXISTS omtbl_module_access (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    organization_id INT REFERENCES omtbl_organizations(id) ON DELETE CASCADE,
    module_id UUID REFERENCES omtbl_modules(id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT unique_org_module UNIQUE (organization_id, module_id)
);

-- 2. Create Module Access Items table (Links Forms to Modules PER ORGANIZATION)
-- Defines which forms are enabled for an organization within a module
CREATE TABLE IF NOT EXISTS omtbl_module_access_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    organization_id INT REFERENCES omtbl_organizations(id) ON DELETE CASCADE, -- Added to allow per-org configuration
    form_id INT REFERENCES omtbl_app_forms(id) ON DELETE CASCADE,
    module_id UUID REFERENCES omtbl_modules(id) ON DELETE CASCADE,
    
    is_enabled BOOLEAN DEFAULT false,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_form_module_org UNIQUE (form_id, module_id, organization_id)
);

-- 3. Safety Alter (in case table exists without necessary columns)
DO $$ 
BEGIN 
    -- Check is_enabled
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'omtbl_module_access_items') AND
       NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_module_access_items' AND column_name = 'is_enabled') THEN
        ALTER TABLE omtbl_module_access_items ADD COLUMN is_enabled BOOLEAN DEFAULT false;
    END IF;

    -- Check organization_id
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'omtbl_module_access_items') AND
       NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_module_access_items' AND column_name = 'organization_id') THEN
        ALTER TABLE omtbl_module_access_items ADD COLUMN organization_id INT REFERENCES omtbl_organizations(id) ON DELETE CASCADE;
        
        -- Drop old constraint if exists and add new one
        ALTER TABLE omtbl_module_access_items DROP CONSTRAINT IF EXISTS unique_form_module;
        ALTER TABLE omtbl_module_access_items ADD CONSTRAINT unique_form_module_org UNIQUE (form_id, module_id, organization_id);
    END IF;
END $$;

-- Add missing audit fields if they don't exist
DO $$
BEGIN
    -- For omtbl_businesspartners
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_businesspartners' AND column_name = 'updated_by') THEN
        ALTER TABLE omtbl_businesspartners ADD COLUMN updated_by uuid;
    END IF;

    -- For omtbl_orders
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_orders' AND column_name = 'updated_by') THEN
        ALTER TABLE omtbl_orders ADD COLUMN updated_by uuid;
    END IF;

    -- For omtbl_products
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_products' AND column_name = 'created_by') THEN
        ALTER TABLE omtbl_products ADD COLUMN created_by uuid;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_products' AND column_name = 'updated_by') THEN
        ALTER TABLE omtbl_products ADD COLUMN updated_by uuid;
    END IF;
END $$;

-- 0. Fix Legacy Schema Column Names (if they exist)
DO $$
BEGIN
    -- Fix omtbl_organizations
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_organizations' AND column_name = 'idOrz') THEN
        ALTER TABLE omtbl_organizations RENAME COLUMN "idOrz" TO "id";
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_organizations' AND column_name = 'orzName') THEN
         ALTER TABLE omtbl_organizations RENAME COLUMN "orzName" TO "name";
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_organizations' AND column_name = 'orzActive') THEN
         ALTER TABLE omtbl_organizations RENAME COLUMN "orzActive" TO "is_active";
    END IF;

    -- Fix omtbl_stores
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_stores' AND column_name = 'id_store') THEN
        ALTER TABLE omtbl_stores RENAME COLUMN "id_store" TO "id";
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_stores' AND column_name = 'orz_id') THEN
        ALTER TABLE omtbl_stores RENAME COLUMN "orz_id" TO "organization_id";
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_stores' AND column_name = 'storeName') THEN
        ALTER TABLE omtbl_stores RENAME COLUMN "storeName" TO "name";
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_stores' AND column_name = 'storeAddress') THEN
        ALTER TABLE omtbl_stores RENAME COLUMN "storeAddress" TO "location";
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_stores' AND column_name = 'active') THEN
        ALTER TABLE omtbl_stores RENAME COLUMN "active" TO "is_active";
    END IF;
END $$;

-- 1. Create Organization Table
CREATE TABLE IF NOT EXISTS omtbl_organizations (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    code TEXT UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    is_active BOOLEAN DEFAULT true
);

-- 2. Create Store Table
CREATE TABLE IF NOT EXISTS omtbl_stores (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES omtbl_organizations(id),
    name TEXT NOT NULL,
    location TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    is_active BOOLEAN DEFAULT true
);

-- 3. Create Roles Table
CREATE TABLE IF NOT EXISTS omtbl_roles (
    id SERIAL PRIMARY KEY,
    role_name TEXT UNIQUE NOT NULL, -- Super User, Admin, Manager, Booker
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Create Privileges Table
CREATE TABLE IF NOT EXISTS omtbl_privileges (
    id SERIAL PRIMARY KEY,
    key TEXT UNIQUE NOT NULL, -- e.g., 'create_order', 'view_all_sales'
    description TEXT
);

-- 5. Role-Privileges Mapping
CREATE TABLE IF NOT EXISTS omtbl_role_privileges (
    role_id INTEGER REFERENCES omtbl_roles(id) ON DELETE CASCADE,
    privilege_id INTEGER REFERENCES omtbl_privileges(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, privilege_id)
);

-- 6. Add OrzID and StoreID to main tables
DO $$
BEGIN
    -- Customers (Business Partners)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_businesspartners' AND column_name = 'organization_id') THEN
        ALTER TABLE omtbl_businesspartners ADD COLUMN organization_id INTEGER REFERENCES omtbl_organizations(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_businesspartners' AND column_name = 'store_id') THEN
        ALTER TABLE omtbl_businesspartners ADD COLUMN store_id INTEGER REFERENCES omtbl_stores(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_businesspartners' AND column_name = 'manager_id') THEN
        ALTER TABLE omtbl_businesspartners ADD COLUMN manager_id uuid REFERENCES omtbl_businesspartners(id); -- Self Join
    END IF;
     IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_businesspartners' AND column_name = 'role_id') THEN
        ALTER TABLE omtbl_businesspartners ADD COLUMN role_id INTEGER REFERENCES omtbl_roles(id);
    END IF;

    -- Orders
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_orders' AND column_name = 'organization_id') THEN
        ALTER TABLE omtbl_orders ADD COLUMN organization_id INTEGER REFERENCES omtbl_organizations(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_orders' AND column_name = 'store_id') THEN
        ALTER TABLE omtbl_orders ADD COLUMN store_id INTEGER REFERENCES omtbl_stores(id);
    END IF;

    -- Products
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_products' AND column_name = 'organization_id') THEN
        ALTER TABLE omtbl_products ADD COLUMN organization_id INTEGER REFERENCES omtbl_organizations(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_products' AND column_name = 'store_id') THEN
        ALTER TABLE omtbl_products ADD COLUMN store_id INTEGER REFERENCES omtbl_stores(id);
    END IF;

    -- Users (omtbl_users)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_users' AND column_name = 'organization_id') THEN
        ALTER TABLE omtbl_users ADD COLUMN organization_id INTEGER REFERENCES omtbl_organizations(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_users' AND column_name = 'store_id') THEN
        ALTER TABLE omtbl_users ADD COLUMN store_id INTEGER REFERENCES omtbl_stores(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_users' AND column_name = 'role_id') THEN
        ALTER TABLE omtbl_users ADD COLUMN role_id INTEGER REFERENCES omtbl_roles(id);
    END IF;
END $$;

-- 7. Seed Initial Roles
INSERT INTO omtbl_roles (role_name, description) VALUES
('Super User', 'Full access to organization'),
('Admin', 'Administrative access'),
('Manager', 'Can view their sales persons'),
('Booker', 'Can only book orders and create customers')
ON CONFLICT (role_name) DO NOTHING;

-- 8. Seed Default Organization/Store (to handle legacy data)
-- Insert a default org and store if empty, so we can update existing nulls
WITH new_org AS (
    INSERT INTO omtbl_organizations (name, code)
    SELECT 'Default Org', 'DEF001'
    WHERE NOT EXISTS (SELECT 1 FROM omtbl_organizations)
    RETURNING id
)
SELECT id FROM new_org;

-- Only insert store if org exists (which it should now)
INSERT INTO omtbl_stores (organization_id, name, location)
SELECT id, 'Main Store', 'HQ'
FROM omtbl_organizations
WHERE name = 'Default Org'
AND NOT EXISTS (SELECT 1 FROM omtbl_stores WHERE name = 'Main Store');

-- 9. Update existing records with default Org/Store
DO $$
DECLARE
    default_org_id INTEGER;
    default_store_id INTEGER;
BEGIN
    SELECT id INTO default_org_id FROM omtbl_organizations WHERE name = 'Default Org' LIMIT 1;
    SELECT id INTO default_store_id FROM omtbl_stores WHERE name = 'Main Store' LIMIT 1;

    IF default_org_id IS NOT NULL THEN
        UPDATE omtbl_businesspartners SET organization_id = default_org_id WHERE organization_id IS NULL;
        UPDATE omtbl_orders SET organization_id = default_org_id WHERE organization_id IS NULL;
        UPDATE omtbl_products SET organization_id = default_org_id WHERE organization_id IS NULL;
    END IF;

    IF default_store_id IS NOT NULL THEN
         UPDATE omtbl_businesspartners SET store_id = default_store_id WHERE store_id IS NULL;
         UPDATE omtbl_orders SET store_id = default_store_id WHERE store_id IS NULL;
         UPDATE omtbl_products SET store_id = default_store_id WHERE store_id IS NULL;
    END IF;
END $$;

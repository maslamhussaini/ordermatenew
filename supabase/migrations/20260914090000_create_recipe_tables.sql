-- Recipe / Composite Product feature
-- Adds product recipe (BOM), daily bulk counter sale, and wastage support.
-- Uses the same inline-org-id RLS pattern as omtbl_inventory_movements.

-- 1. Seed product type "Recipe" once per organization
INSERT INTO omtbl_producttypes (producttype, status, organization_id, created_at)
SELECT 'Recipe', 1, id, NOW()
FROM omtbl_organizations
WHERE NOT EXISTS (
  SELECT 1 FROM omtbl_producttypes WHERE producttype = 'Recipe'
);

-- 2. Recipe ingredients (BOM lines)
CREATE TABLE IF NOT EXISTS omtbl_product_recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES omtbl_products(id),
    component_product_id UUID NOT NULL REFERENCES omtbl_products(id),
    quantity DECIMAL(15,4) NOT NULL,
    uom_id INTEGER NOT NULL REFERENCES omtbl_units_of_measure(id),
    wastage_percent DECIMAL(5,2) DEFAULT 0,
    organization_id BIGINT NOT NULL REFERENCES omtbl_organizations(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_product_recipes_product
    ON omtbl_product_recipes (product_id);

-- 3. Daily bulk counter sale header
CREATE TABLE IF NOT EXISTS omtbl_recipe_sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id BIGINT NOT NULL REFERENCES omtbl_organizations(id),
    store_id BIGINT NOT NULL REFERENCES omtbl_stores(id),
    sale_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    total_cost DECIMAL(15,2) NOT NULL DEFAULT 0,
    total_profit DECIMAL(15,2) NOT NULL DEFAULT 0,
    created_by UUID REFERENCES omtbl_users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recipe_sales_org_date
    ON omtbl_recipe_sales (organization_id, sale_date);

-- 4. Daily bulk counter sale lines
CREATE TABLE IF NOT EXISTS omtbl_recipe_sale_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_sale_id UUID NOT NULL REFERENCES omtbl_recipe_sales(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES omtbl_products(id),
    quantity_sold DECIMAL(15,4) NOT NULL,
    rate DECIMAL(15,2) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    cost DECIMAL(15,2) NOT NULL,
    profit DECIMAL(15,2) NOT NULL,
    wastage_qty DECIMAL(15,4) DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_recipe_sale_items_sale
    ON omtbl_recipe_sale_items (recipe_sale_id);

-- 5. RLS for recipe tables
ALTER TABLE omtbl_product_recipes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view recipes in their organization"
    ON omtbl_product_recipes FOR SELECT USING (
        organization_id IN (
            SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()
        )
    );

CREATE POLICY "Users can create recipes in their organization"
    ON omtbl_product_recipes FOR INSERT WITH CHECK (
        organization_id IN (
            SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()
        )
    );

CREATE POLICY "Users can update recipes in their organization"
    ON omtbl_product_recipes FOR UPDATE USING (
        organization_id IN (
            SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete recipes in their organization"
    ON omtbl_product_recipes FOR DELETE USING (
        organization_id IN (
            SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()
        )
    );

ALTER TABLE omtbl_recipe_sales ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view recipe sales in their organization"
    ON omtbl_recipe_sales FOR SELECT USING (
        organization_id IN (
            SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()
        )
    );

CREATE POLICY "Users can create recipe sales in their organization"
    ON omtbl_recipe_sales FOR INSERT WITH CHECK (
        organization_id IN (
            SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()
        )
    );

ALTER TABLE omtbl_recipe_sale_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view recipe sale items in their organization"
    ON omtbl_recipe_sale_items FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM omtbl_recipe_sales rs
            WHERE rs.id = recipe_sale_id
              AND rs.organization_id IN (
                  SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()
              )
        )
    );

CREATE POLICY "Users can create recipe sale items in their organization"
    ON omtbl_recipe_sale_items FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM omtbl_recipe_sales rs
            WHERE rs.id = recipe_sale_id
              AND rs.organization_id IN (
                  SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()
              )
        )
    );

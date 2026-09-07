CREATE TABLE IF NOT EXISTS omtbl_inventory_movements (
    id BIGSERIAL PRIMARY KEY,
    organization_id BIGINT NOT NULL REFERENCES omtbl_organizations(id),
    product_id UUID NOT NULL REFERENCES omtbl_products(id),
    store_id BIGINT NOT NULL REFERENCES omtbl_stores(id),
    movement_type TEXT NOT NULL,
    quantity DECIMAL(15, 4) NOT NULL,
    reference_table TEXT,
    reference_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inventory_movements_org_product_store
    ON omtbl_inventory_movements (organization_id, product_id, store_id);

CREATE INDEX IF NOT EXISTS idx_inventory_movements_reference
    ON omtbl_inventory_movements (reference_table, reference_id);

ALTER TABLE omtbl_inventory_movements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view movements in their organization"
    ON omtbl_inventory_movements FOR SELECT USING (
        organization_id IN (
            SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()
        )
    );

CREATE POLICY "Users can create movements in their organization"
    ON omtbl_inventory_movements FOR INSERT WITH CHECK (
        organization_id IN (
            SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()
        )
    );

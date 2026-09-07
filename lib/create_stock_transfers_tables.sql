-- Create Stock Transfers Tables
CREATE TABLE IF NOT EXISTS omtbl_stock_transfers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transfer_number TEXT NOT NULL,
    source_store_id BIGINT REFERENCES omtbl_stores(id),
    destination_store_id BIGINT REFERENCES omtbl_stores(id),
    status TEXT NOT NULL, -- Draft, Pending, Completed, Cancelled
    transfer_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES omtbl_users(id),
    driver_name TEXT,
    vehicle_number TEXT,
    remarks TEXT,
    organization_id BIGINT REFERENCES omtbl_organizations(id),
    s_year INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS omtbl_stock_transfer_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transfer_id UUID REFERENCES omtbl_stock_transfers(id) ON DELETE CASCADE,
    product_id UUID REFERENCES omtbl_products(id),
    quantity DECIMAL(15, 4) NOT NULL,
    uom_id BIGINT REFERENCES omtbl_uoms(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE omtbl_stock_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE omtbl_stock_transfer_items ENABLE ROW LEVEL SECURITY;

-- Policies for omtbl_stock_transfers
CREATE POLICY "Users can view transfers in their organization" ON omtbl_stock_transfers
    FOR SELECT USING (organization_id IN (
        SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()
    ));

CREATE POLICY "Users can create transfers in their organization" ON omtbl_stock_transfers
    FOR INSERT WITH CHECK (organization_id IN (
        SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()
    ));

CREATE POLICY "Users can update transfers in their organization" ON omtbl_stock_transfers
    FOR UPDATE USING (organization_id IN (
        SELECT organization_id FROM omtbl_users WHERE auth_id = auth.uid()
    ));

-- Policies for omtbl_stock_transfer_items
CREATE POLICY "Users can view transfer items" ON omtbl_stock_transfer_items
    FOR SELECT USING (transfer_id IN (
        SELECT id FROM omtbl_stock_transfers
    ));

CREATE POLICY "Users can add transfer items" ON omtbl_stock_transfer_items
    FOR INSERT WITH CHECK (transfer_id IN (
        SELECT id FROM omtbl_stock_transfers
    ));

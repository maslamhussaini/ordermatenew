-- Rename customer_id to business_partner_id
ALTER TABLE omtbl_orders RENAME COLUMN customer_id TO business_partner_id;

-- Add order_type column, defaulting to 'SO' (Sales Order)
ALTER TABLE omtbl_orders ADD COLUMN order_type TEXT DEFAULT 'SO';

-- Alter status to default to 'Booked'
ALTER TABLE omtbl_orders ALTER COLUMN status SET DEFAULT 'Booked';

-- Optional: Add check constraint for order_type
ALTER TABLE omtbl_orders ADD CONSTRAINT check_order_type CHECK (order_type IN ('SO', 'PO'));

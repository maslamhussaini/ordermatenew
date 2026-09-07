-- Rename vendor_id to business_partner_id in omtbl_products
ALTER TABLE omtbl_products 
RENAME COLUMN vendor_id TO business_partner_id;

-- If there was a foreign key constraint explicitly named, it might need renaming too, 
-- but usually Postgres handles the column rename in the constraint automatically or preserves the constraint.
-- However, good to document.

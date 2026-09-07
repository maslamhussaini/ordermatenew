-- 1. Soft-fix orphaned records: Set business_partner_id to NULL for products where the business_partner doesn't exist in businesspartners
UPDATE omtbl_products
SET business_partner_id = NULL
WHERE business_partner_id IS NOT NULL 
AND business_partner_id NOT IN (SELECT id FROM omtbl_businesspartners);

-- 2. Now it is safe to add the constraint
ALTER TABLE omtbl_products 
DROP CONSTRAINT IF EXISTS fk_products_business_partner;

ALTER TABLE omtbl_products 
ADD CONSTRAINT fk_products_business_partner 
FOREIGN KEY (business_partner_id) REFERENCES omtbl_businesspartners(id);

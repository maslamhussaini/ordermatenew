-- create_modules_schema.sql

-- 1. Create the Modules table
CREATE TABLE IF NOT EXISTS omtbl_modules (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Insert the required modules
INSERT INTO omtbl_modules (name) VALUES 
('GLAccounts'),
('BankCash'),
('Customers'),
('Vendors'),
('Inventory'),
('HRMS'),
('Admin')
ON CONFLICT (name) DO NOTHING;

-- 3. Add module_id foreign key to omtbl_app_forms
ALTER TABLE omtbl_app_forms 
ADD COLUMN IF NOT EXISTS module_id UUID REFERENCES omtbl_modules(id);

-- 4. Update omtbl_app_forms to link to the new modules based on form names
-- This is a best-effort mapping based on common naming conventions.

-- GLAccounts
UPDATE omtbl_app_forms 
SET module_id = (SELECT id FROM omtbl_modules WHERE name = 'GLAccounts')
WHERE module_id IS NULL 
AND (
    form_name ILIKE '%Account%' 
    OR form_name ILIKE '%Journal%' 
    OR form_name ILIKE '%Voucher%'
    OR form_name ILIKE '%Ledger%'
    OR form_name ILIKE '%Financial%'
    OR form_name ILIKE '%Tax%'
    OR form_name ILIKE '%Fiscal%'
)
AND form_name NOT ILIKE '%Bank%' 
AND form_name NOT ILIKE '%Cash%';

-- BankCash
UPDATE omtbl_app_forms 
SET module_id = (SELECT id FROM omtbl_modules WHERE name = 'BankCash')
WHERE module_id IS NULL 
AND (
    form_name ILIKE '%Bank%' 
    OR form_name ILIKE '%Cash%'
    OR form_name ILIKE '%Cheque%'
    OR form_name ILIKE '%Deposit%'
    OR form_name ILIKE '%Withdrawal%'
);

-- Customers (Sales)
UPDATE omtbl_app_forms 
SET module_id = (SELECT id FROM omtbl_modules WHERE name = 'Customers')
WHERE module_id IS NULL 
AND (
    form_name ILIKE '%Customer%' 
    OR form_name ILIKE '%Sale%' 
    OR form_name ILIKE '%Invoice%'
    OR form_name ILIKE '%Quote%'
    OR form_name ILIKE '%Receipt%'
);

-- Vendors (Purchasing)
UPDATE omtbl_app_forms 
SET module_id = (SELECT id FROM omtbl_modules WHERE name = 'Vendors')
WHERE module_id IS NULL 
AND (
    form_name ILIKE '%Vendor%' 
    OR form_name ILIKE '%Supplier%' 
    OR form_name ILIKE '%Purchase%' 
    OR form_name ILIKE '%Bill%'
    OR form_name ILIKE '%PO%'
);

-- Inventory
UPDATE omtbl_app_forms 
SET module_id = (SELECT id FROM omtbl_modules WHERE name = 'Inventory')
WHERE module_id IS NULL 
AND (
    form_name ILIKE '%Product%' 
    OR form_name ILIKE '%Item%' 
    OR form_name ILIKE '%Stock%' 
    OR form_name ILIKE '%Inventory%'
    OR form_name ILIKE '%Warehouse%'
    OR form_name ILIKE '%Category%'
    OR form_name ILIKE '%Brand%'
    OR form_name ILIKE '%Unit%'
);

-- HRMS
UPDATE omtbl_app_forms 
SET module_id = (SELECT id FROM omtbl_modules WHERE name = 'HRMS')
WHERE module_id IS NULL 
AND (
    form_name ILIKE '%Employee%' 
    OR form_name ILIKE '%Staff%' 
    OR form_name ILIKE '%Payroll%'
    OR form_name ILIKE '%Leave%'
    OR form_name ILIKE '%Department%'
    OR form_name ILIKE '%Designation%'
    OR form_name ILIKE '%Privilege%'
);

-- Admin (Fallback for setup/config)
UPDATE omtbl_app_forms 
SET module_id = (SELECT id FROM omtbl_modules WHERE name = 'Admin')
WHERE module_id IS NULL 
AND (
    form_name ILIKE '%Organization%' 
    OR form_name ILIKE '%Branch%' 
    OR form_name ILIKE '%User%'
    OR form_name ILIKE '%Role%'
    OR form_name ILIKE '%Setting%'
    OR form_name ILIKE '%Config%'
    OR form_name ILIKE '%Setup%'
);

-- Verify what remains unassigned
-- SELECT * FROM omtbl_app_forms WHERE module_id IS NULL;

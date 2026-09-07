-- ==============================================================================
-- ADD SUB-LEDGER COLUMNS TO TRANSACTIONS
-- ==============================================================================
-- Adds module_account and offset_module_account to omtbl_transactions
-- These fields store the Sub-Ledger ID (Customer ID, Vendor ID, Bank ID, etc.)
-- Logic:
-- IF Transaction affects Customer/Vendor/Bank:
--    module_account = CustomerID/VendorID/BankID
--    offset_module_account = OffsetGLAccountID (or OffsetSubLedgerID if applicable)
-- ELSE (General GL):
--    module_account = AccountID (Same as Main GL Account)
--    offset_module_account = OffsetAccountID
-- ==============================================================================

DO $$
BEGIN
    -- Add module_account
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_transactions' AND column_name = 'module_account') THEN
        ALTER TABLE omtbl_transactions ADD COLUMN module_account TEXT;
    END IF;

    -- Add offset_module_account
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_transactions' AND column_name = 'offset_module_account') THEN
        ALTER TABLE omtbl_transactions ADD COLUMN offset_module_account TEXT;
    END IF;

    -- Create Indexes for fast reporting (Filtering by specific Customer/Vendor)
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_omtbl_transactions_module_account') THEN
        CREATE INDEX idx_omtbl_transactions_module_account ON omtbl_transactions(module_account);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_omtbl_transactions_offset_module_account') THEN
        CREATE INDEX idx_omtbl_transactions_offset_module_account ON omtbl_transactions(offset_module_account);
    END IF;

END $$;

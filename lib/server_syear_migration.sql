-- server_syear_migration.sql
-- Ensure sYear exists in critical tables and is NOT NULL where appropriate.
-- This script should be run in Supabase SQL Editor.

-- 1. Financial Sessions Association (Source of Truth)
CREATE TABLE IF NOT EXISTS omtbl_financial_sessions (
    syear INTEGER PRIMARY KEY,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    narration TEXT,
    in_use BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    is_closed BOOLEAN DEFAULT FALSE,
    organization_id INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Add syear to Orders
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_orders' AND column_name = 'syear') THEN
        ALTER TABLE omtbl_orders ADD COLUMN syear INTEGER;
    END IF;
END $$;

-- 3. Add syear to Invoices
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_invoices' AND column_name = 'syear') THEN
        ALTER TABLE omtbl_invoices ADD COLUMN syear INTEGER;
    END IF;
END $$;

-- 4. Add syear to Transactions (GL)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_transactions' AND column_name = 'syear') THEN
        ALTER TABLE omtbl_transactions ADD COLUMN syear INTEGER;
    END IF;
END $$;

-- 5. Add store_id and syear to Roles
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_roles' AND column_name = 'store_id') THEN
        ALTER TABLE omtbl_roles ADD COLUMN store_id BIGINT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_roles' AND column_name = 'syear') THEN
        ALTER TABLE omtbl_roles ADD COLUMN syear INTEGER;
    END IF;
END $$;

-- 6. Add syear to Receipts/Payments (Bank Cash) if separated, otherwise checks Transactions
-- Assuming omtbl_receipts exists or is planned
CREATE TABLE IF NOT EXISTS omtbl_receipts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  syear INTEGER,
  -- other standard fields assumed or existing
  organization_id INTEGER
);

DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'omtbl_receipts' AND column_name = 'syear') THEN
        ALTER TABLE omtbl_receipts ADD COLUMN syear INTEGER;
    END IF;
END $$;

-- 6. Add Constraints (Optional: Strictness)
-- Note: Adding NOT NULL requires data backfill. We can add check constraints instead or triggers.

-- Example Function to validate Date within Session
CREATE OR REPLACE FUNCTION validate_syear_date_range()
RETURNS TRIGGER AS $$
DECLARE
    session_start DATE;
    session_end DATE;
BEGIN
    -- Skip if syear is null (checked by NOT NULL constraint if applied)
    IF NEW.syear IS NULL THEN
        RAISE EXCEPTION 'sYear is required for this transaction.';
    END IF;

    SELECT start_date, end_date INTO session_start, session_end
    FROM omtbl_financial_sessions
    WHERE syear = NEW.syear AND organization_id = NEW.organization_id;

    IF session_start IS NULL THEN
        RAISE EXCEPTION 'Invalid Financial Year (sYear %). Session not found.', NEW.syear;
    END IF;

    -- Assumption: 'voucher_date', 'invoice_date', 'order_date' column names vary.
    -- We need dynamic checking or specific triggers per table.
    -- This is a generic logic placeholder.
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

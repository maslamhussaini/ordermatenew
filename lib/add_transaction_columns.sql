-- Add new columns to omtbl_transactions for Receipt details

ALTER TABLE omtbl_transactions 
ADD COLUMN IF NOT EXISTS payment_mode text,
ADD COLUMN IF NOT EXISTS reference_number text,
ADD COLUMN IF NOT EXISTS reference_date timestamp,
ADD COLUMN IF NOT EXISTS reference_bank text,
ADD COLUMN IF NOT EXISTS invoice_id text;

-- Add index for invoice_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_transactions_invoice_id ON omtbl_transactions(invoice_id);

-- Optional: Add index for payment_mode for reporting
CREATE INDEX IF NOT EXISTS idx_transactions_payment_mode ON omtbl_transactions(payment_mode);

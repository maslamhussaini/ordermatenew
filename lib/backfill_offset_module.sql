-- ==============================================================================
-- UPDATE OFFSET MODULE ACCOUNT WITH CONTRA ACCOUNT (GL ID)
-- ==============================================================================
-- This script updates 'offset_module_account' for transactions linked to Invoices.
-- It sets 'offset_module_account' to the value of 'offset_account_id' (The Contra GL Account).
-- This ensures that querying by 'offset_module_account' will return these records
-- when filtering for that specific General Ledger account (e.g. Sales Income).
-- ==============================================================================

UPDATE public.omtbl_transactions t
SET offset_module_account = t.offset_account_id
FROM public.omtbl_invoices i
WHERE t.voucher_number = i.invoice_number
  AND t.organization_id = i.organization_id
  AND t.offset_module_account IS NULL
  AND t.offset_account_id IS NOT NULL; -- Ensure we have a contra account to copy

-- Note: This follows the logic "Else update ModuleAccount same as Account"
-- In this case, the Offset Module Account becomes the Offset GL Account ID.

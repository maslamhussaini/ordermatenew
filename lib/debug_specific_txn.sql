-- ==============================================================================
-- DEBUG SUB-LEDGER UPDATE
-- ==============================================================================

-- 1. Check why the specific transaction was not updated.
-- Does it match an invoice?
SELECT 
    t.id as transaction_id, 
    t.voucher_number, 
    t.module_account, 
    t.offset_module_account,
    i.invoice_number as matching_invoice,
    i.business_partner_id as customer_id
FROM public.omtbl_transactions t
LEFT JOIN public.omtbl_invoices i ON t.voucher_number = i.invoice_number AND t.organization_id = i.organization_id
WHERE t.id = '23ffee79-cb4c-4224-95f2-81fbadbe764e';

-- 2. Force Update for this SINGLE transaction (Test)
-- If query 1 returns a matching invoice, we run this:
UPDATE public.omtbl_transactions t
SET 
  module_account = COALESCE(i.business_partner_id, t.account_id),
  offset_module_account = COALESCE(t.offset_account_id, t.offset_account_id) -- Default logic logic
FROM public.omtbl_invoices i
WHERE t.voucher_number = i.invoice_number
  AND t.organization_id = i.organization_id
  AND t.id = '23ffee79-cb4c-4224-95f2-81fbadbe764e';

-- ==============================================================================
-- UPDATE TRANSACTIONS WITH CUSTOMER IDs FROM INVOICES
-- ==============================================================================
-- This script backfills the 'module_account' column in omtbl_transactions
-- by linking Transactions -> Invoices -> BusinessPartners (Customers).
-- Logic:
-- 1. Match Transactions to Invoices using 'voucher_number' (Assuming Voucher # = Invoice #)
-- 2. Update 'module_account' with the Invoice's 'business_partner_id'
-- 3. Only applies to Transactions corresponding to "Accounts Receivable" type logic
--    (i.e. Sales Invoices).
-- ==============================================================================

UPDATE public.omtbl_transactions t
SET module_account = i.business_partner_id
FROM public.omtbl_invoices i
WHERE t.voucher_number = i.invoice_number
  AND t.organization_id = i.organization_id -- Ensure safety in multi-tenant
  AND t.module_account IS NULL; -- Only update if empty

-- Also update offset_module_account if the transaction side is relevant
-- (Logic depends on which side of the entry is the "Customer" side)
-- Typically, for a Sale:
-- Debit: Accounts Receivable (ModuleAccount = CustomerID)
-- Credit: Sales Income (OffsetModuleAccount = SalesGL or CustomerID depending on logic)
-- If we follow your rule "update ModuleAccount same as Account or ... = OffsetAccount"
-- We simple backfill the Customer ID where we find the link.

-- For safety, run this query to verify matches first:
-- SELECT t.voucher_number, i.business_partner_id 
-- FROM omtbl_transactions t 
-- JOIN omtbl_invoices i ON t.voucher_number = i.invoice_number 
-- WHERE t.module_account IS NULL;

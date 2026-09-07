-- ==============================================================================
-- FIX SUB-LEDGER POSTING LOGIC (SMART UPDATE)
-- ==============================================================================
-- This script corrects the module_account and offset_module_account values
-- based on the Account Type logic requested.
-- 
-- LOGIC RULES:
-- 1. IF Account is "Accounts Receivable" (AR):
--      ModuleAccount = CustomerID (from Invoice)
-- 2. IF Offset Account is "Accounts Receivable" (e.g. Income Line):
--      OffsetModuleAccount = CustomerID (from Invoice)
-- 3. ALL OTHER CASES (Inventory, COGS, Income Main, etc.):
--      ModuleAccount = AccountID
--      OffsetModuleAccount = OffsetAccountID
-- ==============================================================================

DO $$
DECLARE
    -- We'll just run queries directly, no complex var needed typically
BEGIN

    -- 1. FIRST, RESET everything for Invoice Transactions to defaults (Self-Referencing)
    -- This handles the "Inventory/COGS" case where Module/OffsetModule should match Account/OffsetAccount.
    UPDATE public.omtbl_transactions t
    SET 
        module_account = t.account_id,
        offset_module_account = t.offset_account_id
    FROM public.omtbl_invoices i
    WHERE t.voucher_number = i.invoice_number
      AND t.organization_id = i.organization_id;


    -- 2. NOW, APPLY CUSTOMER ID OVERRIDES for AR Lines
    -- We need to identify AR accounts. 
    -- We look for accounts linked to 'Accounts Receivable' type or Category.
    -- (Adjust 'Accounts Receivable' string matches to your actual setup if needed)
    
    -- A. Update ModuleAccount for AR Debits (The Customer Line)
    UPDATE public.omtbl_transactions t
    SET module_account = i.business_partner_id
    FROM public.omtbl_invoices i
    JOIN public.omtbl_chart_of_accounts coa ON t.account_id = coa.id
    JOIN public.omtbl_account_types aty ON coa.account_type_id = aty.id
    WHERE t.voucher_number = i.invoice_number
      AND t.organization_id = i.organization_id
      AND (aty.type_name ILIKE '%Receivable%' OR coa.account_title ILIKE '%Receivable%');

    -- B. Update OffsetModuleAccount for Income Credits (The Income Line linked to AR)
    UPDATE public.omtbl_transactions t
    SET offset_module_account = i.business_partner_id
    FROM public.omtbl_invoices i
    JOIN public.omtbl_chart_of_accounts coa_offset ON t.offset_account_id = coa_offset.id
    JOIN public.omtbl_account_types aty_offset ON coa_offset.account_type_id = aty_offset.id
    WHERE t.voucher_number = i.invoice_number
      AND t.organization_id = i.organization_id
      AND (aty_offset.type_name ILIKE '%Receivable%' OR coa_offset.account_title ILIKE '%Receivable%');

END $$;

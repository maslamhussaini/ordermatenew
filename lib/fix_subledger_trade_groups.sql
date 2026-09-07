-- ==============================================================================
-- FIX SUB-LEDGER POSTING LOGIC (Using Trade Debtors/Creditors Group Names)
-- ==============================================================================

DO $$
BEGIN

    -- 1. RESET DEFAULTS
    UPDATE public.omtbl_transactions t
    SET module_account = t.account_id,
        offset_module_account = t.offset_account_id
    FROM public.omtbl_invoices i
    WHERE t.voucher_number = i.invoice_number
      AND t.organization_id = i.organization_id;


    -- 2. OVERRIDE AR LINES (Trade Debtors)
    -- Logic: If Account Group (Category) is 'Trade Debtors', assume it's a Customer line.
    UPDATE public.omtbl_transactions t
    SET module_account = i.business_partner_id
    FROM public.omtbl_invoices i,
         public.omtbl_chart_of_accounts coa,
         public.omtbl_account_categories cat
    WHERE t.voucher_number = i.invoice_number
      AND t.organization_id = i.organization_id
      AND t.account_id = coa.id
      AND coa.account_category_id = cat.id
      AND (cat.category_name ILIKE '%Trade Debtors%' OR cat.category_name ILIKE '%Accounts Receivable%');


    -- 3. OVERRIDE INCOME LINES (Where OFFSET is Trade Debtors)
    -- Logic: Income line's offset is the Customer account (Trade Debtors).
    UPDATE public.omtbl_transactions t
    SET offset_module_account = i.business_partner_id
    FROM public.omtbl_invoices i,
         public.omtbl_chart_of_accounts coa_offset,
         public.omtbl_account_categories cat_offset
    WHERE t.voucher_number = i.invoice_number
      AND t.organization_id = i.organization_id
      AND t.offset_account_id = coa_offset.id
      AND coa_offset.account_category_id = cat_offset.id
      AND (cat_offset.category_name ILIKE '%Trade Debtors%' OR cat_offset.category_name ILIKE '%Accounts Receivable%');

    
    -- 4. OVERRIDE AP LINES (Trade Creditors - for Purchases/Suppliers if linked to same Invoice table or Purchase Table)
    -- Assuming Invoices table handles Purchase Invoices too (or we only care about Sales Invoices here for now).
    -- If Invoices table has 'business_partner_id' which is Vendor for purchases:
    
    -- AP Debit (Payment to Vendor) OR Expense Credit (Bill from Vendor) - Logic depends on Voucher Type
    
    -- IF this is a BILL (Purchase):
    -- Credit Account = Trade Creditors (Vendor) -> ModuleAccount = VendorID
    -- Debit Account = Expense/Inventory -> OffsetModuleAccount = VendorID
    
    UPDATE public.omtbl_transactions t
    SET module_account = i.business_partner_id
    FROM public.omtbl_invoices i,
         public.omtbl_chart_of_accounts coa,
         public.omtbl_account_categories cat
    WHERE t.voucher_number = i.invoice_number
      AND t.organization_id = i.organization_id
      AND t.account_id = coa.id
      AND coa.account_category_id = cat.id
      AND (cat.category_name ILIKE '%Trade Creditors%' OR cat.category_name ILIKE '%Accounts Payable%');

END $$;

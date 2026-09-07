-- ==============================================================================
-- FIX SUB-LEDGER POSTING LOGIC (Specific 'Customers' Category)
-- ==============================================================================
-- Adds logic to handle Account Category "Customers" (or ID = 3).
-- ==============================================================================

DO $$
BEGIN

    -- 1. OVERRIDE AR LINES (Category = Customers)
    UPDATE public.omtbl_transactions t
    SET module_account = i.business_partner_id
    FROM public.omtbl_invoices i,
         public.omtbl_chart_of_accounts coa,
         public.omtbl_account_categories cat
    WHERE t.voucher_number = i.invoice_number
      AND t.organization_id = i.organization_id
      AND t.account_id = coa.id
      AND coa.account_category_id = cat.id
      -- Target specifically "Customers" category or ID 3
      AND (cat.category_name ILIKE '%Customers%' OR cat.id = 3);


    -- 2. OVERRIDE INCOME LINES (Where OFFSET is Customers)
    UPDATE public.omtbl_transactions t
    SET offset_module_account = i.business_partner_id
    FROM public.omtbl_invoices i,
         public.omtbl_chart_of_accounts coa_offset,
         public.omtbl_account_categories cat_offset
    WHERE t.voucher_number = i.invoice_number
      AND t.organization_id = i.organization_id
      AND t.offset_account_id = coa_offset.id
      AND coa_offset.account_category_id = cat_offset.id
      -- Target specifically "Customers" category or ID 3
      AND (cat_offset.category_name ILIKE '%Customers%' OR cat_offset.id = 3);
      
END $$;

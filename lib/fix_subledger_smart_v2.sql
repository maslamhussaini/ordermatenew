-- ==============================================================================
-- FIX SUB-LEDGER POSTING LOGIC (CORRECTED JOINS)
-- ==============================================================================

DO $$
BEGIN

    -- 1. RESET DEFAULTS
    -- (Self-Referencing: Module=Account, OffsetModule=OffsetAccount)
    UPDATE public.omtbl_transactions t
    SET 
        module_account = t.account_id,
        offset_module_account = t.offset_account_id
    FROM public.omtbl_invoices i
    WHERE t.voucher_number = i.invoice_number
      AND t.organization_id = i.organization_id;


    -- 2. OVERRIDE AR LINES
    -- Use a clean FROM/WHERE structure compatible with Postgres UPDATE with JOINs.
    -- Postgres UPDATE "FROM" clause implies a join, but referencing the target alias in subsequent buffer joins can be tricky.
    -- We will join all tables in the FROM clause.
    
    UPDATE public.omtbl_transactions t
    SET module_account = i.business_partner_id
    FROM public.omtbl_invoices i,
         public.omtbl_chart_of_accounts coa,
         public.omtbl_account_types aty
    WHERE t.voucher_number = i.invoice_number
      AND t.organization_id = i.organization_id
      AND t.account_id = coa.id
      AND coa.account_type_id = aty.id
      AND (aty.type_name ILIKE '%Receivable%' OR coa.account_title ILIKE '%Receivable%');


    -- 3. OVERRIDE INCOME LINES (Where OFFSET is AR)
    UPDATE public.omtbl_transactions t
    SET offset_module_account = i.business_partner_id
    FROM public.omtbl_invoices i,
         public.omtbl_chart_of_accounts coa_offset,
         public.omtbl_account_types aty_offset
    WHERE t.voucher_number = i.invoice_number
      AND t.organization_id = i.organization_id
      AND t.offset_account_id = coa_offset.id
      AND coa_offset.account_type_id = aty_offset.id
      AND (aty_offset.type_name ILIKE '%Receivable%' OR coa_offset.account_title ILIKE '%Receivable%');

END $$;

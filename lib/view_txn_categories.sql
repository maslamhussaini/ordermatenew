-- ==============================================================================
-- VIEW TRANSACTIONS WITH CATEGORY NAMES
-- ==============================================================================

SELECT 
    t.voucher_number,
    t.voucher_date,
    t.description,
    -- Account Details
    coa.account_title as "Account",
    cat.category_name as "Category",
    cat.id as "Category ID",
    -- Module Mapping
    t.module_account as "SubLedger ID",
    t.offset_module_account as "Offset SubLedger ID",
    -- Amounts
    t.amount
FROM 
    public.omtbl_transactions t
JOIN 
    public.omtbl_chart_of_accounts coa ON t.account_id = coa.id
JOIN 
    public.omtbl_account_categories cat ON coa.account_category_id = cat.id
ORDER BY 
    t.voucher_date DESC, t.voucher_number;

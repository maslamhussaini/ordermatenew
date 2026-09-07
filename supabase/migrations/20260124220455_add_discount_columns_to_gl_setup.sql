ALTER TABLE omtbl_gl_setup
ADD COLUMN IF NOT EXISTS purchase_discount_account_id uuid REFERENCES omtbl_chart_of_accounts(id),
ADD COLUMN IF NOT EXISTS sales_discount_account_id uuid REFERENCES omtbl_chart_of_accounts(id);

-- =====================================================================
--  PREPARED — DO NOT APPLY YET
--
--  Addresses N-1, N-2 and N-5. Held back deliberately: applying RLS or
--  replacing a security function without first knowing the live policy
--  state can lock users out of production.
--
--  APPLY ONLY AFTER Q1-Q4 in RUN_THESE_READONLY_QUERIES.sql have been run
--  and reviewed. Notes inline explain what each result changes.
--
--  Nothing here drops data. There is no DROP TABLE, no TRUNCATE, no
--  DELETE. The only DROPs are of functions/policies being replaced.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- N-1 + N-2 — one authoritative, hardened get_my_org_id()
--
-- Problem being fixed:
--   * Two definitions exist in lib/*.sql with DIFFERENT return types
--     (BIGINT in migration_saas_subscriptions.sql, INTEGER in
--     setup_strict_rbac.sql). CREATE OR REPLACE cannot change a return
--     type, so whichever ran second raised an error and silently did not
--     take effect.
--   * Both are SECURITY DEFINER with NO `SET search_path`, which is a
--     privilege-escalation vector: a caller who can create objects in a
--     schema earlier on the search_path can shadow `omtbl_users`.
--
-- Note the contrast with check_email_exists_rpc.sql, which already does
-- `SET search_path = public, auth` correctly. The pattern was known.
--
-- DROP is required (not just REPLACE) because the return type differs
-- between the two existing versions. Check Q4 output first: if the live
-- function returns BIGINT and any policy compares it to an INTEGER
-- column, confirm the cast is still valid after this change.
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_my_org_id() CASCADE;

CREATE FUNCTION public.get_my_org_id()
RETURNS BIGINT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp   -- N-1: pinned
AS $$
  SELECT u.organization_id
  FROM   public.omtbl_users u
  WHERE  u.auth_id = auth.uid()
  LIMIT  1;
$$;

REVOKE ALL ON FUNCTION public.get_my_org_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_org_id() TO authenticated;

-- NOTE: `CASCADE` above drops any policy that referenced the old
-- function. Q2 output tells you which policies those are. They must be
-- recreated in the same transaction or access will break. Do not run
-- this file until that list is known.

DROP FUNCTION IF EXISTS public.get_my_role_name() CASCADE;

CREATE FUNCTION public.get_my_role_name()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT r.role_name
  FROM   public.omtbl_users u
  JOIN   public.omtbl_roles r ON r.id = u.role_id
  WHERE  u.auth_id = auth.uid()
  LIMIT  1;
$$;

REVOKE ALL ON FUNCTION public.get_my_role_name() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_role_name() TO authenticated;


-- ---------------------------------------------------------------------
-- N-5 — tenant policies for the three uncovered financial-core tables
--
-- omtbl_invoices, omtbl_invoice_items and omtbl_order_items have no
-- CREATE POLICY in any of the 50 SQL files in the repository.
--
-- Q1 tells you which case you are in:
--   rls_enabled = false -> the tables are currently WIDE OPEN; these
--                          policies close them.
--   rls_enabled = true  -> they are currently LOCKED (RLS on, no policy);
--                          these policies restore access. Expect the app
--                          to have been failing on these tables.
--
-- The child tables have no organization_id of their own, so they inherit
-- it from their parent via EXISTS.
-- ---------------------------------------------------------------------

ALTER TABLE public.omtbl_invoices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS omtbl_invoices_tenant ON public.omtbl_invoices;
CREATE POLICY omtbl_invoices_tenant ON public.omtbl_invoices
  FOR ALL TO authenticated
  USING      (organization_id = public.get_my_org_id())
  WITH CHECK (organization_id = public.get_my_org_id());

ALTER TABLE public.omtbl_invoice_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS omtbl_invoice_items_tenant ON public.omtbl_invoice_items;
CREATE POLICY omtbl_invoice_items_tenant ON public.omtbl_invoice_items
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.omtbl_invoices i
    WHERE i.id = omtbl_invoice_items.invoice_id
      AND i.organization_id = public.get_my_org_id()))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.omtbl_invoices i
    WHERE i.id = omtbl_invoice_items.invoice_id
      AND i.organization_id = public.get_my_org_id()));

ALTER TABLE public.omtbl_order_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS omtbl_order_items_tenant ON public.omtbl_order_items;
CREATE POLICY omtbl_order_items_tenant ON public.omtbl_order_items
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.omtbl_orders o
    WHERE o.id = omtbl_order_items.order_id
      AND o.organization_id = public.get_my_org_id()))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.omtbl_orders o
    WHERE o.id = omtbl_order_items.order_id
      AND o.organization_id = public.get_my_org_id()));

-- Supports the EXISTS lookups above.
CREATE INDEX IF NOT EXISTS ix_invoice_items_invoice
  ON public.omtbl_invoice_items (invoice_id);
CREATE INDEX IF NOT EXISTS ix_order_items_order
  ON public.omtbl_order_items (order_id);

COMMIT;


-- =====================================================================
--  NOT INCLUDED HERE, ON PURPOSE
--
--  * Revoking the anonymous grants from allow_anon_accounting_seed.sql
--    (N-3). Q3 must confirm they are live and we must confirm nothing in
--    the onboarding flow depends on them before revoking, or new-org
--    signup could break during the demo.
--
--  * Reverting TEMP_FIX_RLS_PERMISSIVE.sql (N-4). Same reasoning.
--
--  * UNIQUE (organization_id, voucher_number) for H-1. Q9 must first
--    confirm no duplicates already exist, or the constraint fails to
--    create.
--
--  * Hot-path indexes for H-8. Q6 must first show what exists.
--
--  * Any change driven by C-5 (paymentTermId == 1). Q5 first.
-- =====================================================================

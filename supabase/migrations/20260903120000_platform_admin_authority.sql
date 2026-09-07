-- =====================================================================
--  Phase 3B-4A-R — Platform Admin Authority
--
--  Problem being fixed: the only existing "platform superUser" concept in
--  this application was a single hardcoded email string compared
--  client-side in lib/core/providers/auth_provider.dart. No server-side,
--  database-backed mechanism existed for a future service-role Edge
--  Function (or any other server-side code) to safely answer "is this
--  authenticated caller a platform administrator." This migration
--  introduces exactly that -- nothing else.
--
--  Scope discipline (per the binding Phase 3B-4A-R instructions):
--    - Does NOT touch any commercial-entitlement table (omtbl_modules,
--      omtbl_app_forms, omtbl_module_access_items, omtbl_report_bundles,
--      omtbl_report_bundle_items, omtbl_organization_bundle_entitlement,
--      omtbl_organization_bundle_entitlement_items).
--    - Does NOT touch omtbl_organizations.entitlement_mode.
--    - Does NOT touch omtbl_roles / organization-scoped RBAC.
--    - Adds exactly one new table and one new function.
--
--  This file is PREPARED for manual execution via the Supabase SQL
--  Editor by the project owner, consistent with every prior migration in
--  this engagement (Phase 3A's migration was likewise prepared here and
--  executed manually) -- this assistant has no direct Postgres/DDL access
--  in this environment (PostgREST-only, confirmed repeatedly across this
--  engagement), so this script has NOT been run against the live database.
--
--  Idempotency: IF NOT EXISTS / OR REPLACE / DROP POLICY IF EXISTS
--  throughout, safe to run more than once.
-- =====================================================================

BEGIN;

-- ============================================================
-- STEP 1 — omtbl_platform_admins
-- ============================================================
-- One row per platform administrator. user_id is a real FK into
-- auth.users(id) -- the only immutable, server-verifiable identity
-- Supabase provides. email is stored for admin-UI/display convenience
-- ONLY; it is never read as an authorization signal by is_platform_admin()
-- below or by any future caller of it.
--
-- Multi-admin support: nothing in this design assumes exactly one row --
-- any number of (user_id, is_active) rows can exist.

CREATE TABLE IF NOT EXISTS omtbl_platform_admins (
    id           SERIAL PRIMARY KEY,
    user_id      UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    email        TEXT,              -- display only, NOT authoritative
    is_active    BOOLEAN NOT NULL DEFAULT true,
    granted_by   UUID REFERENCES auth.users(id),  -- who granted this row, if known; nullable for the initial bootstrap row
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT omtbl_platform_admins_user_id_key UNIQUE (user_id)
);

COMMENT ON TABLE omtbl_platform_admins IS
    'Authoritative platform-level administrator membership. Independent of '
    'organization-scoped omtbl_roles/RBAC and independent of commercial '
    'entitlement. Written only via service_role (no INSERT/UPDATE/DELETE '
    'RLS policy exists for authenticated/anon -- see RLS section below). '
    'Read only via the is_platform_admin() SECURITY DEFINER function, '
    'never by direct table SELECT from ordinary sessions.';

COMMENT ON COLUMN omtbl_platform_admins.email IS
    'Display/admin-UI convenience only. NEVER used as an authorization '
    'signal -- user_id (a real auth.users FK) is the sole authority.';

CREATE INDEX IF NOT EXISTS idx_platform_admins_user_id
    ON omtbl_platform_admins(user_id);

-- ------------------------------------------------------------
-- RLS: default-deny for authenticated/anon on every operation.
-- ------------------------------------------------------------
-- No SELECT policy: an ordinary user must not be able to enumerate the
-- platform-admin list (Part M of the binding spec: "not expose
-- platform-admin membership to ordinary users unnecessarily").
-- No INSERT/UPDATE/DELETE policy: a normal session can never self-grant,
-- self-revoke, or modify another admin's row (Part G: "authority must not
-- be self-service"). Only service_role (which bypasses RLS entirely) can
-- write this table -- there is deliberately no client-facing write path
-- at all, not even an admin-only one, in this phase (Part M explicitly
-- says not to create an RPC/write-path unless proven necessary; none of
-- the currently-scoped work needs one -- see the accompanying report).

ALTER TABLE omtbl_platform_admins ENABLE ROW LEVEL SECURITY;

-- (No CREATE POLICY statements -- RLS enabled with zero policies means
-- every operation is denied by default for authenticated/anon; only
-- service_role, which bypasses RLS, can read or write this table
-- directly. This is a stricter posture than every other Phase 3A/3B
-- table, deliberately, since this table IS the authorization boundary.)


-- ============================================================
-- STEP 2 — is_platform_admin(): the one safe read path
-- ============================================================
-- SECURITY DEFINER, single hardcoded search_path (mirrors the SAFE
-- existing pattern used by current_org_id()/accessible_store_ids() --
-- NOT the WARNING-flagged get_my_org_id() pattern that also searches
-- 'pg_temp'). Takes no arguments and looks at auth.uid() only -- a caller
-- can only ever ask "am I a platform admin," never "is some other user id
-- a platform admin" (Part M: "not allow arbitrary caller impersonation").
--
-- Because it is SECURITY DEFINER, it can read omtbl_platform_admins even
-- though the calling role has no SELECT grant/policy on that table at
-- all -- this is the standard, already-established pattern in this
-- project for exposing a narrow, safe boolean derived from a
-- lockdown table.

CREATE OR REPLACE FUNCTION is_platform_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM omtbl_platform_admins
        WHERE user_id = auth.uid()
          AND is_active = true
    );
$$;

COMMENT ON FUNCTION is_platform_admin() IS
    'Returns true iff the CURRENTLY AUTHENTICATED caller (auth.uid()) is '
    'an active platform administrator. Takes no arguments -- cannot be '
    'used to query another user''s status. Safe for both client-side UI '
    'use (via .rpc(''is_platform_admin'')) and future service-role Edge '
    'Functions (which should independently verify the caller''s JWT and '
    'then check this same table/function for that verified identity -- '
    'never trust a client-supplied uuid/email/role/superUser flag).';

-- authenticated may call the function (to learn their OWN status only);
-- they still have no ability to read the underlying table directly.
GRANT EXECUTE ON FUNCTION is_platform_admin() TO authenticated;


-- ============================================================
-- STEP 3 — Bootstrap the current hardcoded admin, by email lookup only
-- ============================================================
-- Resolves the existing hardcoded platform-admin email
-- ('maslamhussaini@gmail.com') to its REAL auth.users.id at migration
-- EXECUTION time, via a live lookup against auth.users -- this migration
-- file does not contain, and the assistant that authored it does not
-- know, any actual UUID. auth.users is not reachable via PostgREST (the
-- only DB access this assistant has), so this INSERT can only be
-- performed by whoever runs this script with real Postgres/SQL-Editor
-- access.
--
-- If no auth.users row with this email exists yet, this is a safe no-op
-- (0 rows inserted, no error) -- see the accompanying report's "Current
-- Admin Bootstrap" section for the manual verification step required
-- after running this migration.

INSERT INTO omtbl_platform_admins (user_id, email)
SELECT id, email
FROM auth.users
WHERE email = 'maslamhussaini@gmail.com'
ON CONFLICT (user_id) DO NOTHING;

COMMIT;

-- =====================================================================
-- POST-MIGRATION VERIFICATION (run these manually, read-only, after
-- applying the above):
--
--   SELECT id, user_id, email, is_active, created_at
--   FROM omtbl_platform_admins;
--   -- Expect exactly one row for maslamhussaini@gmail.com if that auth
--   -- user already existed at migration time. If it returns zero rows,
--   -- see "Manual action required" in the Phase 3B-4A-R report.
--
--   SELECT is_platform_admin();
--   -- Run this as the bootstrapped admin's own authenticated session
--   -- (e.g. via the app, or `SET LOCAL ROLE authenticated; SELECT
--   -- set_config('request.jwt.claims', ...)` as done in earlier phases)
--   -- to confirm it returns true for them and would return false for
--   -- anyone else.
-- =====================================================================

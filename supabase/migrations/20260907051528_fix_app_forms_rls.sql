-- Minimal fix: allow global catalog rows (organization_id IS NULL) to be
-- visible to authenticated users while preserving tenant isolation for
-- organization-specific rows.

DROP POLICY IF EXISTS omtbl_app_forms_tenant ON omtbl_app_forms;

CREATE POLICY omtbl_app_forms_tenant
    ON omtbl_app_forms
    FOR ALL
    TO authenticated
    USING (organization_id = current_org_id() OR organization_id IS NULL)
    WITH CHECK (organization_id = current_org_id() OR organization_id IS NULL);

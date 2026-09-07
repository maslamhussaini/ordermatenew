-- Add is_system column to omtbl_roles
ALTER TABLE omtbl_roles ADD COLUMN IF NOT EXISTS is_system BOOLEAN DEFAULT FALSE;

-- Drop organization_id column from omtbl_roles
-- Assuming no foreign key constraints or they should be dropped too
ALTER TABLE omtbl_roles DROP COLUMN IF EXISTS organization_id;

-- Update local_roles table definition (This is just SQL, actual local migration needs Dart code)
-- This file acts as a reference for Supabase migration.

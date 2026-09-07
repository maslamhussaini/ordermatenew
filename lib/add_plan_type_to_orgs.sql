-- Add plan_type column to organizations
ALTER TABLE omtbl_organizations ADD COLUMN IF NOT EXISTS plan_type TEXT DEFAULT 'free';

-- Grant permissions if needed (though existing policies should cover updates if user owns org)
-- Start with 'free' plan for everyone.

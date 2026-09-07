
-- Create Location History Table
CREATE TABLE IF NOT EXISTS public.omtbl_location_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    organization_id BIGINT,
    store_id BIGINT,
    user_id UUID NOT NULL, -- Assuming UUID based on app user structure
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy DOUBLE PRECISION,
    
    -- Foreign Keys
    CONSTRAINT fk_organization FOREIGN KEY (organization_id) REFERENCES public.omtbl_organizations(id) ON DELETE SET NULL,
    CONSTRAINT fk_store FOREIGN KEY (store_id) REFERENCES public.omtbl_stores(id) ON DELETE SET NULL,
    CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES public.omtbl_businesspartners(id) ON DELETE CASCADE
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_location_history_user_date ON public.omtbl_location_history(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_location_history_org_date ON public.omtbl_location_history(organization_id, created_at);

-- RLS Policies
ALTER TABLE public.omtbl_location_history ENABLE ROW LEVEL SECURITY;

-- Allow users to view their own history (match by BP ID), and Admins/Owners to view all in their Org
CREATE POLICY "Admins and Owners can view all location history in their org" ON public.omtbl_location_history
FOR SELECT
USING (
  -- User is viewing their own data (linked via omtbl_users)
  EXISTS (
    SELECT 1 FROM public.omtbl_users
    WHERE id = auth.uid()
    AND business_partner_id = omtbl_location_history.user_id
  )
  OR
  -- User is an Admin/Owner looking at data in their organization
  (
    EXISTS (
      SELECT 1 FROM public.omtbl_users
      WHERE id = auth.uid() 
      AND (
        organization_id = omtbl_location_history.organization_id 
        OR role IN ('OWNER', 'SUPER USER', 'CORPORATE_ADMIN')
      )
      AND role IN ('OWNER', 'ADMIN', 'SUPER USER', 'CORPORATE_ADMIN')
    )
  )
);

-- Allow authenticated users to insert their *own* location
CREATE POLICY "Users can insert their own location" ON public.omtbl_location_history
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.omtbl_users
    WHERE id = auth.uid() 
    AND business_partner_id = omtbl_location_history.user_id
  )
);

-- Permissions
GRANT ALL ON public.omtbl_location_history TO authenticated;
GRANT ALL ON public.omtbl_location_history TO service_role;

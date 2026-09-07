-- ============================================
-- STATES / PROVINCES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS omtbl_states (
    id SERIAL PRIMARY KEY,
    state_name VARCHAR(255) NOT NULL,
    status INTEGER DEFAULT 1, -- 1=Active, 0=Inactive
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS for States
ALTER TABLE omtbl_states ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow read access for all" ON omtbl_states
    FOR SELECT USING (true);

CREATE POLICY "Allow insert for authenticated users" ON omtbl_states
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ============================================
-- MODIFY BUSINESS PARTNERS TABLE
-- ============================================

-- Add new address component columns
ALTER TABLE omtbl_businesspartners 
ADD COLUMN IF NOT EXISTS city_id INTEGER REFERENCES omtbl_cities(id),
ADD COLUMN IF NOT EXISTS state_id INTEGER REFERENCES omtbl_states(id),
ADD COLUMN IF NOT EXISTS country_id INTEGER REFERENCES omtbl_countries(id),
ADD COLUMN IF NOT EXISTS postal_code VARCHAR(20);

-- Indexes for new foreign keys
CREATE INDEX IF NOT EXISTS idx_omtbl_businesspartners_city ON omtbl_businesspartners(city_id);
CREATE INDEX IF NOT EXISTS idx_omtbl_businesspartners_state ON omtbl_businesspartners(state_id);
CREATE INDEX IF NOT EXISTS idx_omtbl_businesspartners_country ON omtbl_businesspartners(country_id);

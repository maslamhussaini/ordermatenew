-- ============================================
-- CITIES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS omtbl_cities (
    id SERIAL PRIMARY KEY,
    city_name VARCHAR(255) NOT NULL,
    status INTEGER DEFAULT 1, -- 1=Active, 0=Inactive
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- COUNTRIES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS omtbl_countries (
    id SERIAL PRIMARY KEY,
    country_name VARCHAR(255) NOT NULL,
    status INTEGER DEFAULT 1, -- 1=Active, 0=Inactive
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- RLS POLICIES FOR LOOKUP TABLES
-- ============================================

-- Enable RLS
ALTER TABLE omtbl_cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE omtbl_countries ENABLE ROW LEVEL SECURITY;
ALTER TABLE omtbl_business_types ENABLE ROW LEVEL SECURITY;

-- Cities Policies
CREATE POLICY "Allow read access for all" ON omtbl_cities
    FOR SELECT USING (true);

CREATE POLICY "Allow insert for authenticated users" ON omtbl_cities
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Countries Policies
CREATE POLICY "Allow read access for all" ON omtbl_countries
    FOR SELECT USING (true);

CREATE POLICY "Allow insert for authenticated users" ON omtbl_countries
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Business Types Policies
CREATE POLICY "Allow read access for all" ON omtbl_business_types
    FOR SELECT USING (true);

CREATE POLICY "Allow insert for authenticated users" ON omtbl_business_types
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

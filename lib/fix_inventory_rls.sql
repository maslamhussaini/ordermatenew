-- ============================================
-- FIX RLS FOR INVENTORY LOOKUP TABLES
-- ============================================

-- 1. BRANDS
ALTER TABLE omtbl_brands ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read for all authenticated users" ON omtbl_brands;
CREATE POLICY "Allow read for all authenticated users"
ON omtbl_brands FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow insert for authenticated users" ON omtbl_brands;
CREATE POLICY "Allow insert for authenticated users"
ON omtbl_brands FOR INSERT TO authenticated WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow update for authenticated users" ON omtbl_brands;
CREATE POLICY "Allow update for authenticated users"
ON omtbl_brands FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow delete for authenticated users" ON omtbl_brands;
CREATE POLICY "Allow delete for authenticated users"
ON omtbl_brands FOR DELETE TO authenticated USING (true);


-- 2. CATEGORIES
ALTER TABLE omtbl_categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read for all authenticated users" ON omtbl_categories;
CREATE POLICY "Allow read for all authenticated users"
ON omtbl_categories FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow insert for authenticated users" ON omtbl_categories;
CREATE POLICY "Allow insert for authenticated users"
ON omtbl_categories FOR INSERT TO authenticated WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow update for authenticated users" ON omtbl_categories;
CREATE POLICY "Allow update for authenticated users"
ON omtbl_categories FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow delete for authenticated users" ON omtbl_categories;
CREATE POLICY "Allow delete for authenticated users"
ON omtbl_categories FOR DELETE TO authenticated USING (true);


-- 3. PRODUCT TYPES
ALTER TABLE omtbl_producttypes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read for all authenticated users" ON omtbl_producttypes;
CREATE POLICY "Allow read for all authenticated users"
ON omtbl_producttypes FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow insert for authenticated users" ON omtbl_producttypes;
CREATE POLICY "Allow insert for authenticated users"
ON omtbl_producttypes FOR INSERT TO authenticated WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow update for authenticated users" ON omtbl_producttypes;
CREATE POLICY "Allow update for authenticated users"
ON omtbl_producttypes FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow delete for authenticated users" ON omtbl_producttypes;
CREATE POLICY "Allow delete for authenticated users"
ON omtbl_producttypes FOR DELETE TO authenticated USING (true);


-- 4. UNITS OF MEASURE (Ensure they are also accessible)
ALTER TABLE omtbl_units_of_measure ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read for authenticated" ON omtbl_units_of_measure;
CREATE POLICY "Allow read for authenticated"
ON omtbl_units_of_measure FOR SELECT TO authenticated USING (true);

-- 5. UNIT CONVERSIONS (Ensure they are also accessible)
ALTER TABLE omtbl_unit_conversions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read for authenticated" ON omtbl_unit_conversions;
CREATE POLICY "Allow read for authenticated"
ON omtbl_unit_conversions FOR SELECT TO authenticated USING (true);

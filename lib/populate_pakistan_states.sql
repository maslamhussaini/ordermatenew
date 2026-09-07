DO $$
DECLARE
    pakistan_id INT;
BEGIN
    -- 1. Find Country ID for Pakistan
    SELECT id INTO pakistan_id FROM omtbl_countries WHERE LOWER(country_name) LIKE '%pakistan%';

    -- If not found, insert it
    IF pakistan_id IS NULL THEN
        INSERT INTO omtbl_countries (country_name, status) VALUES ('Pakistan', 1) RETURNING id INTO pakistan_id;
    END IF;

    -- 2. Insert States if not exists (Basic List)
    INSERT INTO omtbl_states (state_name, country_id, status)
    SELECT s.name, pakistan_id, 1
    FROM (VALUES 
        ('Sindh'), 
        ('Punjab'), 
        ('Khyber Pakhtunkhwa'), 
        ('Balochistan'), 
        ('Islamabad Capital Territory'), 
        ('Gilgit-Baltistan'), 
        ('Azad Jammu and Kashmir')
    ) AS s(name)
    WHERE NOT EXISTS (
        SELECT 1 FROM omtbl_states WHERE LOWER(state_name) = LOWER(s.name) AND country_id = pakistan_id
    );

END $$;

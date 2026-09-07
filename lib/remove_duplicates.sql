-- Remove duplicate Categories (per organization, keeping the one with the lowest ID)
DELETE FROM omtbl_categories
WHERE idcategory IN (
    SELECT idcategory
    FROM (
        SELECT idcategory,
        ROW_NUMBER() OVER (
            PARTITION BY lower(trim(category)), organization_id 
            ORDER BY idcategory
        ) AS rnum
        FROM omtbl_categories
    ) t
    WHERE t.rnum > 1
);

-- Remove duplicate Brands (per organization)
DELETE FROM omtbl_brands
WHERE idbrand IN (
    SELECT idbrand
    FROM (
        SELECT idbrand,
        ROW_NUMBER() OVER (
            PARTITION BY lower(trim(brandtype)), organization_id 
            ORDER BY idbrand
        ) AS rnum
        FROM omtbl_brands
    ) t
    WHERE t.rnum > 1
);

-- Remove duplicate Product Types (per organization)
DELETE FROM omtbl_producttypes
WHERE idproducttype IN (
    SELECT idproducttype
    FROM (
        SELECT idproducttype,
        ROW_NUMBER() OVER (
            PARTITION BY lower(trim(producttype)), organization_id 
            ORDER BY idproducttype
        ) AS rnum
        FROM omtbl_producttypes
    ) t
    WHERE t.rnum > 1
);

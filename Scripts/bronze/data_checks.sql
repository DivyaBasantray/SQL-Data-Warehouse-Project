-- CHECK FOR NULLS OR DUPLICATES IN PRIMARY KEY
-- EXPECTATION : NO RESULT

SELECT
	prd_id,
	COUNT(*)
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- CHECK FOR UNWANTED SPACES
-- EXPEXTATION : NO RESULTS

SELECT prd_nm
FROM bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- CHECK FOR NULLS AND NEGATIVE NUMBERS
-- EXPEXTATION : NO RESULTS

SELECT prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- DATA STANDARDIZATION AND CONSISTENCY

SELECT DISTINCT prd_line
FROM bronze.crm_prd_info;

-- CHECK FOR INVALID DATE ORDERS

SELECT *
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

SELECT *
FROM bronze.crm_prd_info;

SELECT	
	prd_id,
	REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,	--EXTRACT CATEGORY ID
	SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,			-- EXTRACT PRODUCT KEY
	prd_nm,
	ISNULL(prd_cost, 0) AS prd_cost,
	CASE UPPER(TRIM(prd_line)) 
		WHEN 'M' THEN 'Mountain'
		WHEN 'R' THEN 'Road'
		WHEN 'S' THEN 'Other Sales'
		WHEN 'T' THEN 'Touring'
		ELSE 'NA'
	END AS prd_line,		-- MAP PRODUCT LINE CODES TO DESCRIPTIVE VALUES
	CAST(prd_start_dt AS DATE) AS prd_start_dt,
	CAST(
		LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt) -1 
		AS DATE
	) AS prd_end_dt			-- CALCULATE END DATE AS ONE DAY BEFORE THE NEXT START DATE
FROM bronze.crm_prd_info;

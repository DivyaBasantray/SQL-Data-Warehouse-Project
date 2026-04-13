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

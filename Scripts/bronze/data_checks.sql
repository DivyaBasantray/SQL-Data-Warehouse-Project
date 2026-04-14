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

----------------------------------------------------------------------------------------------------------------------------------------------------------

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

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- CHECK FOR INVALID DATES

SELECT sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0;

SELECT 
	NULLIF(sls_order_dt, 0) sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0 
OR LEN(sls_order_dt) != 8 
OR sls_order_dt > 20500101
OR sls_order_dt <19000101;

SELECT 
	NULLIF(sls_due_dt, 0) sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0 
OR LEN(sls_due_dt) != 8 
OR sls_due_dt > 20500101
OR sls_due_dt <19000101;

-- CHECK FOR INVALID DATE ORDERS

SELECT *
FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
OR sls_order_dt > sls_due_dt;

-- CHECK DATA CONSISTENCY: BETWEEN SALES, QUANTITY, AND PRICE
-- >> SLAES = QUANTITY * PRICE
-- >> VALUES MUST NOT BE NULL, ZERO, OR NEGATIVE.

SELECT DISTINCT
	sls_sales,
	sls_quantity,
	sls_price
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

--- RULES ---

-- IF SALES IS NEGATIVE, XERO, OR NULL, DERIVE IT USING QUANTITY AND PRICE.
-- IF PRICE IS ZERO OR NULL, CALCULATE IT USING SALES AND QUANTITY.
-- IF PRICE IS NEGATIVE, CONVERT IT TO A POSITIVE VALUE.

SELECT DISTINCT
	sls_sales AS old_sls_sales,
	sls_quantity,
	sls_price AS old_sls_price,

CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)  --ABS() : RETURNS ABSOLUTE VALUE OF A NUMBER
	 THEN sls_quantity * ABS(sls_price)
	 ELSE sls_sales
END AS sls_sales,

CASE WHEN sls_price IS NULL OR sls_price <= 0
	 THEN sls_sales / NULLIF(sls_quantity, 0)
	 ELSE sls_price
END AS sls_price

FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT	
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,

	CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
		 ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
	END AS sls_order_dt,

	CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
		 ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
	END AS sls_ship_dt,

	CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
		 ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
	END AS sls_due_dt,
	
	CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)  --ABS() : RETURNS ABSOLUTE VALUE OF A NUMBER
		 THEN sls_quantity * ABS(sls_price)
		 ELSE sls_sales
	END AS sls_sales, 		-- RECALCULATE SALES IF ORIGINAL VALUE IS MISSING OR INCORRECT

	sls_quantity,

	CASE WHEN sls_price IS NULL OR sls_price <= 0
		 THEN sls_sales / NULLIF(sls_quantity, 0)
		 ELSE sls_price			-- DERIVE PRICE IF ORIGINAL VALUE IS INVALID
	END AS sls_price
	
FROM bronze.crm_sales_details;

/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs various quality checks for data consistency, accuracy, 
    and standardization across the 'silver' layer. It includes checks for:
    - Null or duplicate primary keys.
    - Unwanted spaces in string fields.
    - Data standardization and consistency.
    - Invalid date ranges and orders.
    - Data consistency between related fields.

Usage Notes:
    - Run these checks after data loading Silver Layer.
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

-- ====================================================================
-- Checking 'silver.crm_cust_info'
-- ====================================================================

-- CHECK FOR NULLS OR DUPLICATES IN PRIMARY KEY
-- EXPECTATION : NO RESULT
SELECT 
    cst_id,
    COUNT(*) 
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- CHECK FOR UNWANTED SPACES
-- EXPECTATION : NO RESULT
SELECT 
    cst_key 
FROM silver.crm_cust_info
WHERE cst_key != TRIM(cst_key);

-- DATA STANDARDIZATION AND CONSISTENCY

SELECT DISTINCT 
    cst_marital_status 
FROM silver.crm_cust_info;

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- ====================================================================
-- Checking 'silver.crm_prd_info'
-- ====================================================================

-- CHECK FOR NULLS OR DUPLICATES IN PRIMARY KEY
-- EXPECTATION : NO RESULT

SELECT
	prd_id,
	COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- CHECK FOR UNWANTED SPACES
-- EXPEXTATION : NO RESULTS

SELECT prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- CHECK FOR NULLS AND NEGATIVE NUMBERS
-- EXPEXTATION : NO RESULTS

SELECT prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- DATA STANDARDIZATION AND CONSISTENCY

SELECT DISTINCT prd_line
FROM silver.crm_prd_info;

-- CHECK FOR INVALID DATE ORDERS

SELECT *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

SELECT *
FROM silver.crm_prd_info;

IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
	DROP TABLE silver.crm_prd_info;
CREATE TABLE silver.crm_prd_info (
    prd_id          INT,
    cat_id          NVARCHAR(50),
    prd_key         NVARCHAR(50),
    prd_nm          NVARCHAR(50),
    prd_cost        INT,
    prd_line        NVARCHAR(50),
    prd_start_dt    DATE,
    prd_end_dt      DATE,
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);


INSERT INTO silver.crm_prd_info(
	prd_id,
	cat_id,
    prd_key,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt,
    prd_end_dt
)
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

-----------------------------------------------------------------------------------------------------------------------------------------------------------------

-- ====================================================================
-- Checking 'silver.crm_sales_details'
-- ====================================================================

IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
	DROP TABLE silver.crm_sales_details;
CREATE TABLE silver.crm_sales_details (
    sls_ord_num			NVARCHAR(50),
    sls_prd_key			NVARCHAR(50),
    sls_cust_id         INT,
    sls_order_dt        DATE,
    sls_ship_dt			DATE,
    sls_due_dt			DATE,
    sls_sales			INT,
    sls_quantity		INT,
	sls_price			INT,
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);

INSERT INTO silver.crm_sales_details(
	sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
	sls_price
)

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
	END AS sls_sales,

	sls_quantity,

	CASE WHEN sls_price IS NULL OR sls_price <= 0
		 THEN sls_sales / NULLIF(sls_quantity, 0)
		 ELSE sls_price
	END AS sls_price
	
FROM bronze.crm_sales_details;

SELECT *
FROM silver.crm_sales_details;

-----------------------------------------------------------------------------------------------------------------------------------------------------------

-- ====================================================================
-- Checking 'silver.erp_cust_az12'
-- ====================================================================

-- IDENTIFY OUT-OF-RANGE DATES

SELECT DISTINCT bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01' OR bdate > GETDATE();

-- DATA STANDARDIZATION AND CONSISTENCY

SELECT DISTINCT gen,
FROM silver.erp_cust_az12;

INSERT INTO silver.erp_cust_az12 (cid, bdate, gen)
SELECT
	CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))		-- REMOVE 'NAS' PREFIX IF PRESENT
		 ELSE cid
	END AS cid,

	CASE WHEN bdate > GETDATE() THEN NULL
		 ELSE bdate
	
	END AS bdate,		-- SET FUTURE BIRTHDATES TO NULL
	
	CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
		 WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
		 ELSE 'NA'
	END AS gen		-- NORMALIZE GENDER VALUES AND HANDLE UNKNOWN CASES

FROM bronze.erp_cust_az12;

SELECT * FROM [silver].[crm_cust_info];

-----------------------------------------------------------------------------------------------------------------------------------------------------------

-- ====================================================================
-- Checking 'silver.erp_loc_a101'
-- ====================================================================

-- DATA STANDARDIZATION AND CONSISTENCY

SELECT DISTINCT	cntry					 	
FROM silver.erp_loc_a101
ORDER BY cntry;

SELECT * 
FROM silver.erp_loc_a101;

INSERT INTO silver.erp_loc_a101
(cid, cntry)
SELECT 
	REPLACE (cid,'-', '') cid,
	CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
		 WHEN TRIM(cntry) IN ('US', 'USA')  THEN 'United States'
		 WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'NA'
		 ELSE TRIM(cntry)
	END AS cntry		-- NORMALIZE AND HANDLE MISSING OR BLANK COUNTRY CODES
FROM bronze.erp_loc_a101;

-----------------------------------------------------------------------------------------------------------------------------------------------------------

-- ====================================================================
-- Checking 'silver.erp_px_cat_g1v2'
-- ====================================================================

-- CHECK FOR UNWANTED SPACES
-- EXPECTATION : NO RESULT

SELECT 
    * 
FROM silver.erp_px_cat_g1v2
WHERE cat != TRIM(cat) 
   OR subcat != TRIM(subcat) 
   OR maintenance != TRIM(maintenance);

-- DATA STANDARDIZATION AND CONSISTENCY

SELECT DISTINCT maintenance 
FROM silver.erp_px_cat_g1v2;

INSERT INTO silver.erp_px_cat_g1v2
(id, cat, subcat, maintenance)
SELECT 
	id, 
	cat, 
	subcat,
	maintenance
FROM bronze.erp_px_cat_g1v2;

SELECT *
FROM silver.erp_px_cat_g1v2;











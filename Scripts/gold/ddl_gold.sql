/*
===============================================================================
 Script Name     : Create Gold Views
 Layer           : Gold (Presentation Layer - Star Schema)
 Purpose         : 
    - Creates dimension and fact views from Silver layer
    - Performs joins, transformations, and cleansed enrichment
 Usage           : 
    - Used by BI tools for reporting and analytics
===============================================================================
*/


-- =============================================================================
-- Dimension View: gold.dim_customers
-- =============================================================================
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY ci.cst_id)     AS customer_key,       -- Surrogate Key
    ci.cst_id                                  AS customer_id,
    ci.cst_key                                 AS customer_number,
    ci.cst_firstname                           AS first_name,
    ci.cst_lastname                            AS last_name,
    loc.cntry                                  AS country,
    ci.cst_marital_status                      AS marital_status,
    CASE 
        WHEN ci.cst_gndr != 'n/a' 
            THEN ci.cst_gndr                   -- Primary from CRM
        ELSE 
            COALESCE(erp.gen, 'n/a')           -- Fallback to ERP
    END                                        AS gender,
    erp.bdate                                  AS birthdate,
    ci.cst_create_date                         AS create_date
FROM silver.crm_cust_info       AS ci
LEFT JOIN silver.erp_cust_az12  AS erp
    ON ci.cst_key = erp.cid
LEFT JOIN silver.erp_loc_a101   AS loc
    ON ci.cst_key = loc.cid;
GO


-- =============================================================================
-- Dimension View: gold.dim_products
-- =============================================================================
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY prd.prd_start_dt, prd.prd_key) AS product_key, -- Surrogate Key
    prd.prd_id           AS product_id,
    prd.prd_key          AS product_number,
    prd.prd_nm           AS product_name,
    prd.cat_id           AS category_id,
    cat.cat              AS category,
    cat.subcat           AS subcategory,
    cat.maintenance      AS maintenance,
    prd.prd_cost         AS cost,
    prd.prd_line         AS product_line,
    prd.prd_start_dt     AS start_date
FROM silver.crm_prd_info       AS prd
LEFT JOIN silver.erp_px_cat_g1v2 AS cat
    ON prd.cat_id = cat.id
WHERE prd.prd_end_dt IS NULL;  -- Exclude inactive/historical records
GO


-- =============================================================================
-- Fact View: gold.fact_sales
-- =============================================================================
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS
SELECT
    sd.sls_ord_num       AS order_number,
    pr.product_key       AS product_key,
    cu.customer_key      AS customer_key,
    sd.sls_order_dt      AS order_date,
    sd.sls_ship_dt       AS shipping_date,
    sd.sls_due_dt        AS due_date,
    sd.sls_sales         AS sales_amount,
    sd.sls_quantity      AS quantity,
    sd.sls_price         AS price
FROM silver.crm_sales_details  AS sd
LEFT JOIN gold.dim_products    AS pr
    ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers   AS cu
    ON sd.sls_cust_id = cu.customer_id;
GO

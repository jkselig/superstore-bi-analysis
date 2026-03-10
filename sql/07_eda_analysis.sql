/* ============================================================================
   SuperStoreBI Project (SQL Server)
   File: 07_eda_analysis.sql

   Purpose:
     EDA + validation checks after the model is built.
     Highlights key insight: a small number of extreme-loss transactions can
     materially reduce overall profit.

   Run Order:
     Run this after:
       04_build_dimensions.sql
       05_build_fact.sql
       06_create_views.sql
============================================================================ */
GO

USE SuperStoreBI;
GO

/* =========================================================
   0) MODEL BUILD VALIDATION (counts)
========================================================= */

SELECT 'staging_superstore' AS table_name, COUNT(*) AS row_count
FROM dbo.staging_superstore
UNION ALL
SELECT 'dim_customer', COUNT(*) FROM dbo.dim_customer
UNION ALL
SELECT 'dim_product', COUNT(*) FROM dbo.dim_product
UNION ALL
SELECT 'dim_date', COUNT(*) FROM dbo.dim_date
UNION ALL
SELECT 'fact_sales', COUNT(*) FROM dbo.fact_sales;
GO

-- Fact should match staging if all key joins succeeded
SELECT
    (SELECT COUNT(*) FROM dbo.staging_superstore) AS staging_rows,
    (SELECT COUNT(*) FROM dbo.fact_sales)        AS fact_rows;
GO

/* =========================================================
   1) DATA QUALITY CHECKS
========================================================= */

-- Profit NULLs (dataset has 1)
SELECT
    COUNT(*) AS profit_null_rows
FROM dbo.fact_sales
WHERE profit IS NULL;

-- Sanity checks for Sales
SELECT
    SUM(CASE WHEN sales IS NULL THEN 1 ELSE 0 END) AS sales_null_rows,
    SUM(CASE WHEN sales < 0 THEN 1 ELSE 0 END)     AS sales_negative_rows,
    MIN(sales) AS min_sales,
    MAX(sales) AS max_sales
FROM dbo.fact_sales;
GO

/* =========================================================
   2) BASELINE BUSINESS METRICS
========================================================= */

SELECT
    SUM(sales)  AS total_sales,
    SUM(profit) AS total_profit,
    CASE WHEN SUM(sales) = 0 THEN NULL ELSE SUM(profit)/SUM(sales) END AS profit_margin_pct,
    COUNT(DISTINCT order_id) AS orders
FROM dbo.fact_sales;
GO

/* =========================================================
   3) EXTREME LOSS ANALYSIS (profit <= -1000)
   Insight: a small number of transactions can drive a large share of losses.
========================================================= */

-- Count + total extreme loss
SELECT
    COUNT(*)      AS extreme_loss_rows,
    SUM(profit)   AS extreme_loss_profit_sum,      -- negative number
    SUM(-profit)  AS extreme_loss_abs_loss         -- positive dollars lost
FROM dbo.fact_sales
WHERE profit <= -1000;
GO

-- Extreme loss share of total profit impact
-- (Interprets "profit impact" as extreme losses relative to overall total profit.)
SELECT
    COUNT(*) AS extreme_loss_transactions,
    SUM(CASE WHEN profit <= -1000 THEN profit ELSE 0 END) AS extreme_loss_profit_sum,
    SUM(profit) AS total_profit,
    CASE 
        WHEN SUM(profit) = 0 THEN NULL
        ELSE SUM(CASE WHEN profit <= -1000 THEN profit ELSE 0 END) / SUM(profit)
    END AS extreme_loss_as_pct_of_total_profit
FROM dbo.fact_sales;
GO

-- Top 25 worst transactions (for drill-down / screenshot)
SELECT TOP (25)
    v.order_date,
    v.order_id,
    v.region,
    v.segment,
    v.category,
    v.sub_category,
    v.product_name,
    v.sales,
    v.profit,
    v.discount,
    v.quantity
FROM dbo.vw_extreme_loss_transactions v
ORDER BY v.profit ASC;
GO

/* =========================================================
   4) CHECK IF EXTREME LOSSES ARE CONCENTRATED
   (If not concentrated, supports "one-off" exceptions narrative)
========================================================= */

-- By Region
SELECT
    region,
    COUNT(*) AS extreme_loss_rows,
    SUM(profit) AS extreme_loss_profit
FROM dbo.vw_extreme_loss_transactions
GROUP BY region
ORDER BY SUM(profit) ASC;
GO

-- By Category/Sub-Category
SELECT
    category,
    sub_category,
    COUNT(*) AS extreme_loss_rows,
    SUM(profit) AS extreme_loss_profit
FROM dbo.vw_extreme_loss_transactions
GROUP BY category, sub_category
ORDER BY SUM(profit) ASC;
GO

-- By Segment
SELECT
    segment,
    COUNT(*) AS extreme_loss_rows,
    SUM(profit) AS extreme_loss_profit
FROM dbo.vw_extreme_loss_transactions
GROUP BY segment
ORDER BY SUM(profit) ASC;
GO

/* =========================================================
   5) RECOMMENDATION SUPPORT METRIC
   "Manager approval required" rule simulation
========================================================= */

-- What fraction of orders would be flagged if we require approval
-- for ANY order containing a line with profit <= -1000?
SELECT
    COUNT(DISTINCT order_id) AS flagged_orders,
    (SELECT COUNT(DISTINCT order_id) FROM dbo.fact_sales) AS total_orders,
    CAST(COUNT(DISTINCT order_id) AS DECIMAL(12,4))
      / NULLIF((SELECT COUNT(DISTINCT order_id) FROM dbo.fact_sales), 0) AS pct_orders_flagged
FROM dbo.fact_sales
WHERE profit <= -1000;
GO

/* =========================================================
   6) TREND CHECK (uses MoM view)
========================================================= */

SELECT TOP (24)
    year,
    month,
    month_name,
    total_sales,
    total_profit,
    prior_month_sales,
    mom_sales_change,
    mom_sales_pct
FROM dbo.vw_sales_summary_monthly_mom
ORDER BY year, month;
GO

/* =========================================================
   7) DISCOUNT IMPACT ANALYSIS
   Goal:
     - Quantify profitability by discount level
     - Determine whether higher discounts correlate with margin erosion

   What to look for:
     - Profit margin typically declines as discount increases
     - High-discount buckets (e.g., 40%+) often show negative profit
========================================================= */

------------------------------------------------------------
-- 7A) Profitability by exact discount value (fine-grained)
------------------------------------------------------------
SELECT
    discount,
    COUNT(*) AS transactions,
    SUM(sales) AS total_sales,
    SUM(profit) AS total_profit,
    AVG(profit) AS avg_profit_per_line,
    CASE
        WHEN SUM(sales) = 0 THEN NULL
        ELSE SUM(profit) / SUM(sales)
    END AS profit_margin
FROM dbo.fact_sales
GROUP BY discount
ORDER BY discount;
GO

------------------------------------------------------------
-- 7B) Profitability by discount buckets (dashboard-friendly)
------------------------------------------------------------
WITH bucketed AS (
    SELECT
        CASE
            WHEN discount = 0 THEN 'No Discount'
            WHEN discount <= 0.10 THEN '0–10%'
            WHEN discount <= 0.20 THEN '10–20%'
            WHEN discount <= 0.40 THEN '20–40%'
            ELSE '40%+'
        END AS discount_bucket,
        CASE
            WHEN discount = 0 THEN 0
            WHEN discount <= 0.10 THEN 1
            WHEN discount <= 0.20 THEN 2
            WHEN discount <= 0.40 THEN 3
            ELSE 4
        END AS bucket_sort,
        sales,
        profit
    FROM dbo.fact_sales
)
SELECT
    discount_bucket,
    COUNT(*) AS transactions,
    SUM(sales) AS total_sales,
    SUM(profit) AS total_profit,
    AVG(profit) AS avg_profit_per_line,
    CASE
        WHEN SUM(sales) = 0 THEN NULL
        ELSE SUM(profit) / SUM(sales)
    END AS profit_margin
FROM bucketed
GROUP BY discount_bucket, bucket_sort
ORDER BY bucket_sort;
GO
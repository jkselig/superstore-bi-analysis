/* ============================================================================
   SuperStoreBI Project (SQL Server)
   File: 06_create_views.sql

   Purpose:
     Create BI reporting views for Power BI dashboards.

   Views Created:
     vw_sales_detail
     vw_sales_summary_monthly
     vw_sales_summary_monthly_mom
     vw_regional_sales_monthly
     vw_product_performance
     vw_customer_sales
     vw_extreme_loss_transactions
============================================================================ */

USE SuperStoreBI;
GO


/* =========================================================
   1) SALES DETAIL VIEW (fact grain)
========================================================= */

CREATE OR ALTER VIEW dbo.vw_sales_detail AS
SELECT
    f.sales_key,
    f.order_id,
    f.row_id,

    d.calendar_date AS order_date,
    d.year,
    d.quarter,
    d.month,
    d.month_name,
    d.week_of_year,

    ds.calendar_date AS ship_date,

    c.customer_id,
    c.customer_name,
    c.segment,
    c.region,
    c.state,
    c.city,
    c.postal_code,

    p.product_id,
    p.category,
    p.sub_category,
    p.product_name,

    f.ship_mode,
    f.sales,
    f.quantity,
    f.discount,
    f.profit,
    f.margin_pct,
    f.profit_missing_flag,
    f.extreme_loss_flag

FROM dbo.fact_sales f
JOIN dbo.dim_date d
    ON f.order_date_key = d.date_key
JOIN dbo.dim_date ds
    ON f.ship_date_key = ds.date_key
JOIN dbo.dim_customer c
    ON f.customer_key = c.customer_key
JOIN dbo.dim_product p
    ON f.product_key = p.product_key;
GO


/* =========================================================
   2) MONTHLY SALES SUMMARY (Executive KPIs)
========================================================= */

CREATE OR ALTER VIEW dbo.vw_sales_summary_monthly AS
SELECT
    d.year,
    d.month,
    d.month_name,

    COUNT(DISTINCT f.order_id) AS order_count,
    COUNT(DISTINCT f.customer_key) AS customer_count,

    SUM(f.sales) AS total_sales,
    SUM(f.profit) AS total_profit,
    SUM(f.quantity) AS total_quantity,

    CASE
        WHEN SUM(f.sales) = 0 THEN NULL
        ELSE SUM(f.profit) / SUM(f.sales)
    END AS profit_margin_pct,

    AVG(f.discount) AS avg_discount,

    SUM(CASE WHEN f.profit_missing_flag = 1 THEN 1 ELSE 0 END) AS profit_missing_lines,
    SUM(CASE WHEN f.extreme_loss_flag = 1 THEN 1 ELSE 0 END) AS extreme_loss_lines

FROM dbo.fact_sales f
JOIN dbo.dim_date d
    ON f.order_date_key = d.date_key

GROUP BY
    d.year,
    d.month,
    d.month_name;
GO


/* =========================================================
   3) MONTH OVER MONTH ANALYSIS
   Demonstrates window function analytics
========================================================= */

CREATE OR ALTER VIEW dbo.vw_sales_summary_monthly_mom AS
WITH monthly AS (
    SELECT
        year,
        month,
        month_name,
        total_sales,
        total_profit,
        (year * 100 + month) AS year_month
    FROM dbo.vw_sales_summary_monthly
)
SELECT
    year,
    month,
    month_name,

    total_sales,
    total_profit,

    LAG(total_sales) OVER (ORDER BY year_month) AS prior_month_sales,
    LAG(total_profit) OVER (ORDER BY year_month) AS prior_month_profit,

    total_sales - LAG(total_sales) OVER (ORDER BY year_month) AS mom_sales_change,
    total_profit - LAG(total_profit) OVER (ORDER BY year_month) AS mom_profit_change,

    CASE
        WHEN LAG(total_sales) OVER (ORDER BY year_month) IS NULL THEN NULL
        ELSE (total_sales - LAG(total_sales) OVER (ORDER BY year_month))
            / NULLIF(LAG(total_sales) OVER (ORDER BY year_month),0)
    END AS mom_sales_pct

FROM monthly;
GO


/* =========================================================
   4) REGIONAL PERFORMANCE
========================================================= */

CREATE OR ALTER VIEW dbo.vw_regional_sales_monthly AS
SELECT
    d.year,
    d.month,
    d.month_name,
    c.region,

    COUNT(DISTINCT f.order_id) AS order_count,
    SUM(f.sales) AS total_sales,
    SUM(f.profit) AS total_profit,
    SUM(f.quantity) AS total_quantity,

    CASE
        WHEN SUM(f.sales) = 0 THEN NULL
        ELSE SUM(f.profit) / SUM(f.sales)
    END AS profit_margin_pct

FROM dbo.fact_sales f
JOIN dbo.dim_customer c
    ON f.customer_key = c.customer_key
JOIN dbo.dim_date d
    ON f.order_date_key = d.date_key

GROUP BY
    d.year,
    d.month,
    d.month_name,
    c.region;
GO


/* =========================================================
   5) PRODUCT PERFORMANCE
========================================================= */

CREATE OR ALTER VIEW dbo.vw_product_performance AS
SELECT
    p.category,
    p.sub_category,
    p.product_id,
    p.product_name,

    COUNT(DISTINCT f.order_id) AS order_count,
    SUM(f.quantity) AS total_quantity,
    SUM(f.sales) AS total_sales,
    SUM(f.profit) AS total_profit,

    CASE
        WHEN SUM(f.sales) = 0 THEN NULL
        ELSE SUM(f.profit) / SUM(f.sales)
    END AS profit_margin_pct,

    AVG(f.discount) AS avg_discount,

    SUM(CASE WHEN f.profit < 0 THEN 1 ELSE 0 END) AS loss_line_count

FROM dbo.fact_sales f
JOIN dbo.dim_product p
    ON f.product_key = p.product_key

GROUP BY
    p.category,
    p.sub_category,
    p.product_id,
    p.product_name;
GO


/* =========================================================
   6) CUSTOMER SALES
========================================================= */

CREATE OR ALTER VIEW dbo.vw_customer_sales AS
SELECT
    c.customer_id,
    c.customer_name,
    c.segment,
    c.region,
    c.state,
    c.city,

    COUNT(DISTINCT f.order_id) AS order_count,
    SUM(f.sales) AS total_sales,
    SUM(f.profit) AS total_profit,
    SUM(f.quantity) AS total_quantity,

    CASE
        WHEN SUM(f.sales) = 0 THEN NULL
        ELSE SUM(f.profit) / SUM(f.sales)
    END AS profit_margin_pct,

    MAX(d.calendar_date) AS last_order_date

FROM dbo.fact_sales f
JOIN dbo.dim_customer c
    ON f.customer_key = c.customer_key
JOIN dbo.dim_date d
    ON f.order_date_key = d.date_key

GROUP BY
    c.customer_id,
    c.customer_name,
    c.segment,
    c.region,
    c.state,
    c.city;
GO


/* =========================================================
   7) EXTREME LOSS TRANSACTIONS
   Used for anomaly / profit leakage analysis
========================================================= */

CREATE OR ALTER VIEW dbo.vw_extreme_loss_transactions AS
SELECT
    f.sales_key,
    f.order_id,
    f.sales,
    f.profit,
    f.discount,
    f.quantity,
    f.margin_pct,

    d.calendar_date AS order_date,
    d.year,
    d.month,

    c.customer_name,
    c.segment,
    c.region,
    c.state,
    c.city,

    p.category,
    p.sub_category,
    p.product_name

FROM dbo.fact_sales f
JOIN dbo.dim_date d
    ON f.order_date_key = d.date_key
JOIN dbo.dim_customer c
    ON f.customer_key = c.customer_key
JOIN dbo.dim_product p
    ON f.product_key = p.product_key

WHERE f.profit <= -1000;
GO


/* =========================================================
   Smoke Test (sanity check)
========================================================= */

SELECT TOP 5 * FROM dbo.vw_sales_summary_monthly;
SELECT TOP 5 * FROM dbo.vw_regional_sales_monthly;
SELECT TOP 5 * FROM dbo.vw_product_performance;
GO
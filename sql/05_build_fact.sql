/* ============================================================================
   SuperStoreBI Project (SQL Server)
   File: 05_build_fact.sql

   Purpose:
     - Build dbo.fact_sales at grain: 1 row per order line
     - Map business keys to surrogate keys (customer_key, product_key)
     - Convert dates to date_keys (YYYYMMDD)
     - Add computed metrics/flags:
         margin_pct
         profit_missing_flag
         extreme_loss_flag  (profit <= -1000)

   Prerequisites:
     - dbo.staging_superstore loaded
     - dbo.dim_customer, dbo.dim_product, dbo.dim_date built (04)
============================================================================ */

USE SuperStoreBI;
GO

DROP TABLE IF EXISTS dbo.fact_sales;
GO

CREATE TABLE dbo.fact_sales (
    sales_key            INT IDENTITY(1,1) PRIMARY KEY,
    order_id             NVARCHAR(50) NOT NULL,
    row_id               INT NULL,
    order_date_key       INT NOT NULL,
    ship_date_key        INT NOT NULL,
    customer_key         INT NOT NULL,
    product_key          INT NOT NULL,
    ship_mode            NVARCHAR(50) NULL,
    sales                DECIMAL(12,2) NULL,
    quantity             INT NULL,
    discount             DECIMAL(6,3) NULL,
    profit               DECIMAL(12,2) NULL,

    -- Derived fields
    profit_missing_flag  BIT NOT NULL,
    margin_pct           DECIMAL(12,6) NULL,
    extreme_loss_flag    BIT NOT NULL
);
GO

/* =========================================================
   Load fact table (key mapping)
========================================================= */

INSERT INTO dbo.fact_sales (
    order_id,
    row_id,
    order_date_key,
    ship_date_key,
    customer_key,
    product_key,
    ship_mode,
    sales,
    quantity,
    discount,
    profit,
    profit_missing_flag,
    margin_pct,
    extreme_loss_flag
)
SELECT
    s.Order_ID,
    s.Row_ID,
    d_order.date_key AS order_date_key,
    d_ship.date_key  AS ship_date_key,
    c.customer_key,
    p.product_key,
    s.Ship_Mode,
    s.Sales,
    s.Quantity,
    s.Discount,
    s.Profit,

    CASE WHEN s.Profit IS NULL THEN 1 ELSE 0 END AS profit_missing_flag,

    CASE 
        WHEN s.Sales IS NULL OR s.Sales = 0 OR s.Profit IS NULL THEN NULL
        ELSE CAST(s.Profit AS DECIMAL(12,6)) / NULLIF(CAST(s.Sales AS DECIMAL(12,6)), 0)
    END AS margin_pct,

    CASE 
        WHEN s.Profit IS NOT NULL AND s.Profit <= -1000 THEN 1
        ELSE 0
    END AS extreme_loss_flag

FROM dbo.staging_superstore s
JOIN dbo.dim_customer c
    ON s.Customer_ID = c.customer_id
   AND s.Country = c.country
   AND s.City = c.city
   AND s.State = c.state
   AND ISNULL(CAST(s.Postal_Code AS NVARCHAR(50)), '') = ISNULL(c.postal_code, '')
   AND s.Region = c.region
JOIN dbo.dim_product p
    ON s.Product_ID = p.product_id
JOIN dbo.dim_date d_order
    ON s.Order_Date = d_order.calendar_date
JOIN dbo.dim_date d_ship
    ON s.Ship_Date = d_ship.calendar_date;
GO

/* =========================================================
   Indexes (common BI query patterns)
========================================================= */

CREATE INDEX ix_fact_sales_order_date
ON dbo.fact_sales(order_date_key);

CREATE INDEX ix_fact_sales_ship_date
ON dbo.fact_sales(ship_date_key);

CREATE INDEX ix_fact_sales_customer
ON dbo.fact_sales(customer_key);

CREATE INDEX ix_fact_sales_product
ON dbo.fact_sales(product_key);

CREATE INDEX ix_fact_sales_order_id
ON dbo.fact_sales(order_id);
GO

/* =========================================================
   Validation
========================================================= */

SELECT COUNT(*) AS fact_row_count
FROM dbo.fact_sales;

SELECT COUNT(*) AS staging_row_count
FROM dbo.staging_superstore;

-- Should be 0 (key integrity)
SELECT COUNT(*) AS missing_customer_keys
FROM dbo.staging_superstore s
LEFT JOIN dbo.dim_customer c ON s.Customer_ID = c.customer_id
WHERE c.customer_id IS NULL;

SELECT COUNT(*) AS missing_product_keys
FROM dbo.staging_superstore s
LEFT JOIN dbo.dim_product p ON s.Product_ID = p.product_id
WHERE p.product_id IS NULL;

-- Extreme loss count check (for your insight)
SELECT
    SUM(CASE WHEN extreme_loss_flag = 1 THEN 1 ELSE 0 END) AS extreme_loss_rows
FROM dbo.fact_sales;
GO
/* ============================================================================
   SuperStoreBI Project (SQL Server)
   File: 04_build_dimensions.sql

   Purpose:
     Build dimension tables from dbo.staging_superstore

   Dimensions Created:
     - dbo.dim_customer  (1 row per Customer_ID — canonical attributes)
     - dbo.dim_product   (1 row per Product_ID — canonical attributes)
     - dbo.dim_date      (dynamic date range from Order_Date..Ship_Date)

   Notes:
     - Surrogate keys use IDENTITY
     - Canonical dimension attributes chosen deterministically via MAX()
     - DATEFIRST is set in 01_create_database.sql for deterministic weekday/week
============================================================================ */

USE SuperStoreBI;
GO

/* =========================================================
   1) CUSTOMER DIMENSION
========================================================= */

DROP TABLE IF EXISTS dbo.dim_customer;
GO

CREATE TABLE dbo.dim_customer (
    customer_key   INT IDENTITY(1,1) PRIMARY KEY,
    customer_id    NVARCHAR(50) NOT NULL,
    customer_name  NVARCHAR(100),
    segment        NVARCHAR(50),
    country        NVARCHAR(50),
    city           NVARCHAR(50),
    state          NVARCHAR(50),
    postal_code    NVARCHAR(50),
    region         NVARCHAR(50)
);
GO

INSERT INTO dbo.dim_customer (
    customer_id,
    customer_name,
    segment,
    country,
    city,
    state,
    postal_code,
    region
)
SELECT
    Customer_ID,
    MAX(Customer_Name) AS customer_name,
    MAX(Segment)       AS segment,
    MAX(Country)       AS country,
    MAX(City)          AS city,
    MAX(State)         AS state,
    MAX(Postal_Code)   AS postal_code,
    MAX(Region)        AS region
FROM dbo.staging_superstore
GROUP BY 
    Customer_ID,
    Country,
    City,
    State,
    Postal_Code,
    Region;
GO

CREATE NONCLUSTERED INDEX ix_dim_customer_customer_id
ON dbo.dim_customer(customer_id);
GO


/* =========================================================
   2) PRODUCT DIMENSION
========================================================= */

DROP TABLE IF EXISTS dbo.dim_product;
GO

CREATE TABLE dbo.dim_product (
    product_key   INT IDENTITY(1,1) PRIMARY KEY,
    product_id    NVARCHAR(50) NOT NULL,
    category      NVARCHAR(50),
    sub_category  NVARCHAR(50),
    product_name  NVARCHAR(200)
);
GO

INSERT INTO dbo.dim_product (
    product_id,
    category,
    sub_category,
    product_name
)
SELECT
    Product_ID,
    MAX(Category)      AS category,
    MAX(Sub_Category)  AS sub_category,
    MAX(Product_Name)  AS product_name
FROM dbo.staging_superstore
GROUP BY Product_ID;
GO

CREATE UNIQUE INDEX ux_dim_product_product_id
ON dbo.dim_product(product_id);
GO


/* =========================================================
   3) DATE DIMENSION
========================================================= */

DROP TABLE IF EXISTS dbo.dim_date;
GO

CREATE TABLE dbo.dim_date (
    date_key       INT PRIMARY KEY,      -- YYYYMMDD
    calendar_date  DATE NOT NULL,
    [year]         INT NOT NULL,
    [quarter]      INT NOT NULL,
    [month]        INT NOT NULL,
    month_name     NVARCHAR(20) NOT NULL,
    day_of_month   INT NOT NULL,
    day_of_week    INT NOT NULL,
    week_of_year   INT NOT NULL
);
GO

-- IMPORTANT: keep variables + CTE in the SAME batch (no GO in between)
DECLARE @min_date DATE = (SELECT MIN(Order_Date) FROM dbo.staging_superstore);
DECLARE @max_date DATE = (SELECT MAX(Ship_Date)  FROM dbo.staging_superstore);

IF @min_date IS NULL OR @max_date IS NULL
BEGIN
    THROW 50001, 'staging_superstore is empty. Load data before building dimensions.', 1;
END;

;WITH date_series AS (
    SELECT @min_date AS d
    UNION ALL
    SELECT DATEADD(DAY, 1, d)
    FROM date_series
    WHERE d < @max_date
)
INSERT INTO dbo.dim_date (
    date_key,
    calendar_date,
    [year],
    [quarter],
    [month],
    month_name,
    day_of_month,
    day_of_week,
    week_of_year
)
SELECT
    CONVERT(INT, FORMAT(d, 'yyyyMMdd')) AS date_key,
    d                                  AS calendar_date,
    YEAR(d)                            AS [year],
    DATEPART(QUARTER, d)               AS [quarter],
    MONTH(d)                           AS [month],
    DATENAME(MONTH, d)                 AS month_name,
    DAY(d)                             AS day_of_month,
    DATEPART(WEEKDAY, d)               AS day_of_week,
    DATEPART(WEEK, d)                  AS week_of_year
FROM date_series
OPTION (MAXRECURSION 0);
GO


/* =========================================================
   4) VALIDATION
========================================================= */

SELECT 'dim_customer' AS table_name, COUNT(*) AS row_count
FROM dbo.dim_customer
UNION ALL
SELECT 'dim_product', COUNT(*)
FROM dbo.dim_product
UNION ALL
SELECT 'dim_date', COUNT(*)
FROM dbo.dim_date;
GO

SELECT COUNT(DISTINCT Customer_ID) AS distinct_customer_ids_in_staging
FROM dbo.staging_superstore;
GO
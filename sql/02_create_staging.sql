/* ============================================================================
   SuperStoreBI Project (SQL Server)
   File: 02_create_staging.sql

   Purpose:
     - Create dbo.staging_superstore for scripted loads (PATH B)

   IMPORTANT:
     - If you are using PATH A (SSMS Import Flat File Wizard), DO NOT run this.
       The wizard must CREATE dbo.staging_superstore itself.
============================================================================ */

USE SuperStoreBI;
GO

DROP TABLE IF EXISTS dbo.staging_superstore;
GO

CREATE TABLE dbo.staging_superstore (
    Row_ID         INT            NULL,
    Order_ID       NVARCHAR(50)   NULL,
    Order_Date     DATE           NULL,
    Ship_Date      DATE           NULL,
    Ship_Mode      NVARCHAR(50)   NULL,
    Customer_ID    NVARCHAR(50)   NULL,
    Customer_Name  NVARCHAR(100)  NULL,
    Segment        NVARCHAR(50)   NULL,
    Country        NVARCHAR(50)   NULL,
    City           NVARCHAR(50)   NULL,
    State          NVARCHAR(50)   NULL,
    Postal_Code    NVARCHAR(50)   NULL,
    Region         NVARCHAR(50)   NULL,
    Product_ID     NVARCHAR(50)   NULL,
    Category       NVARCHAR(50)   NULL,
    Sub_Category   NVARCHAR(50)   NULL,
    Product_Name   NVARCHAR(200)  NULL,
    Sales          DECIMAL(12,2)  NULL,
    Quantity       INT            NULL,
    Discount       DECIMAL(6,3)   NULL,
    Profit         DECIMAL(12,2)  NULL
);
GO
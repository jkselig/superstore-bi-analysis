/* ============================================================================
   SuperStoreBI Project (SQL Server)
   File: 03A_wizard_import_instructions.sql

   Purpose:
     - Instructions for PATH A (SSMS Import Flat File Wizard)

   Steps:
     1) In SSMS, right-click SuperStoreBI → Tasks → Import Flat File...
     2) Select: Sample - Superstore.csv
     3) Destination table name: dbo.staging_superstore
     4) Ensure Profit allows NULL
     5) Finish import
     6) Run the checks below
============================================================================ */

USE SuperStoreBI;
GO

SELECT COUNT(*) AS staging_row_count
FROM dbo.staging_superstore;

SELECT TOP (10) *
FROM dbo.staging_superstore
ORDER BY Order_Date, Order_ID, Row_ID;
GO
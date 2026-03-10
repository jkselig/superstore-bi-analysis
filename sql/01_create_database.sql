/* ============================================================================
   SuperStoreBI Project (SQL Server) — Tableau “Sample - Superstore” Dataset
   File: 01_create_database.sql

   Purpose:
     - Create the SuperStoreBI database (if missing)
     - Set standard session options for deterministic results

   Run Options:

   PATH A (Recommended — simplest / realistic):
     01_create_database.sql
     (SSMS Import Flat File Wizard → import CSV into dbo.staging_superstore)
     04_build_dimensions.sql
     05_build_fact.sql
     06_create_views.sql
     07_eda_analysis.sql

   PATH B (Optional — script-only load):
     01_create_database.sql
     02_create_staging.sql
     03_load_staging_bulk.sql
     04_build_dimensions.sql
     05_build_fact.sql
     06_create_views.sql
     07_eda_analysis.sql
============================================================================ */

IF DB_ID('SuperStoreBI') IS NULL
BEGIN
    CREATE DATABASE SuperStoreBI;
END
GO

USE SuperStoreBI;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Make weekday/week-of-year logic deterministic
SET DATEFIRST 7;  -- Sunday = 1 (common US convention)
GO
/* ============================================================================
   SuperStoreBI Project (SQL Server)
   File: 03_load_staging_bulk.sql

   Purpose:
     - Load Sample - Superstore.csv into dbo.staging_superstore via BULK INSERT

   Use:
     - PATH B only (script-only load)

   Notes:
     - BULK INSERT can fail on some CSV variants due to quoted commas, permissions,
       or regional decimal formatting.
     - If BULK INSERT gives conversion errors, use PATH A (wizard) instead.
============================================================================ */

USE SuperStoreBI;
GO

-- Requires dbo.staging_superstore to exist (run 02_create_staging.sql first)
TRUNCATE TABLE dbo.staging_superstore;
GO

DECLARE @FilePath NVARCHAR(4000) =
N'C:\data\Sample - Superstore.csv';  -- TODO: change me

DECLARE @sql NVARCHAR(MAX) =
N'BULK INSERT dbo.staging_superstore
  FROM ''' + REPLACE(@FilePath, '''', '''''') + N'''
  WITH (
      FIRSTROW = 2,
      FIELDTERMINATOR = '','',
      ROWTERMINATOR = ''0x0a'',
      TABLOCK,
      CODEPAGE = ''65001''
  );';

EXEC sys.sp_executesql @sql;
GO

SELECT COUNT(*) AS staging_row_count
FROM dbo.staging_superstore;

SELECT TOP (10) *
FROM dbo.staging_superstore
ORDER BY Order_Date, Order_ID, Row_ID;
GO
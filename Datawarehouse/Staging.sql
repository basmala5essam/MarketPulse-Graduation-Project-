-- Active: 1791130657023@@196.221.145.204@1433@MarketPulseDW@staging
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
    EXEC('staging');

IF OBJECT_ID('staging.market', 'U') IS NULL
CREATE TABLE staging.market (
    ticker           NVARCHAR(255),
    [date]           NVARCHAR(255),
    [open]           NVARCHAR(255),
    high             NVARCHAR(255),
    low              NVARCHAR(255),
    [close]          NVARCHAR(255),
    volume           NVARCHAR(255),
    [return]         NVARCHAR(255),
    next_day_return  NVARCHAR(255)
);

DROP TABLE bronze.monthly_risk;

SELECT *
FROM sys.schemas

-- Manual reset only. load_to_sql.py already truncates before loading.

-- Data for staging.market is loaded from Python (Datawarehouse/load_to_sql.py),

SELECT COUNT(*) AS total_rows FROM staging.news_clean;
SELECT TOP 10 * FROM staging.companies;
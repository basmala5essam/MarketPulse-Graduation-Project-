-- =====================================================================
-- 03_gold.sql : Gold layer (star schema for Power BI), built from the silver layer
--
-- DIMENSIONS
--   gold.dim_company   from silver.companies
--   gold.dim_date      generated, one row per day from 2021-01-01 to 2025-12-31
--                      (trading days come from the dates in silver.market_prices)
-- FACTS (one per remaining silver table)
--   fact_market_prices, fact_market_features, fact_news, fact_article_sentiment, fact_news_tickers,
--   fact_events, fact_fundamentals, fact_monthly_risk, fact_risk_summary, fact_correlation, fact_benchmark_prices
-- VIEW
--   gold.fact_market_daily   market_features + monthly_risk + benchmark_prices joined on company and date
--
-- Rules used for every fact:
--   * gold does no cleaning and no casting: columns are copied as they are from silver (silver has the right types)
--   * only silver rows with has_invalid_value = 0 are loaded
--   * the quality flag columns (has_missing_value, has_outlier_value, quality_missing_*) are NOT copied to gold
--   * every fact is refreshed with MERGE (insert new, update changed, delete rows that left silver)
--
-- Run with:  python run_sql.py 03_gold.sql     (batches are split only on lines that contain just GO)
-- =====================================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('CREATE SCHEMA gold');
GO

-- Cleanup of objects from the previous version of this script (the old fact tables had a different shape).
-- It does nothing if they do not exist. You can delete the next line after the first successful run.
IF OBJECT_ID('gold.fact_market_daily', 'U') IS NOT NULL DROP TABLE gold.fact_market_daily;   -- only the old TABLE, never the view
GO

-- The fact tables used to carry quality flag columns. A fact table that still has them is dropped here
-- and rebuilt below (gold is rebuilt from silver, so this is safe). It does nothing once the tables are clean.
IF COL_LENGTH('gold.fact_market_prices', 'has_missing_value') IS NOT NULL DROP TABLE gold.fact_market_prices;
IF COL_LENGTH('gold.fact_market_features', 'has_missing_value') IS NOT NULL DROP TABLE gold.fact_market_features;
IF COL_LENGTH('gold.fact_news', 'has_missing_value') IS NOT NULL DROP TABLE gold.fact_news;
IF COL_LENGTH('gold.fact_article_sentiment', 'has_missing_value') IS NOT NULL DROP TABLE gold.fact_article_sentiment;
IF COL_LENGTH('gold.fact_news_tickers', 'has_missing_value') IS NOT NULL DROP TABLE gold.fact_news_tickers;
IF COL_LENGTH('gold.fact_events', 'has_missing_value') IS NOT NULL DROP TABLE gold.fact_events;
IF COL_LENGTH('gold.fact_fundamentals', 'has_missing_value') IS NOT NULL DROP TABLE gold.fact_fundamentals;
IF COL_LENGTH('gold.fact_monthly_risk', 'has_missing_value') IS NOT NULL DROP TABLE gold.fact_monthly_risk;
IF COL_LENGTH('gold.fact_risk_summary', 'has_missing_value') IS NOT NULL DROP TABLE gold.fact_risk_summary;
IF COL_LENGTH('gold.fact_correlation', 'has_missing_value') IS NOT NULL DROP TABLE gold.fact_correlation;
IF COL_LENGTH('gold.fact_benchmark_prices', 'has_missing_value') IS NOT NULL DROP TABLE gold.fact_benchmark_prices;
GO

-- =====================================================================
-- DIMENSION: dim_company
-- =====================================================================
IF OBJECT_ID('gold.dim_company', 'U') IS NULL
CREATE TABLE gold.dim_company (
    company_key   INT IDENTITY(1,1) NOT NULL,   -- surrogate key used by the fact tables
    ticker        NVARCHAR(10)  NOT NULL,       -- business key
    company_name  NVARCHAR(150),
    sector        NVARCHAR(50),
    industry      NVARCHAR(100),
    currency      NVARCHAR(10),
    cik           INT,
    CONSTRAINT PK_gold_dim_company PRIMARY KEY (company_key),
    CONSTRAINT UQ_gold_dim_company_ticker UNIQUE (ticker)
);
GO

MERGE gold.dim_company AS tgt
USING (
    SELECT ticker, company_name, sector, industry, currency, cik
    FROM silver.companies
) AS src
    ON tgt.ticker = src.ticker
WHEN MATCHED THEN
    UPDATE SET
        tgt.company_name = src.company_name,
        tgt.sector = src.sector,
        tgt.industry = src.industry,
        tgt.currency = src.currency,
        tgt.cik = src.cik
WHEN NOT MATCHED THEN
    INSERT (ticker, company_name, sector, industry, currency, cik)
    VALUES (src.ticker, src.company_name, src.sector, src.industry, src.currency, src.cik)
;   -- the semicolon that ends the MERGE statement
GO

-- =====================================================================
-- DIMENSION: dim_date  (generated)
-- =====================================================================
IF OBJECT_ID('gold.dim_date', 'U') IS NULL
CREATE TABLE gold.dim_date (
    date_key                  INT          NOT NULL,   -- yyyymmdd, for example 20240131
    [date]                    DATE         NOT NULL,
    [year]                    SMALLINT     NOT NULL,
    [quarter]                 TINYINT      NOT NULL,   -- 1 to 4
    month_number              TINYINT      NOT NULL,   -- 1 to 12
    month_name                NVARCHAR(10) NOT NULL,   -- January ... December
    year_month                CHAR(7)      NOT NULL,   -- yyyy-mm, for example 2024-01
    is_trading_day            BIT          NOT NULL,
    is_month_end_trading_day  BIT          NOT NULL,
    CONSTRAINT PK_gold_dim_date PRIMARY KEY (date_key),
    CONSTRAINT UQ_gold_dim_date_date UNIQUE ([date])
);
GO

WITH digits AS (
    SELECT n FROM (VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)) AS v(n)
),
numbers AS (
    -- 10000 consecutive numbers from 0 to 9999, built from digits only (no system tables needed)
    SELECT d0.n + 10 * d1.n + 100 * d2.n + 1000 * d3.n AS n
    FROM digits AS d0
    CROSS JOIN digits AS d1
    CROSS JOIN digits AS d2
    CROSS JOIN digits AS d3
),
calendar AS (
    -- one row for every calendar day between the two dates
    SELECT DATEADD(DAY, n, CAST('2021-01-01' AS DATE)) AS d
    FROM numbers
    WHERE n <= DATEDIFF(DAY, '2021-01-01', '2025-12-31')
),
trading_dates AS (
    -- the distinct dates that exist in the market data
    SELECT DISTINCT [date] AS d
    FROM silver.market_prices
),
trading_ranked AS (
    -- rank 1 = the last trading day of its month
    SELECT d,
           ROW_NUMBER() OVER (PARTITION BY YEAR(d), MONTH(d) ORDER BY d DESC) AS rank_in_month
    FROM trading_dates
),
dim AS (
    SELECT
        YEAR(c.d) * 10000 + MONTH(c.d) * 100 + DAY(c.d)                  AS date_key,
        c.d                                                              AS [date],
        CAST(YEAR(c.d) AS SMALLINT)                                      AS [year],
        CAST(DATEPART(QUARTER, c.d) AS TINYINT)                          AS [quarter],
        CAST(MONTH(c.d) AS TINYINT)                                      AS month_number,
        CHOOSE(MONTH(c.d), 'January', 'February', 'March', 'April', 'May', 'June',
                           'July', 'August', 'September', 'October', 'November', 'December') AS month_name,
        LEFT(CONVERT(CHAR(10), c.d, 23), 7)                              AS year_month,
        CAST(CASE WHEN t.d IS NOT NULL THEN 1 ELSE 0 END AS BIT)         AS is_trading_day,
        CAST(CASE WHEN t.rank_in_month = 1 THEN 1 ELSE 0 END AS BIT)     AS is_month_end_trading_day
    FROM calendar AS c
    LEFT JOIN trading_ranked AS t
        ON t.d = c.d
)
MERGE gold.dim_date AS tgt
USING dim AS src
    ON tgt.date_key = src.date_key
WHEN MATCHED THEN
    UPDATE SET
        tgt.[date] = src.[date],
        tgt.[year] = src.[year],
        tgt.[quarter] = src.[quarter],
        tgt.month_number = src.month_number,
        tgt.month_name = src.month_name,
        tgt.year_month = src.year_month,
        tgt.is_trading_day = src.is_trading_day,
        tgt.is_month_end_trading_day = src.is_month_end_trading_day
WHEN NOT MATCHED THEN
    INSERT (date_key, [date], [year], [quarter], month_number, month_name, year_month, is_trading_day, is_month_end_trading_day)
    VALUES (src.date_key, src.[date], src.[year], src.[quarter], src.month_number, src.month_name, src.year_month, src.is_trading_day, src.is_month_end_trading_day)
;   -- the semicolon that ends the MERGE statement
GO

-- =====================================================================
-- FACT: fact_market_prices   (from silver.market_prices)
-- =====================================================================
IF OBJECT_ID('gold.fact_market_prices', 'U') IS NULL
CREATE TABLE gold.fact_market_prices (
    [company_key] INT NOT NULL,
    [date_key] INT NOT NULL,
    [open] DECIMAL(18,4) NULL,
    [high] DECIMAL(18,4) NULL,
    [low] DECIMAL(18,4) NULL,
    [close] DECIMAL(18,4) NULL,
    [volume] BIGINT NULL,
    [return] DECIMAL(18,6) NULL,
    [next_day_return] DECIMAL(18,6) NULL,
    CONSTRAINT PK_gold_fact_market_prices PRIMARY KEY ([company_key], [date_key]),
    CONSTRAINT FK_fact_market_prices_company_key FOREIGN KEY ([company_key]) REFERENCES gold.dim_company (company_key),
    CONSTRAINT FK_fact_market_prices_date_key FOREIGN KEY ([date_key]) REFERENCES gold.dim_date (date_key)
);
GO

MERGE gold.fact_market_prices AS tgt
USING (
    SELECT
        c.company_key AS [company_key],
        d1.date_key AS [date_key],
        s.[open] AS [open],
        s.[high] AS [high],
        s.[low] AS [low],
        s.[close] AS [close],
        s.[volume] AS [volume],
        s.[return] AS [return],
        s.[next_day_return] AS [next_day_return]
    FROM silver.market_prices AS s
    JOIN gold.dim_company AS c ON c.ticker = s.[ticker]
    JOIN gold.dim_date AS d1 ON d1.[date] = s.[date]
    WHERE s.has_invalid_value = 0
) AS src
    ON tgt.[company_key] = src.[company_key] AND tgt.[date_key] = src.[date_key]
WHEN MATCHED THEN
    UPDATE SET
        tgt.[open] = src.[open],
        tgt.[high] = src.[high],
        tgt.[low] = src.[low],
        tgt.[close] = src.[close],
        tgt.[volume] = src.[volume],
        tgt.[return] = src.[return],
        tgt.[next_day_return] = src.[next_day_return]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([company_key], [date_key], [open], [high], [low], [close], [volume], [return], [next_day_return])
    VALUES (src.[company_key], src.[date_key], src.[open], src.[high], src.[low], src.[close], src.[volume], src.[return], src.[next_day_return])
WHEN NOT MATCHED BY SOURCE THEN
    DELETE
;   -- the semicolon that ends the MERGE statement
GO

-- =====================================================================
-- FACT: fact_market_features   (from silver.market_features)
-- =====================================================================
IF OBJECT_ID('gold.fact_market_features', 'U') IS NULL
CREATE TABLE gold.fact_market_features (
    [company_key] INT NOT NULL,
    [date_key] INT NOT NULL,
    [open] DECIMAL(18,4) NULL,
    [high] DECIMAL(18,4) NULL,
    [low] DECIMAL(18,4) NULL,
    [close] DECIMAL(18,4) NULL,
    [volume] BIGINT NULL,
    [return] DECIMAL(18,6) NULL,
    [cumulative_return] DECIMAL(18,6) NULL,
    [ma20] DECIMAL(18,4) NULL,
    [ma50] DECIMAL(18,4) NULL,
    [ma200] DECIMAL(18,4) NULL,
    [rolling_volatility] DECIMAL(18,6) NULL,
    [volume_change] DECIMAL(18,6) NULL,
    [volume_ma20] DECIMAL(18,4) NULL,
    CONSTRAINT PK_gold_fact_market_features PRIMARY KEY ([company_key], [date_key]),
    CONSTRAINT FK_fact_market_features_company_key FOREIGN KEY ([company_key]) REFERENCES gold.dim_company (company_key),
    CONSTRAINT FK_fact_market_features_date_key FOREIGN KEY ([date_key]) REFERENCES gold.dim_date (date_key)
);
GO

MERGE gold.fact_market_features AS tgt
USING (
    SELECT
        c.company_key AS [company_key],
        d1.date_key AS [date_key],
        s.[open] AS [open],
        s.[high] AS [high],
        s.[low] AS [low],
        s.[close] AS [close],
        s.[volume] AS [volume],
        s.[return] AS [return],
        s.[cumulative_return] AS [cumulative_return],
        s.[ma20] AS [ma20],
        s.[ma50] AS [ma50],
        s.[ma200] AS [ma200],
        s.[rolling_volatility] AS [rolling_volatility],
        s.[volume_change] AS [volume_change],
        s.[volume_ma20] AS [volume_ma20]
    FROM silver.market_features AS s
    JOIN gold.dim_company AS c ON c.ticker = s.[ticker]
    JOIN gold.dim_date AS d1 ON d1.[date] = s.[date]
    WHERE s.has_invalid_value = 0
) AS src
    ON tgt.[company_key] = src.[company_key] AND tgt.[date_key] = src.[date_key]
WHEN MATCHED THEN
    UPDATE SET
        tgt.[open] = src.[open],
        tgt.[high] = src.[high],
        tgt.[low] = src.[low],
        tgt.[close] = src.[close],
        tgt.[volume] = src.[volume],
        tgt.[return] = src.[return],
        tgt.[cumulative_return] = src.[cumulative_return],
        tgt.[ma20] = src.[ma20],
        tgt.[ma50] = src.[ma50],
        tgt.[ma200] = src.[ma200],
        tgt.[rolling_volatility] = src.[rolling_volatility],
        tgt.[volume_change] = src.[volume_change],
        tgt.[volume_ma20] = src.[volume_ma20]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([company_key], [date_key], [open], [high], [low], [close], [volume], [return], [cumulative_return], [ma20], [ma50], [ma200], [rolling_volatility], [volume_change], [volume_ma20])
    VALUES (src.[company_key], src.[date_key], src.[open], src.[high], src.[low], src.[close], src.[volume], src.[return], src.[cumulative_return], src.[ma20], src.[ma50], src.[ma200], src.[rolling_volatility], src.[volume_change], src.[volume_ma20])
WHEN NOT MATCHED BY SOURCE THEN
    DELETE
;   -- the semicolon that ends the MERGE statement
GO

-- =====================================================================
-- FACT: fact_article_sentiment   (from silver.artcl_senti)
-- =====================================================================
IF OBJECT_ID('gold.fact_article_sentiment', 'U') IS NULL
CREATE TABLE gold.fact_article_sentiment (
    [published_date_key] INT NULL,
    [article_id] INT NOT NULL,
    [published_at] DATETIME NULL,
    [updated_at] DATETIME NULL,
    [title] NVARCHAR(MAX) NULL,
    [author] NVARCHAR(255) NULL,
    [source] NVARCHAR(100) NULL,
    [url] NVARCHAR(MAX) NULL,
    [symbols] NVARCHAR(MAX) NULL,
    [finbert_label] NVARCHAR(20) NULL,
    [finbert_positive] FLOAT NULL,
    [finbert_negative] FLOAT NULL,
    [finbert_neutral] FLOAT NULL,
    [finbert_score] FLOAT NULL,
    CONSTRAINT PK_gold_fact_article_sentiment PRIMARY KEY ([article_id]),
    CONSTRAINT FK_fact_article_sentiment_published_date_key FOREIGN KEY ([published_date_key]) REFERENCES gold.dim_date (date_key)
);
GO

MERGE gold.fact_article_sentiment AS tgt
USING (
    SELECT
        d1.date_key AS [published_date_key],
        s.[article_id] AS [article_id],
        s.[published_at] AS [published_at],
        s.[updated_at] AS [updated_at],
        s.[title] AS [title],
        s.[author] AS [author],
        s.[source] AS [source],
        s.[url] AS [url],
        s.[symbols] AS [symbols],
        s.[finbert_label] AS [finbert_label],
        s.[finbert_positive] AS [finbert_positive],
        s.[finbert_negative] AS [finbert_negative],
        s.[finbert_neutral] AS [finbert_neutral],
        s.[finbert_score] AS [finbert_score]
    FROM silver.artcl_senti AS s
    LEFT JOIN gold.dim_date AS d1 ON d1.[date] = CAST(s.[published_at] AS DATE)
    WHERE s.has_invalid_value = 0
) AS src
    ON tgt.[article_id] = src.[article_id]
WHEN MATCHED THEN
    UPDATE SET
        tgt.[published_date_key] = src.[published_date_key],
        tgt.[published_at] = src.[published_at],
        tgt.[updated_at] = src.[updated_at],
        tgt.[title] = src.[title],
        tgt.[author] = src.[author],
        tgt.[source] = src.[source],
        tgt.[url] = src.[url],
        tgt.[symbols] = src.[symbols],
        tgt.[finbert_label] = src.[finbert_label],
        tgt.[finbert_positive] = src.[finbert_positive],
        tgt.[finbert_negative] = src.[finbert_negative],
        tgt.[finbert_neutral] = src.[finbert_neutral],
        tgt.[finbert_score] = src.[finbert_score]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([published_date_key], [article_id], [published_at], [updated_at], [title], [author], [source], [url], [symbols], [finbert_label], [finbert_positive], [finbert_negative], [finbert_neutral], [finbert_score])
    VALUES (src.[published_date_key], src.[article_id], src.[published_at], src.[updated_at], src.[title], src.[author], src.[source], src.[url], src.[symbols], src.[finbert_label], src.[finbert_positive], src.[finbert_negative], src.[finbert_neutral], src.[finbert_score])
WHEN NOT MATCHED BY SOURCE THEN
    DELETE
;   -- the semicolon that ends the MERGE statement
GO

-- =====================================================================
-- FACT: fact_news_tickers   (from silver.news_tickers)
-- =====================================================================
IF OBJECT_ID('gold.fact_news_tickers', 'U') IS NULL
CREATE TABLE gold.fact_news_tickers (
    [company_key] INT NOT NULL,
    [published_date_key] INT NULL,
    [reaction_date_key] INT NULL,
    [article_id] INT NOT NULL,
    [published_at] DATETIME NULL,
    [n_symbols_total] INT NULL,
    [n_project_tickers] INT NULL,
    CONSTRAINT PK_gold_fact_news_tickers PRIMARY KEY ([article_id], [company_key]),
    CONSTRAINT FK_fact_news_tickers_company_key FOREIGN KEY ([company_key]) REFERENCES gold.dim_company (company_key),
    CONSTRAINT FK_fact_news_tickers_published_date_key FOREIGN KEY ([published_date_key]) REFERENCES gold.dim_date (date_key),
    CONSTRAINT FK_fact_news_tickers_reaction_date_key FOREIGN KEY ([reaction_date_key]) REFERENCES gold.dim_date (date_key)
);
GO

MERGE gold.fact_news_tickers AS tgt
USING (
    SELECT
        c.company_key AS [company_key],
        d1.date_key AS [published_date_key],
        d2.date_key AS [reaction_date_key],
        s.[article_id] AS [article_id],
        s.[published_at] AS [published_at],
        s.[n_symbols_total] AS [n_symbols_total],
        s.[n_project_tickers] AS [n_project_tickers]
    FROM silver.news_tickers AS s
    JOIN gold.dim_company AS c ON c.ticker = s.[ticker]
    LEFT JOIN gold.dim_date AS d1 ON d1.[date] = CAST(s.[published_at] AS DATE)
    LEFT JOIN gold.dim_date AS d2 ON d2.[date] = CAST(s.[reaction_date] AS DATE)
    WHERE s.has_invalid_value = 0
) AS src
    ON tgt.[article_id] = src.[article_id] AND tgt.[company_key] = src.[company_key]
WHEN MATCHED THEN
    UPDATE SET
        tgt.[published_date_key] = src.[published_date_key],
        tgt.[reaction_date_key] = src.[reaction_date_key],
        tgt.[published_at] = src.[published_at],
        tgt.[n_symbols_total] = src.[n_symbols_total],
        tgt.[n_project_tickers] = src.[n_project_tickers]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([company_key], [published_date_key], [reaction_date_key], [article_id], [published_at], [n_symbols_total], [n_project_tickers])
    VALUES (src.[company_key], src.[published_date_key], src.[reaction_date_key], src.[article_id], src.[published_at], src.[n_symbols_total], src.[n_project_tickers])
WHEN NOT MATCHED BY SOURCE THEN
    DELETE
;   -- the semicolon that ends the MERGE statement
GO

-- =====================================================================
-- FACT: fact_events   (from silver.events)
-- =====================================================================
IF OBJECT_ID('gold.fact_events', 'U') IS NULL
CREATE TABLE gold.fact_events (
    [company_key] INT NOT NULL,
    [event_date_key] INT NULL,
    [reaction_date_key] INT NULL,
    [event_id] INT NOT NULL,
    [event_type] NVARCHAR(25) NULL,
    [after_close] BIT NULL,
    [eps_estimate] DECIMAL(18,4) NULL,
    [eps_actual] DECIMAL(18,4) NULL,
    [surprise_pct] DECIMAL(18,4) NULL,
    [items] NVARCHAR(100) NULL,
    [items_description] NVARCHAR(MAX) NULL,
    [accession_number] NVARCHAR(255) NULL,
    CONSTRAINT PK_gold_fact_events PRIMARY KEY ([event_id]),
    CONSTRAINT FK_fact_events_company_key FOREIGN KEY ([company_key]) REFERENCES gold.dim_company (company_key),
    CONSTRAINT FK_fact_events_event_date_key FOREIGN KEY ([event_date_key]) REFERENCES gold.dim_date (date_key),
    CONSTRAINT FK_fact_events_reaction_date_key FOREIGN KEY ([reaction_date_key]) REFERENCES gold.dim_date (date_key)
);
GO

MERGE gold.fact_events AS tgt
USING (
    SELECT
        c.company_key AS [company_key],
        d1.date_key AS [event_date_key],
        d2.date_key AS [reaction_date_key],
        s.[event_id] AS [event_id],
        s.[event_type] AS [event_type],
        s.[after_close] AS [after_close],
        s.[eps_estimate] AS [eps_estimate],
        s.[eps_actual] AS [eps_actual],
        s.[surprise_pct] AS [surprise_pct],
        s.[items] AS [items],
        s.[items_description] AS [items_description],
        s.[accession_number] AS [accession_number]
    FROM silver.events AS s
    JOIN gold.dim_company AS c ON c.ticker = s.[ticker]
    LEFT JOIN gold.dim_date AS d1 ON d1.[date] = s.[event_date]
    LEFT JOIN gold.dim_date AS d2 ON d2.[date] = s.[reaction_date]
    WHERE s.has_invalid_value = 0
) AS src
    ON tgt.[event_id] = src.[event_id]
WHEN MATCHED THEN
    UPDATE SET
        tgt.[company_key] = src.[company_key],
        tgt.[event_date_key] = src.[event_date_key],
        tgt.[reaction_date_key] = src.[reaction_date_key],
        tgt.[event_type] = src.[event_type],
        tgt.[after_close] = src.[after_close],
        tgt.[eps_estimate] = src.[eps_estimate],
        tgt.[eps_actual] = src.[eps_actual],
        tgt.[surprise_pct] = src.[surprise_pct],
        tgt.[items] = src.[items],
        tgt.[items_description] = src.[items_description],
        tgt.[accession_number] = src.[accession_number]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([company_key], [event_date_key], [reaction_date_key], [event_id], [event_type], [after_close], [eps_estimate], [eps_actual], [surprise_pct], [items], [items_description], [accession_number])
    VALUES (src.[company_key], src.[event_date_key], src.[reaction_date_key], src.[event_id], src.[event_type], src.[after_close], src.[eps_estimate], src.[eps_actual], src.[surprise_pct], src.[items], src.[items_description], src.[accession_number])
WHEN NOT MATCHED BY SOURCE THEN
    DELETE
;   -- the semicolon that ends the MERGE statement
GO

-- =====================================================================
-- FACT: fact_fundamentals   (from silver.fundamentals)
-- =====================================================================
IF OBJECT_ID('gold.fact_fundamentals', 'U') IS NULL
CREATE TABLE gold.fact_fundamentals (
    [company_key] INT NOT NULL,
    [period_end_date_key] INT NULL,
    [filing_date_key] INT NULL,
    [period_end] DATE NOT NULL,
    [filing_date] DATE NULL,
    [revenue] DECIMAL(18,4) NULL,
    [net_income] DECIMAL(18,4) NULL,
    [eps_diluted] DECIMAL(18,4) NULL,
    [total_assets] DECIMAL(18,4) NULL,
    [equity] DECIMAL(18,4) NULL,
    [profit_margin] DECIMAL(18,4) NULL,
    CONSTRAINT PK_gold_fact_fundamentals PRIMARY KEY ([company_key], [period_end]),
    CONSTRAINT FK_fact_fundamentals_company_key FOREIGN KEY ([company_key]) REFERENCES gold.dim_company (company_key),
    CONSTRAINT FK_fact_fundamentals_period_end_date_key FOREIGN KEY ([period_end_date_key]) REFERENCES gold.dim_date (date_key),
    CONSTRAINT FK_fact_fundamentals_filing_date_key FOREIGN KEY ([filing_date_key]) REFERENCES gold.dim_date (date_key)
);
GO

MERGE gold.fact_fundamentals AS tgt
USING (
    SELECT
        c.company_key AS [company_key],
        d1.date_key AS [period_end_date_key],
        d2.date_key AS [filing_date_key],
        s.[period_end] AS [period_end],
        s.[filing_date] AS [filing_date],
        s.[revenue] AS [revenue],
        s.[net_income] AS [net_income],
        s.[eps_diluted] AS [eps_diluted],
        s.[total_assets] AS [total_assets],
        s.[equity] AS [equity],
        s.[profit_margin] AS [profit_margin]
    FROM silver.fundamentals AS s
    JOIN gold.dim_company AS c ON c.ticker = s.[ticker]
    LEFT JOIN gold.dim_date AS d1 ON d1.[date] = s.[period_end]
    LEFT JOIN gold.dim_date AS d2 ON d2.[date] = s.[filing_date]
    WHERE s.has_invalid_value = 0
) AS src
    ON tgt.[company_key] = src.[company_key] AND tgt.[period_end] = src.[period_end]
WHEN MATCHED THEN
    UPDATE SET
        tgt.[period_end_date_key] = src.[period_end_date_key],
        tgt.[filing_date_key] = src.[filing_date_key],
        tgt.[filing_date] = src.[filing_date],
        tgt.[revenue] = src.[revenue],
        tgt.[net_income] = src.[net_income],
        tgt.[eps_diluted] = src.[eps_diluted],
        tgt.[total_assets] = src.[total_assets],
        tgt.[equity] = src.[equity],
        tgt.[profit_margin] = src.[profit_margin]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([company_key], [period_end_date_key], [filing_date_key], [period_end], [filing_date], [revenue], [net_income], [eps_diluted], [total_assets], [equity], [profit_margin])
    VALUES (src.[company_key], src.[period_end_date_key], src.[filing_date_key], src.[period_end], src.[filing_date], src.[revenue], src.[net_income], src.[eps_diluted], src.[total_assets], src.[equity], src.[profit_margin])
WHEN NOT MATCHED BY SOURCE THEN
    DELETE
;   -- the semicolon that ends the MERGE statement
GO

-- =====================================================================
-- FACT: fact_monthly_risk   (from silver.monthly_risk)
-- =====================================================================
IF OBJECT_ID('gold.fact_monthly_risk', 'U') IS NULL
CREATE TABLE gold.fact_monthly_risk (
    [company_key] INT NOT NULL,
    [date_key] INT NOT NULL,
    [volatility_30d] DECIMAL(18,6) NULL,
    [max_drawdown] DECIMAL(18,6) NULL,
    CONSTRAINT PK_gold_fact_monthly_risk PRIMARY KEY ([company_key], [date_key]),
    CONSTRAINT FK_fact_monthly_risk_company_key FOREIGN KEY ([company_key]) REFERENCES gold.dim_company (company_key),
    CONSTRAINT FK_fact_monthly_risk_date_key FOREIGN KEY ([date_key]) REFERENCES gold.dim_date (date_key)
);
GO

MERGE gold.fact_monthly_risk AS tgt
USING (
    SELECT
        c.company_key AS [company_key],
        d1.date_key AS [date_key],
        s.[volatility_30d] AS [volatility_30d],
        s.[max_drawdown] AS [max_drawdown]
    FROM silver.monthly_risk AS s
    JOIN gold.dim_company AS c ON c.ticker = s.[ticker]
    JOIN gold.dim_date AS d1 ON d1.[date] = s.[date]
    WHERE s.has_invalid_value = 0
) AS src
    ON tgt.[company_key] = src.[company_key] AND tgt.[date_key] = src.[date_key]
WHEN MATCHED THEN
    UPDATE SET
        tgt.[volatility_30d] = src.[volatility_30d],
        tgt.[max_drawdown] = src.[max_drawdown]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([company_key], [date_key], [volatility_30d], [max_drawdown])
    VALUES (src.[company_key], src.[date_key], src.[volatility_30d], src.[max_drawdown])
WHEN NOT MATCHED BY SOURCE THEN
    DELETE
;   -- the semicolon that ends the MERGE statement
GO

-- =====================================================================
-- FACT: fact_risk_summary   (from silver.risk_metrics)
-- =====================================================================
IF OBJECT_ID('gold.fact_risk_summary', 'U') IS NULL
CREATE TABLE gold.fact_risk_summary (
    [company_key] INT NOT NULL,
    [daily_volatility] DECIMAL(18,8) NULL,
    [annualized_volatility] DECIMAL(18,8) NULL,
    [max_drawdown] DECIMAL(18,8) NULL,
    [sharpe_ratio] DECIMAL(18,8) NULL,
    [var_95_hist] DECIMAL(18,8) NULL,
    [var_95_param] DECIMAL(18,8) NULL,
    [var_99_hist] DECIMAL(18,8) NULL,
    [var_99_param] DECIMAL(18,8) NULL,
    CONSTRAINT PK_gold_fact_risk_summary PRIMARY KEY ([company_key]),
    CONSTRAINT FK_fact_risk_summary_company_key FOREIGN KEY ([company_key]) REFERENCES gold.dim_company (company_key)
);
GO

MERGE gold.fact_risk_summary AS tgt
USING (
    SELECT
        c.company_key AS [company_key],
        s.[daily_volatility] AS [daily_volatility],
        s.[annualized_volatility] AS [annualized_volatility],
        s.[max_drawdown] AS [max_drawdown],
        s.[sharpe_ratio] AS [sharpe_ratio],
        s.[var_95_hist] AS [var_95_hist],
        s.[var_95_param] AS [var_95_param],
        s.[var_99_hist] AS [var_99_hist],
        s.[var_99_param] AS [var_99_param]
    FROM silver.risk_metrics AS s
    JOIN gold.dim_company AS c ON c.ticker = s.[ticker]
    WHERE s.has_invalid_value = 0
) AS src
    ON tgt.[company_key] = src.[company_key]
WHEN MATCHED THEN
    UPDATE SET
        tgt.[daily_volatility] = src.[daily_volatility],
        tgt.[annualized_volatility] = src.[annualized_volatility],
        tgt.[max_drawdown] = src.[max_drawdown],
        tgt.[sharpe_ratio] = src.[sharpe_ratio],
        tgt.[var_95_hist] = src.[var_95_hist],
        tgt.[var_95_param] = src.[var_95_param],
        tgt.[var_99_hist] = src.[var_99_hist],
        tgt.[var_99_param] = src.[var_99_param]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([company_key], [daily_volatility], [annualized_volatility], [max_drawdown], [sharpe_ratio], [var_95_hist], [var_95_param], [var_99_hist], [var_99_param])
    VALUES (src.[company_key], src.[daily_volatility], src.[annualized_volatility], src.[max_drawdown], src.[sharpe_ratio], src.[var_95_hist], src.[var_95_param], src.[var_99_hist], src.[var_99_param])
WHEN NOT MATCHED BY SOURCE THEN
    DELETE
;   -- the semicolon that ends the MERGE statement
GO

-- =====================================================================
-- FACT: fact_correlation   (from silver.correlation_matrix)
-- =====================================================================
IF OBJECT_ID('gold.fact_correlation', 'U') IS NULL
CREATE TABLE gold.fact_correlation (
    [company_key] INT NOT NULL,
    [peer_company_key] INT NOT NULL,
    [correlation] DECIMAL(18,8) NULL,
    CONSTRAINT PK_gold_fact_correlation PRIMARY KEY ([company_key], [peer_company_key]),
    CONSTRAINT FK_fact_correlation_company_key FOREIGN KEY ([company_key]) REFERENCES gold.dim_company (company_key),
    CONSTRAINT FK_fact_correlation_peer_company_key FOREIGN KEY ([peer_company_key]) REFERENCES gold.dim_company (company_key)
);
GO

MERGE gold.fact_correlation AS tgt
USING (
    SELECT
        c.company_key AS [company_key],
        p.company_key AS [peer_company_key],
        v.corr_value AS [correlation]
    FROM silver.correlation_matrix AS s
    CROSS APPLY (VALUES
        ('AAPL', s.[AAPL]),
        ('AMZN', s.[AMZN]),
        ('JNJ', s.[JNJ]),
        ('JPM', s.[JPM]),
        ('KO', s.[KO]),
        ('LLY', s.[LLY]),
        ('MSFT', s.[MSFT]),
        ('NVDA', s.[NVDA]),
        ('TSLA', s.[TSLA]),
        ('XOM', s.[XOM])
    ) AS v(peer_ticker, corr_value)
    JOIN gold.dim_company AS c ON c.ticker = s.[ticker]
    JOIN gold.dim_company AS p ON p.ticker = v.peer_ticker
    WHERE s.has_invalid_value = 0
) AS src
    ON tgt.[company_key] = src.[company_key] AND tgt.[peer_company_key] = src.[peer_company_key]
WHEN MATCHED THEN
    UPDATE SET
        tgt.[correlation] = src.[correlation]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([company_key], [peer_company_key], [correlation])
    VALUES (src.[company_key], src.[peer_company_key], src.[correlation])
WHEN NOT MATCHED BY SOURCE THEN
    DELETE
;   -- the semicolon that ends the MERGE statement
GO

-- =====================================================================
-- FACT: fact_benchmark_prices   (from silver.benchmark_prices)
-- =====================================================================
IF OBJECT_ID('gold.fact_benchmark_prices', 'U') IS NULL
CREATE TABLE gold.fact_benchmark_prices (
    [date_key] INT NOT NULL,
    [benchmark_symbol] NVARCHAR(10) NOT NULL,
    [close] DECIMAL(18,8) NULL,
    [return] DECIMAL(18,8) NULL,
    CONSTRAINT PK_gold_fact_benchmark_prices PRIMARY KEY ([benchmark_symbol], [date_key]),
    CONSTRAINT FK_fact_benchmark_prices_date_key FOREIGN KEY ([date_key]) REFERENCES gold.dim_date (date_key)
);
GO

MERGE gold.fact_benchmark_prices AS tgt
USING (
    SELECT
        d1.date_key AS [date_key],
        s.[symbol] AS [benchmark_symbol],
        s.[close] AS [close],
        s.[return] AS [return]
    FROM silver.benchmark_prices AS s
    JOIN gold.dim_date AS d1 ON d1.[date] = s.[date]
    WHERE s.has_invalid_value = 0
) AS src
    ON tgt.[benchmark_symbol] = src.[benchmark_symbol] AND tgt.[date_key] = src.[date_key]
WHEN MATCHED THEN
    UPDATE SET
        tgt.[close] = src.[close],
        tgt.[return] = src.[return]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([date_key], [benchmark_symbol], [close], [return])
    VALUES (src.[date_key], src.[benchmark_symbol], src.[close], src.[return])
WHEN NOT MATCHED BY SOURCE THEN
    DELETE
;   -- the semicolon that ends the MERGE statement
GO

-- =====================================================================
-- VIEW: fact_market_daily = market_features + monthly_risk + benchmark_prices (joined on company and date)
-- A view keeps one copy of the data. Risk columns are empty on days that have no monthly_risk row.
-- =====================================================================
CREATE OR ALTER VIEW gold.fact_market_daily AS
WITH benchmark AS (
    -- if more than one benchmark symbol is ever loaded, use the one with the most rows
    SELECT benchmark_symbol, date_key, [close], [return]
    FROM gold.fact_benchmark_prices
    WHERE benchmark_symbol = (
        SELECT TOP (1) benchmark_symbol
        FROM gold.fact_benchmark_prices
        GROUP BY benchmark_symbol
        ORDER BY COUNT(*) DESC, benchmark_symbol
    )
)
SELECT
    f.date_key,
    f.company_key,
    f.[open], f.high, f.low, f.[close], f.volume,
    f.[return], f.cumulative_return,
    f.ma20, f.ma50, f.ma200,
    f.rolling_volatility, f.volume_change, f.volume_ma20,
    r.volatility_30d,
    r.max_drawdown,
    b.benchmark_symbol,
    b.[close]  AS benchmark_close,
    b.[return] AS benchmark_return
FROM gold.fact_market_features AS f
LEFT JOIN gold.fact_monthly_risk AS r
    ON r.company_key = f.company_key AND r.date_key = f.date_key
LEFT JOIN benchmark AS b
    ON b.date_key = f.date_key;
GO

-- =====================================================================
-- CHECKS
-- =====================================================================

-- 1) Row counts: gold rows against the valid rows of the matching silver table
SELECT 'dim_company' AS gold_table, (SELECT COUNT(*) FROM gold.dim_company) AS gold_rows, (SELECT COUNT(*) FROM silver.companies) AS silver_rows
UNION ALL SELECT 'dim_date', (SELECT COUNT(*) FROM gold.dim_date), 1826
UNION ALL SELECT 'fact_market_prices', (SELECT COUNT(*) FROM gold.fact_market_prices), (SELECT COUNT(*) FROM silver.market_prices WHERE has_invalid_value = 0)
UNION ALL SELECT 'fact_market_features', (SELECT COUNT(*) FROM gold.fact_market_features), (SELECT COUNT(*) FROM silver.market_features WHERE has_invalid_value = 0)
UNION ALL SELECT 'fact_article_sentiment', (SELECT COUNT(*) FROM gold.fact_article_sentiment), (SELECT COUNT(*) FROM silver.artcl_senti WHERE has_invalid_value = 0)
UNION ALL SELECT 'fact_news_tickers', (SELECT COUNT(*) FROM gold.fact_news_tickers), (SELECT COUNT(*) FROM silver.news_tickers WHERE has_invalid_value = 0)
UNION ALL SELECT 'fact_events', (SELECT COUNT(*) FROM gold.fact_events), (SELECT COUNT(*) FROM silver.events WHERE has_invalid_value = 0)
UNION ALL SELECT 'fact_fundamentals', (SELECT COUNT(*) FROM gold.fact_fundamentals), (SELECT COUNT(*) FROM silver.fundamentals WHERE has_invalid_value = 0)
UNION ALL SELECT 'fact_monthly_risk', (SELECT COUNT(*) FROM gold.fact_monthly_risk), (SELECT COUNT(*) FROM silver.monthly_risk WHERE has_invalid_value = 0)
UNION ALL SELECT 'fact_risk_summary', (SELECT COUNT(*) FROM gold.fact_risk_summary), (SELECT COUNT(*) FROM silver.risk_metrics WHERE has_invalid_value = 0)
UNION ALL SELECT 'fact_correlation', (SELECT COUNT(*) FROM gold.fact_correlation), (SELECT COUNT(*) * 10 FROM silver.correlation_matrix WHERE has_invalid_value = 0)
UNION ALL SELECT 'fact_benchmark_prices', (SELECT COUNT(*) FROM gold.fact_benchmark_prices), (SELECT COUNT(*) FROM silver.benchmark_prices WHERE has_invalid_value = 0)
;
GO

-- 2) dim_date: total_days 1826, month_end_trading_days 60 (12 months x 5 years)
SELECT
    COUNT(*)                                     AS total_days,
    SUM(CAST(is_trading_day AS INT))             AS trading_days,
    SUM(CAST(is_month_end_trading_day AS INT))   AS month_end_trading_days,
    MIN([date])                                  AS first_date,
    MAX([date])                                  AS last_date
FROM gold.dim_date;
GO

-- 3) Facts whose date column did not find a day in dim_date (the date_key stays empty)

SELECT 'fact_article_sentiment.published_date_key' AS date_key_column, COUNT(*) AS fact_rows, SUM(CASE WHEN published_date_key IS NULL THEN 1 ELSE 0 END) AS rows_without_date_key FROM gold.fact_article_sentiment
UNION ALL
SELECT 'fact_news_tickers.published_date_key' AS date_key_column, COUNT(*) AS fact_rows, SUM(CASE WHEN published_date_key IS NULL THEN 1 ELSE 0 END) AS rows_without_date_key FROM gold.fact_news_tickers
UNION ALL
SELECT 'fact_news_tickers.reaction_date_key' AS date_key_column, COUNT(*) AS fact_rows, SUM(CASE WHEN reaction_date_key IS NULL THEN 1 ELSE 0 END) AS rows_without_date_key FROM gold.fact_news_tickers
UNION ALL
SELECT 'fact_events.event_date_key' AS date_key_column, COUNT(*) AS fact_rows, SUM(CASE WHEN event_date_key IS NULL THEN 1 ELSE 0 END) AS rows_without_date_key FROM gold.fact_events
UNION ALL
SELECT 'fact_events.reaction_date_key' AS date_key_column, COUNT(*) AS fact_rows, SUM(CASE WHEN reaction_date_key IS NULL THEN 1 ELSE 0 END) AS rows_without_date_key FROM gold.fact_events
UNION ALL
SELECT 'fact_fundamentals.period_end_date_key' AS date_key_column, COUNT(*) AS fact_rows, SUM(CASE WHEN period_end_date_key IS NULL THEN 1 ELSE 0 END) AS rows_without_date_key FROM gold.fact_fundamentals
UNION ALL
SELECT 'fact_fundamentals.filing_date_key' AS date_key_column, COUNT(*) AS fact_rows, SUM(CASE WHEN filing_date_key IS NULL THEN 1 ELSE 0 END) AS rows_without_date_key FROM gold.fact_fundamentals;
GO

-- 4) Trading days in silver.market_prices that fall outside 2021-2025 (expected: no rows)
SELECT DISTINCT [date] AS market_date_not_in_dim
FROM silver.market_prices
WHERE [date] NOT IN (SELECT [date] FROM gold.dim_date);
GO

-- 5) The joined view: how many rows got risk and benchmark values
SELECT
    COUNT(*)                                                      AS rows_in_view,
    SUM(CASE WHEN volatility_30d IS NOT NULL THEN 1 ELSE 0 END)   AS rows_with_risk,
    SUM(CASE WHEN benchmark_close IS NOT NULL THEN 1 ELSE 0 END)  AS rows_with_benchmark
FROM gold.fact_market_daily;
GO
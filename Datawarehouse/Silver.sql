
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
    EXEC('CREATE SCHEMA silver');

-- ONE-TIME RESET of the tables whose definition was fixed below
-- (silver is rebuilt from bronze, so this is safe). Delete these 4 lines after the first successful run.
DROP TABLE IF EXISTS silver.events;
DROP TABLE IF EXISTS silver.monthly_risk;
DROP TABLE IF EXISTS silver.correlation_matrix;
DROP TABLE IF EXISTS silver.benchmark_prices;

IF OBJECT_ID('silver.market_prices', 'U') IS NULL
CREATE TABLE silver.market_prices (
    ticker           NVARCHAR(10)    NOT NULL,
    [date]           DATE           NOT NULL,
    [open]           DECIMAL(18,4)  NOT NULL,
    high             DECIMAL(18,4)  NOT NULL,
    low              DECIMAL(18,4)  NOT NULL,
    [close]          DECIMAL(18,4)  NOT NULL,
    volume           BIGINT         NOT NULL,
    [return]         DECIMAL(18,6)  NULL,      -- empty on the first day of each stock
    next_day_return  DECIMAL(18,6)  NULL,      -- empty on the last day of each stock
    has_missing_value BIT NOT NULL DEFAULT 0,
    has_invalid_value BIT NOT NULL DEFAULT 0,
    has_outlier_value BIT NOT NULL DEFAULT 0,
    CONSTRAINT PK_silver_market_prices PRIMARY KEY (ticker, [date])
);
Go



WITH mkt_latest AS (
    -- keep only the newest copy of each (ticker, date) rows without a usable key are left in bronze
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY UPPER(LTRIM(RTRIM(ticker))), TRY_CAST(NULLIF(LTRIM(RTRIM([date])), '') AS DATE)
            ORDER BY bronze_id DESC
        ) AS rn
    FROM bronze.market
    WHERE NULLIF(LTRIM(RTRIM(ticker)), '') IS NOT NULL
      AND TRY_CAST(NULLIF(LTRIM(RTRIM([date])), '') AS DATE) IS NOT NULL
),
mkt_cleaned AS (
    -- trim text, turn '' into NULL, convert types keep the raw text to tell "empty" from "invalid"
    SELECT
        UPPER(LTRIM(RTRIM(ticker))) AS ticker,
        TRY_CAST(NULLIF(LTRIM(RTRIM([date])), '') AS DATE) AS [date],
        TRY_CAST(NULLIF(LTRIM(RTRIM([open])),  '') AS DECIMAL(18,4)) AS [open],
        NULLIF(LTRIM(RTRIM([open])),  '') AS raw_open,
        TRY_CAST(NULLIF(LTRIM(RTRIM(high)),    '') AS DECIMAL(18,4)) AS high,
        NULLIF(LTRIM(RTRIM(high)),    '') AS raw_high,
        TRY_CAST(NULLIF(LTRIM(RTRIM(low)),     '') AS DECIMAL(18,4)) AS low,
        NULLIF(LTRIM(RTRIM(low)),     '') AS raw_low,
        TRY_CAST(NULLIF(LTRIM(RTRIM([close])), '') AS DECIMAL(18,4)) AS [close],
        NULLIF(LTRIM(RTRIM([close])), '') AS raw_close,
        -- via FLOAT so values like "1.2E+08" or "123.0" still convert
        TRY_CAST(TRY_CAST(NULLIF(LTRIM(RTRIM(volume)), '') AS FLOAT) AS BIGINT) AS volume,
        NULLIF(LTRIM(RTRIM(volume)), '') AS raw_volume,
        -- via FLOAT so tiny values written like "1e-05" still convert
        TRY_CAST(TRY_CAST(NULLIF(LTRIM(RTRIM([return])), '') AS FLOAT) AS DECIMAL(18,6)) AS [return],
        NULLIF(LTRIM(RTRIM([return])), '') AS raw_return,
        TRY_CAST(TRY_CAST(NULLIF(LTRIM(RTRIM(next_day_return)), '') AS FLOAT) AS DECIMAL(18,6)) AS next_day_return,
        NULLIF(LTRIM(RTRIM(next_day_return)), '') AS raw_next_day_return
    FROM mkt_latest
    WHERE rn = 1
),
flagged AS (
    SELECT
        ticker, [date], [open], high, low, [close], volume, [return], next_day_return,
        -- missing: a required price/volume was empty (an empty return is normal on the first/last day, so it is not counted)
        CASE WHEN
            raw_open IS NULL OR raw_high IS NULL OR raw_low IS NULL OR raw_close IS NULL OR raw_volume IS NULL
        THEN 1 ELSE 0 END AS has_missing_value,
        -- invalid: text that could not be converted, or values that break basic market rules
        CASE WHEN
            (raw_open IS NOT NULL AND [open] IS NULL)
        OR (raw_high IS NOT NULL AND high IS NULL)
        OR (raw_low IS NOT NULL AND low IS NULL)
        OR (raw_close IS NOT NULL AND [close] IS NULL)
        OR (raw_volume IS NOT NULL AND volume IS NULL)
        OR (raw_return IS NOT NULL AND [return] IS NULL)
        OR (raw_next_day_return IS NOT NULL AND next_day_return IS NULL)
        OR high < low
        OR [open] <= 0 OR high <= 0 OR low <= 0 OR [close] <= 0
        OR volume < 0
        THEN 1 ELSE 0 END AS has_invalid_value,
        -- outlier: a daily move above 25% (a flag only, the row is kept change 0.25 if you want)
        CASE WHEN ABS([return]) > 0.25 OR ABS(next_day_return) > 0.25
        THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS has_outlier_value
    FROM mkt_cleaned
)
MERGE silver.market_prices AS tgt
USING flagged AS src
    ON tgt.ticker = src.ticker AND tgt.[date] = src.[date]
WHEN MATCHED THEN
    UPDATE SET
        tgt.[open] = src.[open],
        tgt.high = src.high,
        tgt.low = src.low,
        tgt.[close] = src.[close],
        tgt.volume = src.volume,
        tgt.[return] = src.[return],
        tgt.next_day_return = src.next_day_return,
        tgt.has_missing_value = src.has_missing_value,
        tgt.has_invalid_value = src.has_invalid_value,
        tgt.has_outlier_value = src.has_outlier_value
WHEN NOT MATCHED THEN
    INSERT (ticker, [date], [open], high, low, [close], volume, [return], next_day_return, has_missing_value, has_invalid_value, has_outlier_value)
    VALUES (src.ticker, src.[date], src.[open], src.high, src.low, src.[close], src.volume, src.[return], src.next_day_return, src.has_missing_value, src.has_invalid_value, src.has_outlier_value);
GO
 
-- Checks after loading
SELECT COUNT(*) AS silver_rows FROM silver.market_prices;
 
SELECT
    SUM(CAST(has_missing_value AS INT)) AS rows_missing,
    SUM(CAST(has_invalid_value AS INT)) AS rows_invalid,
    SUM(CAST(has_outlier_value AS INT)) AS rows_outlier
FROM silver.market_prices;
GO
 

IF OBJECT_ID('silver.news', 'U') IS NULL
CREATE TABLE silver.news (
    news_id INT NOT NULL,
    article_id INT,
    ticker NVARCHAR(10),
    published_at DATETIME,
    [date] DATE,
    title NVARCHAR(MAX),
    summary NVARCHAR(MAX),
    [source] NVARCHAR(20),
    url NVARCHAR(MAX),
    n_project_tickers INT,
    n_symbols_total INT,
    finbert_label NVARCHAR(20),
    finbert_positive FLOAT,
    finbert_negative FLOAT,
    finbert_neutral FLOAT,
    finbert_score FLOAT,
    has_missing_value BIT NOT NULL DEFAULT 0,
    has_invalid_value BIT NOT NULL DEFAULT 0,
    has_outlier_value BIT NOT NULL DEFAULT 0,
    CONSTRAINT PK_silver_news PRIMARY KEY (news_id)
);
GO 

WITH news_latest AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY (LTRIM(RTRIM(news_id)))
            ORDER BY bronze_id DESC
        ) AS rn
    FROM bronze.news
    WHERE NULLIF(LTRIM(RTRIM(news_id)), '') IS NOT NULL
),
news_cleaned AS (
    SELECT
        TRY_CAST(NULLIF(LTRIM(RTRIM(news_id)), '') AS INT) AS news_id,
        TRY_CAST(NULLIF(LTRIM(RTRIM(article_id)), '') AS INT) AS article_id,
        UPPER(LTRIM(RTRIM(ticker))) AS ticker,
        TRY_CAST(NULLIF(LTRIM(RTRIM(published_at)), '') AS DATETIME) AS published_at,
        TRY_CAST(NULLIF(LTRIM(RTRIM([date])), '') AS DATE) AS [date],
        title, summary, [source], url,
        TRY_CAST(NULLIF(LTRIM(RTRIM(n_project_tickers)), '') AS INT) AS n_project_tickers,
        TRY_CAST(NULLIF(LTRIM(RTRIM(n_symbols_total)), '') AS INT) AS n_symbols_total,
        finbert_label,
        TRY_CAST(NULLIF(LTRIM(RTRIM(finbert_positive)), '') AS FLOAT) AS finbert_positive,
        TRY_CAST(NULLIF(LTRIM(RTRIM(finbert_negative)), '') AS FLOAT) AS finbert_negative,
        TRY_CAST(NULLIF(LTRIM(RTRIM(finbert_neutral)), '') AS FLOAT) AS finbert_neutral,
        TRY_CAST(NULLIF(LTRIM(RTRIM(finbert_score)), '') AS FLOAT) AS finbert_score
    FROM news_latest
    WHERE rn = 1
),
news_flagged AS (
    SELECT
        news_id, article_id, ticker, published_at, [date], title, summary, [source], url,
        n_project_tickers, n_symbols_total, finbert_label, finbert_positive, finbert_negative, finbert_neutral, finbert_score,
        CASE WHEN
            news_id IS NULL OR article_id IS NULL OR ticker IS NULL OR [date] IS NULL OR n_project_tickers IS NULL OR n_symbols_total IS NULL OR finbert_label IS NULL OR finbert_positive IS NULL OR finbert_negative IS NULL OR finbert_neutral IS NULL OR finbert_score IS NULL
        THEN 1 ELSE 0 END AS has_missing_value,
        CASE WHEN
            (news_id IS NOT NULL AND TRY_CAST(news_id AS INT) IS NULL)
        OR (article_id IS NOT NULL AND TRY_CAST(article_id AS INT) IS NULL)
        OR (ticker IS NOT NULL AND LEN(ticker) > 10)
        OR (published_at IS NOT NULL AND TRY_CAST(published_at AS DATETIME) IS NULL)
        OR ([date] IS NOT NULL AND TRY_CAST([date] AS DATE) IS NULL)
        OR (n_project_tickers IS NOT NULL AND TRY_CAST(n_project_tickers AS INT) IS NULL)
        OR (n_symbols_total IS NOT NULL AND TRY_CAST(n_symbols_total AS INT) IS NULL)
        OR (finbert_label IS NOT NULL AND LEN(finbert_label) > 20)
        OR (finbert_positive IS NOT NULL AND TRY_CAST(finbert_positive AS FLOAT) IS NULL)
        OR (finbert_negative IS NOT NULL AND TRY_CAST(finbert_negative AS FLOAT) IS NULL)
        OR (finbert_neutral IS NOT NULL AND TRY_CAST(finbert_neutral AS FLOAT) IS NULL)
        OR (finbert_score IS NOT NULL AND TRY_CAST(finbert_score AS FLOAT) IS NULL)
        THEN 1 ELSE 0 END AS has_invalid_value,
        CASE WHEN
            finbert_score < -1.0 OR finbert_score > 1.0
        THEN 1 ELSE 0 END AS has_outlier_value
    FROM news_cleaned
)
MERGE silver.news AS tgt
USING news_flagged AS src
    ON tgt.news_id = src.news_id
WHEN MATCHED THEN
    UPDATE SET
        tgt.article_id = src.article_id,
        tgt.ticker = src.ticker,
        tgt.published_at = src.published_at,
        tgt.[date] = src.[date],
        tgt.title = src.title,
        tgt.summary = src.summary,
        tgt.[source] = src.[source],
        tgt.url = src.url,
        tgt.n_project_tickers = src.n_project_tickers,
        tgt.n_symbols_total = src.n_symbols_total,
        tgt.finbert_label = src.finbert_label,
        tgt.finbert_positive = src.finbert_positive,
        tgt.finbert_negative = src.finbert_negative,
        tgt.finbert_neutral = src.finbert_neutral,
        tgt.finbert_score = src.finbert_score,
        tgt.has_missing_value = src.has_missing_value,
        tgt.has_invalid_value = src.has_invalid_value,
        tgt.has_outlier_value = src.has_outlier_value
WHEN NOT MATCHED THEN
    INSERT (news_id, article_id, ticker, published_at, [date], title, summary, [source], url, n_project_tickers, n_symbols_total, finbert_label, finbert_positive, finbert_negative, finbert_neutral, finbert_score, has_missing_value, has_invalid_value, has_outlier_value)
    VALUES (src.news_id, src.article_id, src.ticker, src.published_at, src.[date], src.title, src.summary, src.[source], src.url, src.n_project_tickers, src.n_symbols_total, src.finbert_label, src.finbert_positive, src.finbert_negative, src.finbert_neutral, src.finbert_score, src.has_missing_value, src.has_invalid_value, src.has_outlier_value);
GO

SELECT
    SUM(CAST(has_missing_value AS INT)) AS rows_missing,
    SUM(CAST(has_invalid_value AS INT)) AS rows_invalid,
    SUM(CAST(has_outlier_value AS INT)) AS rows_outlier
FROM silver.NEWS;
GO
 


 IF OBJECT_ID('silver.artcl_senti', 'U') IS NULL
CREATE TABLE silver.artcl_senti (
    article_id INT NOT NULL,
    published_at DATETIME,
    updated_at DATETIME,
    title NVARCHAR(MAX),
    summary NVARCHAR(MAX),
    author NVARCHAR(50),
    [source] NVARCHAR(25),
    url NVARCHAR(MAX),
    symbols_raw NVARCHAR(MAX),
    symbols NVARCHAR(MAX),
    finbert_label NVARCHAR(20),
    finbert_positive NVARCHAR(255),
    finbert_negative NVARCHAR(255),
    finbert_neutral NVARCHAR(255),
    finbert_score NVARCHAR(255),
    sentiment_text NVARCHAR(MAX),
    quality_missing_title NVARCHAR(25),
    quality_missing_published_at NVARCHAR(25),
    has_missing_value BIT NOT NULL DEFAULT 0,
    has_invalid_value BIT NOT NULL DEFAULT 0,
    has_outlier_value BIT NOT NULL DEFAULT 0,
    CONSTRAINT PK_silver_artcl_senti PRIMARY KEY (article_id)
);


WITH artcl_latest AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY (LTRIM(RTRIM(article_id)))
            ORDER BY bronze_id DESC
        ) AS rn
    FROM bronze.artcl_senti
    WHERE NULLIF(LTRIM(RTRIM(article_id)), '') IS NOT NULL
),
artcl_cleaned AS (
    SELECT
        TRY_CAST(NULLIF(LTRIM(RTRIM(article_id)), '') AS INT) AS article_id,
        TRY_CAST(NULLIF(LTRIM(RTRIM(published_at)), '') AS DATETIME) AS published_at,
        TRY_CAST(NULLIF(LTRIM(RTRIM(updated_at)), '') AS DATETIME) AS updated_at,
        title, summary, author, [source], url, symbols_raw, symbols,
        finbert_label,
        TRY_CAST(NULLIF(LTRIM(RTRIM(finbert_positive)), '') AS FLOAT) AS finbert_positive,
        TRY_CAST(NULLIF(LTRIM(RTRIM(finbert_negative)), '') AS FLOAT) AS finbert_negative,
        TRY_CAST(NULLIF(LTRIM(RTRIM(finbert_neutral)), '') AS FLOAT) AS finbert_neutral,
        TRY_CAST(NULLIF(LTRIM(RTRIM(finbert_score)), '') AS FLOAT) AS finbert_score,
        sentiment_text, quality_missing_title, quality_missing_published_at
    FROM artcl_latest
    WHERE rn = 1
),
artcl_flagged AS (
    SELECT
        article_id, published_at, updated_at, title, summary, author, [source], url, symbols_raw, symbols,
        finbert_label, finbert_positive, finbert_negative, finbert_neutral, finbert_score,
        sentiment_text, quality_missing_title, quality_missing_published_at,
        CASE WHEN
            article_id IS NULL OR title IS NULL  OR author IS NULL OR url IS NULL OR symbols_raw IS NULL OR symbols IS NULL OR finbert_label IS NULL OR finbert_positive IS NULL OR finbert_negative IS NULL OR finbert_neutral IS NULL OR finbert_score IS NULL
        THEN 1 ELSE 0 END AS has_missing_value,
        CASE WHEN
            (article_id IS NOT NULL AND TRY_CAST(article_id AS INT) IS NULL)
        OR (published_at IS NOT NULL AND TRY_CAST(published_at AS DATETIME) IS NULL)
        OR (updated_at IS NOT NULL AND TRY_CAST(updated_at AS DATETIME) IS NULL)
        OR (finbert_positive IS NOT NULL AND TRY_CAST(finbert_positive AS FLOAT) IS NULL)
        OR (finbert_negative IS NOT NULL AND TRY_CAST(finbert_negative AS FLOAT) IS NULL)
        OR (finbert_neutral IS NOT NULL AND TRY_CAST(finbert_neutral AS FLOAT) IS NULL)
        OR (finbert_score IS NOT NULL AND TRY_CAST(finbert_score AS FLOAT) IS NULL)
        THEN 1 ELSE 0 END AS has_invalid_value,
        CASE WHEN
            finbert_score < -1.0 OR finbert_score > 1.0
        THEN 1 ELSE 0 END AS has_outlier_value
    FROM artcl_cleaned
)
MERGE silver.artcl_senti AS tgt
USING artcl_flagged AS src
    ON tgt.article_id = src.article_id
WHEN MATCHED THEN
    UPDATE SET
        tgt.published_at = src.published_at,
        tgt.updated_at = src.updated_at,
        tgt.title = src.title,
        tgt.summary = src.summary,
        tgt.author = src.author,
        tgt.[source] = src.[source],
        tgt.url = src.url,
        tgt.symbols_raw = src.symbols_raw,
        tgt.symbols = src.symbols,
        tgt.finbert_label = src.finbert_label,
        tgt.finbert_positive = src.finbert_positive,
        tgt.finbert_negative = src.finbert_negative,
        tgt.finbert_neutral = src.finbert_neutral,
        tgt.finbert_score = src.finbert_score,
        tgt.sentiment_text = src.sentiment_text,
        tgt.quality_missing_title = src.quality_missing_title,
        tgt.quality_missing_published_at = src.quality_missing_published_at,
        tgt.has_missing_value = src.has_missing_value,
        tgt.has_invalid_value = src.has_invalid_value,
        tgt.has_outlier_value = src.has_outlier_value
WHEN NOT MATCHED THEN
    INSERT (article_id, published_at, updated_at, title, summary, author, [source], url, symbols_raw, symbols, finbert_label, finbert_positive, finbert_negative, finbert_neutral, finbert_score, sentiment_text, quality_missing_title, quality_missing_published_at, has_missing_value, has_invalid_value, has_outlier_value)
    VALUES (src.article_id, src.published_at, src.updated_at, src.title, src.summary, src.author, src.[source], src.url, src.symbols_raw, src.symbols, src.finbert_label, src.finbert_positive, src.finbert_negative, src.finbert_neutral, src.finbert_score, src.sentiment_text, src.quality_missing_title, src.quality_missing_published_at, src.has_missing_value, src.has_invalid_value, src.has_outlier_value);
GO 

SELECT
    SUM(CAST(has_missing_value AS INT)) AS rows_missing,
    SUM(CAST(has_invalid_value AS INT)) AS rows_invalid,
    SUM(CAST(has_outlier_value AS INT)) AS rows_outlier
FROM silver.artcl_senti;
GO
 

 IF OBJECT_ID('silver.companies', 'U') IS NULL
CREATE TABLE silver.companies (
    ticker NVARCHAR(10) NOT NULL ,
    company_name NVARCHAR(150) NOT NULL,
    sector NVARCHAR(50) NOT NULL,
    industry NVARCHAR(100) NOT NULL,
    currency NVARCHAR(10) NOT NULL,
    cik INT ,
    has_missing_value BIT NOT NULL DEFAULT 0,
    has_invalid_value BIT NOT NULL DEFAULT 0,
    has_outlier_value BIT NOT NULL DEFAULT 0,
    CONSTRAINT PK_silver_companies PRIMARY KEY (ticker)
);
WITH comp_latest AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY (LTRIM(RTRIM(ticker)))
            ORDER BY bronze_id DESC
        ) AS rn
    FROM bronze.companies
    WHERE NULLIF(LTRIM(RTRIM(ticker)), '') IS NOT NULL
),
comp_cleaned AS (
    SELECT
        UPPER(LTRIM(RTRIM(ticker))) AS ticker,
        company_name, sector, industry, currency,
        TRY_CAST(NULLIF(LTRIM(RTRIM(cik)), '') AS INT) AS cik
    FROM comp_latest
    WHERE rn = 1
),
comp_flagged AS (
    SELECT
        ticker, company_name, sector, industry, currency, cik,
        CASE WHEN
            ticker IS NULL OR company_name IS NULL OR sector IS NULL OR industry IS NULL OR currency IS NULL OR cik IS NULL
        THEN 1 ELSE 0 END AS has_missing_value,
        CASE WHEN
            (ticker IS NOT NULL AND LEN(ticker) > 10)
        OR (company_name IS NOT NULL AND LEN(company_name) > 150)
        OR (sector IS NOT NULL AND LEN(sector) > 50)
        OR (industry IS NOT NULL AND LEN(industry) > 100)
        OR (currency IS NOT NULL AND LEN(currency) > 10)
        OR (cik IS NOT NULL AND TRY_CAST(cik AS INT) IS NULL)
        THEN 1 ELSE 0 END AS has_invalid_value,
        CASE WHEN
            cik < 0
        THEN 1 ELSE 0 END AS has_outlier_value
    FROM comp_cleaned
)
MERGE silver.companies AS tgt 
USING comp_flagged AS src
    ON tgt.ticker = src.ticker
WHEN MATCHED THEN
    UPDATE SET
        tgt.company_name = src.company_name,
        tgt.sector = src.sector,
        tgt.industry = src.industry,
        tgt.currency = src.currency,
        tgt.cik = src.cik,
        tgt.has_missing_value = src.has_missing_value,
        tgt.has_invalid_value = src.has_invalid_value,
        tgt.has_outlier_value = src.has_outlier_value
WHEN NOT MATCHED THEN
    INSERT (ticker, company_name, sector, industry, currency, cik, has_missing_value, has_invalid_value, has_outlier_value)
    VALUES (src.ticker, src.company_name, src.sector, src.industry, src.currency, src.cik, src.has_missing_value, src.has_invalid_value, src.has_outlier_value);
GO    

SELECT
    SUM(CAST(has_missing_value AS INT)) AS rows_missing,
    SUM(CAST(has_invalid_value AS INT)) AS rows_invalid,
    SUM(CAST(has_outlier_value AS INT)) AS rows_outlier
FROM silver.companies;
GO

IF OBJECT_ID('silver.news_tickers', 'U') IS NULL
CREATE TABLE silver.news_tickers (
    article_id INT NOT NULL,
    ticker NVARCHAR(10) NOT NULL,
    n_symbols_total INT,
    n_project_tickers INT,
    published_at DATETIME,
    reaction_date DATETIME,
    has_missing_value BIT NOT NULL DEFAULT 0,
    has_invalid_value BIT NOT NULL DEFAULT 0,
    has_outlier_value BIT NOT NULL DEFAULT 0,
    CONSTRAINT PK_silver_news_tickers PRIMARY KEY (article_id, ticker)
);
WITH news_tickers_latest AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY (LTRIM(RTRIM(article_id))), (LTRIM(RTRIM(ticker)))
            ORDER BY bronze_id DESC
        ) AS rn
    FROM bronze.news_tickers
    WHERE NULLIF(LTRIM(RTRIM(article_id)), '') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(ticker)), '') IS NOT NULL
),
news_tickers_cleaned AS (
    SELECT
        CAST(NULLIF(LTRIM(RTRIM(article_id)), '') AS INT) AS article_id,
        NULLIF(LTRIM(RTRIM(ticker)), '') AS ticker,
        CAST(NULLIF(LTRIM(RTRIM(n_symbols_total)), '') AS INT) AS n_symbols_total,
        CAST(NULLIF(LTRIM(RTRIM(n_project_tickers)), '') AS INT) AS n_project_tickers,
        TRY_CAST(NULLIF(LTRIM(RTRIM(published_at)), '') AS DATETIME) AS published_at,
        TRY_CAST(NULLIF(LTRIM(RTRIM(reaction_date)), '') AS DATETIME) AS reaction_date
    FROM news_tickers_latest
    WHERE rn = 1
),
news_tickers_flagged AS (
    SELECT
        article_id, ticker, n_symbols_total, n_project_tickers, published_at, reaction_date,
        CASE WHEN
            article_id IS NULL OR ticker IS NULL OR n_symbols_total IS NULL OR n_project_tickers IS NULL OR published_at IS NULL OR reaction_date IS NULL
        THEN 1 ELSE 0 END AS has_missing_value,
        CASE WHEN
            (article_id IS NOT NULL AND TRY_CAST(article_id AS INT) IS NULL)
        OR (ticker IS NOT NULL AND LEN(ticker) > 10)
        OR (n_symbols_total IS NOT NULL AND TRY_CAST(n_symbols_total AS INT) IS NULL)
        OR (n_project_tickers IS NOT NULL AND TRY_CAST(n_project_tickers AS INT) IS NULL)
        OR (published_at IS NOT NULL AND TRY_CAST(published_at AS DATETIME) IS NULL)
        OR (reaction_date IS NOT NULL AND TRY_CAST(reaction_date AS DATETIME) IS NULL)
        THEN 1 ELSE 0 END AS has_invalid_value,
        CASE WHEN
            n_symbols_total < 0 OR n_project_tickers < 0
        THEN 1 ELSE 0 END AS has_outlier_value
    FROM news_tickers_cleaned
)MERGE silver.news_tickers AS tgt
USING news_tickers_flagged AS src
    ON tgt.article_id = src.article_id AND tgt.ticker = src.ticker
WHEN MATCHED THEN
    UPDATE SET
        tgt.n_symbols_total = src.n_symbols_total,
        tgt.n_project_tickers = src.n_project_tickers,
        tgt.published_at = src.published_at,
        tgt.reaction_date = src.reaction_date,
        tgt.has_missing_value = src.has_missing_value,
        tgt.has_invalid_value = src.has_invalid_value,
        tgt.has_outlier_value = src.has_outlier_value
WHEN NOT MATCHED THEN
    INSERT (article_id, ticker, n_symbols_total, n_project_tickers, published_at, reaction_date, has_missing_value, has_invalid_value, has_outlier_value)
    VALUES (src.article_id, src.ticker, src.n_symbols_total, src.n_project_tickers, src.published_at, src.reaction_date, src.has_missing_value, src.has_invalid_value, src.has_outlier_value);


IF OBJECT_ID('silver.events', 'U') IS NULL
CREATE TABLE silver.events (
    event_id INT ,
    ticker NVARCHAR(10) NOT NULL,
    event_type NVARCHAR(25) NOT NULL,
    event_date DATE NOT NULL,
    reaction_date DATE NOT NULL,
    after_close NVARCHAR(10) ,
    eps_estimate DECIMAL(18,4),
    eps_actual DECIMAL(18,4),
    surprise_pct DECIMAL(18,4),
    items NVARCHAR(100),
    items_description NVARCHAR(Max),
    accession_number NVARCHAR(255),
    has_missing_value BIT NOT NULL DEFAULT 0,
    has_invalid_value BIT NOT NULL DEFAULT 0,
    has_outlier_value BIT NOT NULL DEFAULT 0,
    CONSTRAINT PK_silver_events PRIMARY KEY (event_id)
);

WITH events_latest AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY (LTRIM(RTRIM(event_id)))
            ORDER BY bronze_id DESC
        ) AS rn
    FROM bronze.events
    WHERE NULLIF(LTRIM(RTRIM(event_id)), '') IS NOT NULL
),
events_cleaned AS (
    SELECT
        TRY_CAST(NULLIF(LTRIM(RTRIM(event_id)), '') AS INT) AS event_id,
        UPPER(LTRIM(RTRIM(ticker))) AS ticker,
        event_type,
        TRY_CAST(NULLIF(LTRIM(RTRIM(event_date)), '') AS DATE) AS event_date,
        TRY_CAST(NULLIF(LTRIM(RTRIM(reaction_date)), '') AS DATE) AS reaction_date,
        CASE WHEN LTRIM(RTRIM(after_close)) IN ('Y', 'N') THEN LTRIM(RTRIM(after_close)) ELSE NULL END AS after_close,
        -- eps_estimate, eps_actual, surprise_pct, items are all DECIMAL(18,4) but can be empty or invalid, so we use TRY_CAST to convert and NULLIF to turn '' into NULL
        -- items_description and accession_number are NVARCHAR(MAX) and can be empty or invalid, so we just trim them and keep them as-is
        TRY_CAST(NULLIF(LTRIM(RTRIM(eps_estimate)), '') AS DECIMAL(18,4)) AS eps_estimate,
        TRY_CAST(NULLIF(LTRIM(RTRIM(eps_actual)), '') AS DECIMAL(18,4)) AS eps_actual,
        TRY_CAST(NULLIF(LTRIM(RTRIM(surprise_pct)), '') AS DECIMAL(18,4)) AS surprise_pct,
        LEFT(NULLIF(LTRIM(RTRIM(items)), ''), 100) AS items,
        LTRIM(RTRIM(items_description)) AS items_description,
        LTRIM(RTRIM(accession_number)) AS accession_number
    FROM events_latest
    WHERE rn = 1
),
events_flagged AS (
    SELECT
        event_id, ticker, event_type, event_date, reaction_date, after_close, eps_estimate, eps_actual, surprise_pct, items, items_description, accession_number,
        CASE WHEN
            event_id IS NULL OR ticker IS NULL OR event_type IS NULL OR event_date IS NULL OR reaction_date IS NULL
        THEN 1 ELSE 0 END AS has_missing_value,
        CASE WHEN
            (event_id IS NOT NULL AND TRY_CAST(event_id AS INT) IS NULL)
        OR (ticker IS NOT NULL AND LEN(ticker) > 10)
        OR (event_type IS NOT NULL AND LEN(event_type) > 25)
        OR (event_date IS NOT NULL AND TRY_CAST(event_date AS DATE) IS NULL)
        OR (reaction_date IS NOT NULL AND TRY_CAST(reaction_date AS DATE) IS NULL)
        OR (eps_estimate IS NOT NULL AND TRY_CAST(eps_estimate AS DECIMAL(18,4)) IS NULL)
        OR (eps_actual IS NOT NULL AND TRY_CAST(eps_actual AS DECIMAL(18,4)) IS NULL)
        OR (surprise_pct IS NOT NULL AND TRY_CAST(surprise_pct AS DECIMAL(18,4)) IS NULL)
        THEN 1 ELSE 0 END AS has_invalid_value,
        CASE WHEN
            eps_estimate < -1000.0 OR eps_estimate > 1000.0
        OR eps_actual < -1000.0 OR eps_actual > 1000.0
        OR surprise_pct < -100.0 OR surprise_pct > 100.0
        THEN 1 ELSE 0 END AS has_outlier_value
    FROM events_cleaned
)
MERGE silver.events AS tgt
USING events_flagged AS src
ON tgt.event_id = src.event_id
WHEN MATCHED THEN
    UPDATE SET
        ticker = src.ticker,
        event_type = src.event_type,
        event_date = src.event_date,
        reaction_date = src.reaction_date,
        after_close = src.after_close,
        eps_estimate = src.eps_estimate,
        eps_actual = src.eps_actual,
        surprise_pct = src.surprise_pct,
        items = src.items,
        items_description = src.items_description,
        accession_number = src.accession_number,
        tgt.has_missing_value = src.has_missing_value,
        tgt.has_invalid_value = src.has_invalid_value,
        tgt.has_outlier_value = src.has_outlier_value
WHEN NOT MATCHED THEN
    INSERT (event_id, ticker, event_type, event_date, reaction_date, after_close, eps_estimate, eps_actual, surprise_pct, items, items_description, accession_number, has_missing_value, has_invalid_value, has_outlier_value)
    VALUES (src.event_id, src.ticker, src.event_type, src.event_date, src.reaction_date, src.after_close, src.eps_estimate, src.eps_actual, src.surprise_pct, src.items, src.items_description, src.accession_number, src.has_missing_value, src.has_invalid_value, src.has_outlier_value);

SELECT
    SUM(CAST(has_missing_value AS INT)) AS rows_missing,
    SUM(CAST(has_invalid_value AS INT)) AS rows_invalid,
    SUM(CAST(has_outlier_value AS INT)) AS rows_outlier
FROM silver.events;
GO
IF OBJECT_ID('silver.fundamentals', 'U') IS NULL
CREATE TABLE silver.fundamentals (
    ticker NVARCHAR(10) NOT NULL,
    period_end DATE NOT NULL,
    filing_date DATE NOT NULL,
    revenue DECIMAL(18,4),
    net_income DECIMAL(18,4),
    eps_diluted DECIMAL(18,4),
    total_assets DECIMAL(18,4),
    equity DECIMAL(18,4),
    profit_margin DECIMAL(18,4),
    has_missing_value BIT NOT NULL DEFAULT 0,
    has_invalid_value BIT NOT NULL DEFAULT 0,
    has_outlier_value BIT NOT NULL DEFAULT 0,
    CONSTRAINT PK_silver_fundamentals PRIMARY KEY (ticker, period_end)
);

WITH fund_latest AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY (LTRIM(RTRIM(ticker))), (LTRIM(RTRIM(period_end)))
            ORDER BY bronze_id DESC
        ) AS rn
    FROM bronze.fundamentals
    WHERE NULLIF(LTRIM(RTRIM(ticker)), '') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(period_end)), '') IS NOT NULL
),
fund_cleaned AS (
    SELECT
        UPPER(LTRIM(RTRIM(ticker))) AS ticker,
        TRY_CAST(NULLIF(LTRIM(RTRIM(period_end)), '') AS DATE) AS period_end,
        TRY_CAST(NULLIF(LTRIM(RTRIM(filing_date)), '') AS DATE) AS filing_date,
        TRY_CAST(NULLIF(LTRIM(RTRIM(revenue)), '') AS DECIMAL(18,4)) AS revenue,
        TRY_CAST(NULLIF(LTRIM(RTRIM(net_income)), '') AS DECIMAL(18,4)) AS net_income,
        TRY_CAST(NULLIF(LTRIM(RTRIM(eps_diluted)), '') AS DECIMAL(18,4)) AS eps_diluted,
        TRY_CAST(NULLIF(LTRIM(RTRIM(total_assets)), '') AS DECIMAL(18,4)) AS total_assets,
        TRY_CAST(NULLIF(LTRIM(RTRIM(equity)), '') AS DECIMAL(18,4)) AS equity,
        TRY_CAST(NULLIF(LTRIM(RTRIM(profit_margin)), '') AS DECIMAL(18,4)) AS profit_margin
    FROM fund_latest
    WHERE rn = 1
),
fund_flagged AS (
    SELECT
        ticker, period_end, filing_date, revenue, net_income, eps_diluted, total_assets, equity, profit_margin,
        CASE WHEN
            ticker IS NULL OR period_end IS NULL OR filing_date IS NULL OR revenue IS NULL OR net_income IS NULL OR eps_diluted IS NULL OR total_assets IS NULL OR equity IS NULL OR profit_margin IS NULL
        THEN 1 ELSE 0 END AS has_missing_value,
        CASE WHEN
            (ticker IS NOT NULL AND LEN(ticker) > 255)
        OR (period_end IS NOT NULL AND LEN(period_end) > 255)
        OR (filing_date IS NOT NULL AND LEN(filing_date) > 255)
        OR (revenue IS NOT NULL AND LEN(revenue) > 255)
        OR (net_income IS NOT NULL AND LEN(net_income) > 255)
        OR (eps_diluted IS NOT NULL AND LEN(eps_diluted) > 255)
        OR (total_assets IS NOT NULL AND LEN(total_assets) > 255)
        OR (equity IS NOT NULL AND LEN(equity) > 255)
        THEN 1 ELSE 0 END AS has_invalid_value,
        CASE WHEN
            profit_margin < -1.0 OR profit_margin > 1.0
        THEN 1 ELSE 0 END AS has_outlier_value
    FROM fund_cleaned
)
MERGE silver.fundamentals AS tgt
USING fund_flagged AS src
    ON tgt.ticker = src.ticker AND tgt.period_end = src.period_end
WHEN MATCHED THEN
    UPDATE SET
        tgt.filing_date = src.filing_date,
        tgt.revenue = src.revenue,
        tgt.net_income = src.net_income,
        tgt.eps_diluted = src.eps_diluted,
        tgt.total_assets = src.total_assets,
        tgt.equity = src.equity,
        tgt.profit_margin = src.profit_margin,
        tgt.has_missing_value = src.has_missing_value,
        tgt.has_invalid_value = src.has_invalid_value,
        tgt.has_outlier_value = src.has_outlier_value
WHEN NOT MATCHED THEN
    INSERT (ticker, period_end, filing_date, revenue, net_income, eps_diluted, total_assets, equity, profit_margin, has_missing_value, has_invalid_value, has_outlier_value)
    VALUES (src.ticker, src.period_end, src.filing_date, src.revenue, src.net_income, src.eps_diluted, src.total_assets, src.equity, src.profit_margin, src.has_missing_value, src.has_invalid_value, src.has_outlier_value);

SELECT
    SUM(CAST(has_missing_value AS INT)) AS rows_missing,
    SUM(CAST(has_invalid_value AS INT)) AS rows_invalid,
    SUM(CAST(has_outlier_value AS INT)) AS rows_outlier
FROM silver.fundamentals;
GO

IF OBJECT_ID('silver.market_features', 'U') IS NULL
CREATE TABLE silver.market_features (

    ticker           NVARCHAR(10)    NOT NULL,
    [date]           DATE           NOT NULL,
    [open]           DECIMAL(18,4)  NOT NULL,
    high             DECIMAL(18,4)  NOT NULL,
    low              DECIMAL(18,4)  NOT NULL,
    [close]          DECIMAL(18,4)  NOT NULL,
    volume           BIGINT         NOT NULL,
    [return]         DECIMAL(18,6)  NULL, 
    cumulative_return  DECIMAL(18,6)  NULL,
    ma20              DECIMAL(18,4)  NULL,
    ma50              DECIMAL(18,4)  NULL,
    ma200             DECIMAL(18,4)  NULL,
    rolling_volatility DECIMAL(18,6)  NULL,
    volume_change DECIMAL(18,6)  NULL,
    volume_ma20 DECIMAL(18,4)  NULL,
    has_missing_value BIT NOT NULL DEFAULT 0,
    has_invalid_value BIT NOT NULL DEFAULT 0,
    has_outlier_value BIT NOT NULL DEFAULT 0,
    CONSTRAINT PK_silver_market_features PRIMARY KEY (ticker, [date])
);

WITH features_latest AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY (LTRIM(RTRIM(ticker))), (LTRIM(RTRIM([date])))
            ORDER BY bronze_id DESC
        ) AS rn
    FROM bronze.market_features
    WHERE NULLIF(LTRIM(RTRIM(ticker)), '') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM([date])), '') IS NOT NULL
),
features_cleaned AS (
    SELECT
        UPPER(LTRIM(RTRIM(ticker))) AS ticker,
        TRY_CAST(NULLIF(LTRIM(RTRIM([date])), '') AS DATE) AS [date],
        TRY_CAST(NULLIF(LTRIM(RTRIM([open])), '') AS DECIMAL(18,4)) AS [open],
        TRY_CAST(NULLIF(LTRIM(RTRIM(high)), '') AS DECIMAL(18,4)) AS high,
        TRY_CAST(NULLIF(LTRIM(RTRIM(low)), '') AS DECIMAL(18,4)) AS low,
        TRY_CAST(NULLIF(LTRIM(RTRIM([close])), '') AS DECIMAL(18,4)) AS [close],
        TRY_CAST(NULLIF(LTRIM(RTRIM(volume)), '') AS BIGINT) AS volume,
        TRY_CAST(NULLIF(LTRIM(RTRIM([return])), '') AS DECIMAL(18,6)) AS [return],
        TRY_CAST(NULLIF(LTRIM(RTRIM(cumulative_return)), '') AS DECIMAL(18,6)) AS cumulative_return,
        TRY_CAST(NULLIF(LTRIM(RTRIM(ma20)), '') AS DECIMAL(18,4)) AS ma20,
        TRY_CAST(NULLIF(LTRIM(RTRIM(ma50)), '') AS DECIMAL(18,4)) AS ma50,
        TRY_CAST(NULLIF(LTRIM(RTRIM(ma200)), '') AS DECIMAL(18,4)) AS ma200,
        TRY_CAST(NULLIF(LTRIM(RTRIM(rolling_volatility)), '') AS DECIMAL(18,6)) AS rolling_volatility,
        TRY_CAST(NULLIF(LTRIM(RTRIM(volume_change)), '') AS DECIMAL(18,6)) AS volume_change,
        TRY_CAST(NULLIF(LTRIM(RTRIM(volume_ma20)), '') AS DECIMAL(18,4)) AS volume_ma20
    FROM features_latest
    WHERE rn = 1
),
features_flagged AS (
    SELECT
        ticker, [date], [open], high, low, [close], volume, [return], cumulative_return, ma20, ma50, ma200, rolling_volatility, volume_change, volume_ma20,
        CASE WHEN
            ticker IS NULL OR [date] IS NULL OR [open] IS NULL OR high IS NULL OR low IS NULL OR [close] IS NULL OR volume IS NULL
        THEN 1 ELSE 0 END AS has_missing_value,
        CASE WHEN
            (ticker IS NOT NULL AND LEN(ticker) > 10)
        OR ([date] IS NOT NULL AND LEN(TRY_CAST([date] AS DATE)) > 255)
        OR ([open] IS NOT NULL AND TRY_CAST([open] AS DECIMAL(18,4)) IS NULL)
        OR (high IS NOT NULL AND TRY_CAST(high AS DECIMAL(18,4)) IS NULL)
        OR (low IS NOT NULL AND TRY_CAST(low AS DECIMAL(18,4)) IS NULL)
        OR ([close] IS NOT NULL AND TRY_CAST([close] AS DECIMAL(18,4)) IS NULL)
        OR (volume IS NOT NULL AND TRY_CAST(volume AS BIGINT) IS NULL)
        THEN 1 ELSE 0 END AS has_invalid_value,
        CASE WHEN
            [return] < -1.0 OR [return] > 1.0
        OR cumulative_return < -1.0 OR cumulative_return > 1.0
        THEN 1 ELSE 0 END AS has_outlier_value
    FROM features_cleaned
)
MERGE silver.market_features AS tgt
USING features_flagged AS src
ON tgt.ticker = src.ticker AND tgt.[date] = src.[date]
WHEN MATCHED THEN
    UPDATE SET
        [open] = src.[open],
        high = src.high,
        low = src.low,
        [close] = src.[close],
        volume = src.volume,
        [return] = src.[return],
        cumulative_return = src.cumulative_return,
        ma20 = src.ma20,
        ma50 = src.ma50,
        ma200 = src.ma200,
        rolling_volatility = src.rolling_volatility,
        volume_change = src.volume_change,
        volume_ma20 = src.volume_ma20,
        tgt.has_missing_value = src.has_missing_value,
        tgt.has_invalid_value = src.has_invalid_value,
        tgt.has_outlier_value = src.has_outlier_value
WHEN NOT MATCHED THEN
    INSERT (
        ticker, [date], [open], high, low, [close], volume, [return], cumulative_return, ma20, ma50, ma200, rolling_volatility, volume_change, volume_ma20, has_missing_value, has_invalid_value, has_outlier_value
    ) VALUES (
        src.ticker, src.[date], src.[open], src.high, src.low, src.[close], src.volume, src.[return], src.cumulative_return, src.ma20, src.ma50, src.ma200, src.rolling_volatility,	src.volume_change, src.volume_ma20, src.has_missing_value, src.has_invalid_value, src.has_outlier_value
    );

    SELECT
    SUM(CAST(has_missing_value AS INT)) AS rows_missing,
    SUM(CAST(has_invalid_value AS INT)) AS rows_invalid,
    SUM(CAST(has_outlier_value AS INT)) AS rows_outlier
FROM silver.market_features;
GO

IF OBJECT_ID('silver.risk_metrics', 'U') IS NULL
CREATE TABLE silver.risk_metrics (
    ticker NVARCHAR(10) NOT NULL,
    daily_volatility DECIMAL(18,8),
    annualized_volatility DECIMAL(18,8),
    max_drawdown DECIMAL(18,8),
    sharpe_ratio DECIMAL(18,8),
    var_95_hist DECIMAL(18,8),
    var_95_param DECIMAL(18,8),
    var_99_hist DECIMAL(18,8),
    var_99_param DECIMAL(18,8),
    has_missing_value BIT NOT NULL DEFAULT 0,
    has_invalid_value BIT NOT NULL DEFAULT 0,
    has_outlier_value BIT NOT NULL DEFAULT 0,
    CONSTRAINT PK_silver_risk_metrics PRIMARY KEY (ticker)
);

WITH risk_metrics_latest AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY (LTRIM(RTRIM(ticker)))
            ORDER BY bronze_id DESC
        ) AS rn
    FROM bronze.risk_metrics
    WHERE NULLIF(LTRIM(RTRIM(ticker)), '') IS NOT NULL
),
risk_metrics_cleaned AS (
    SELECT
        UPPER(LTRIM(RTRIM(ticker))) AS ticker,
        TRY_CAST(NULLIF(LTRIM(RTRIM(daily_volatility)), '') AS DECIMAL(18,8)) AS daily_volatility,
        TRY_CAST(NULLIF(LTRIM(RTRIM(annualized_volatility)), '') AS DECIMAL(18,8)) AS annualized_volatility,
        TRY_CAST(NULLIF(LTRIM(RTRIM(max_drawdown)), '') AS DECIMAL(18,8)) AS max_drawdown,
        TRY_CAST(NULLIF(LTRIM(RTRIM(sharpe_ratio)), '') AS DECIMAL(18,8)) AS sharpe_ratio,
        TRY_CAST(NULLIF(LTRIM(RTRIM(var_95_hist)), '') AS DECIMAL(18,8)) AS var_95_hist,
        TRY_CAST(NULLIF(LTRIM(RTRIM(var_95_param)), '') AS DECIMAL(18,8)) AS var_95_param,
        TRY_CAST(NULLIF(LTRIM(RTRIM(var_99_hist)), '') AS DECIMAL(18,8)) AS var_99_hist,
        TRY_CAST(NULLIF(LTRIM(RTRIM(var_99_param)), '') AS DECIMAL(18,8)) AS var_99_param
    FROM risk_metrics_latest
    WHERE rn = 1
),
risk_metrics_flagged AS (
    SELECT
        ticker, daily_volatility, annualized_volatility, max_drawdown, sharpe_ratio, var_95_hist, var_95_param, var_99_hist, var_99_param,
        CASE WHEN
            ticker IS NULL OR daily_volatility IS NULL OR annualized_volatility IS NULL OR max_drawdown IS NULL OR sharpe_ratio IS NULL OR var_95_hist IS NULL OR var_95_param IS NULL OR var_99_hist IS NULL OR var_99_param IS NULL
        THEN 1 ELSE 0 END AS has_missing_value,
        CASE WHEN
            (ticker IS NOT NULL AND LEN(ticker) > 10)
        OR (daily_volatility IS NOT NULL AND TRY_CAST(daily_volatility AS DECIMAL(18,8)) IS NULL)
        OR (annualized_volatility IS NOT NULL AND TRY_CAST(annualized_volatility AS DECIMAL(18,8)) IS NULL)
        OR (max_drawdown IS NOT NULL AND TRY_CAST(max_drawdown AS DECIMAL(18,8)) IS NULL)
        OR (sharpe_ratio IS NOT NULL AND TRY_CAST(sharpe_ratio AS DECIMAL(18,8)) IS NULL)
        OR (var_95_hist IS NOT NULL AND TRY_CAST(var_95_hist AS DECIMAL(18,8)) IS NULL)
        OR (var_95_param IS NOT NULL AND TRY_CAST(var_95_param AS DECIMAL(18,8)) IS NULL)
        OR (var_99_hist IS NOT NULL AND TRY_CAST(var_99_hist AS DECIMAL(18,8)) IS NULL)
        OR (var_99_param IS NOT NULL AND TRY_CAST(var_99_param AS DECIMAL(18,8)) IS NULL)
        THEN 1 ELSE 0 END AS has_invalid_value,
        CASE WHEN
            daily_volatility < 0 OR daily_volatility > 1
        OR annualized_volatility < 0 OR annualized_volatility > 1
        THEN 1 ELSE 0 END AS has_outlier_value
    FROM risk_metrics_cleaned
)
MERGE silver.risk_metrics AS tgt
USING risk_metrics_flagged AS src
ON tgt.ticker = src.ticker
WHEN MATCHED THEN
    UPDATE SET
        daily_volatility = src.daily_volatility,
        annualized_volatility = src.annualized_volatility,
        max_drawdown = src.max_drawdown,
        sharpe_ratio = src.sharpe_ratio,
        var_95_hist = src.var_95_hist,
        var_95_param = src.var_95_param,
        var_99_hist = src.var_99_hist,
        var_99_param = src.var_99_param,
        tgt.has_missing_value = src.has_missing_value,
        tgt.has_invalid_value = src.has_invalid_value,
        tgt.has_outlier_value = src.has_outlier_value
WHEN NOT MATCHED THEN
    INSERT (ticker, daily_volatility, annualized_volatility, max_drawdown, sharpe_ratio, var_95_hist, var_95_param, var_99_hist, var_99_param, has_missing_value, has_invalid_value, has_outlier_value)
    VALUES (src.ticker, src.daily_volatility, src.annualized_volatility, src.max_drawdown, src.sharpe_ratio, src.var_95_hist, src.var_95_param, src.var_99_hist, src.var_99_param, src.has_missing_value, src.has_invalid_value, src.has_outlier_value);

SELECT
    SUM(CAST(has_missing_value AS INT)) AS rows_missing,
    SUM(CAST(has_invalid_value AS INT)) AS rows_invalid,
    SUM(CAST(has_outlier_value AS INT)) AS rows_outlier
FROM silver.risk_metrics;
GO

IF OBJECT_ID('silver.monthly_risk', 'U') IS NULL
CREATE TABLE silver.monthly_risk (
    ticker NVARCHAR(10) NOT NULL,
    [date] DATE NOT NULL,
    volatility_30d DECIMAL(18,6),
    max_drawdown DECIMAL(18,6),
    has_missing_value BIT NOT NULL DEFAULT 0,
    has_invalid_value BIT NOT NULL DEFAULT 0,
    has_outlier_value BIT NOT NULL DEFAULT 0,
    CONSTRAINT PK_silver_monthly_risk PRIMARY KEY (ticker, [date])
);
GO

WITH risk_latest AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY UPPER(LTRIM(RTRIM(ticker))), TRY_CAST(NULLIF(LTRIM(RTRIM([date])), '') AS DATE)
            ORDER BY bronze_id DESC
        ) AS rn
    FROM bronze.monthly_risk
    WHERE NULLIF(LTRIM(RTRIM(ticker)), '') IS NOT NULL
      AND TRY_CAST(NULLIF(LTRIM(RTRIM([date])), '') AS DATE) IS NOT NULL
),
risk_cleaned AS (
    SELECT
        UPPER(LTRIM(RTRIM(ticker))) AS ticker,
        TRY_CAST(NULLIF(LTRIM(RTRIM([date])), '') AS DATE) AS [date],
        TRY_CAST(TRY_CAST(NULLIF(LTRIM(RTRIM(volatility_30d)), '') AS FLOAT) AS DECIMAL(18,6)) AS volatility_30d,
        NULLIF(LTRIM(RTRIM(volatility_30d)), '') AS raw_volatility_30d,
        TRY_CAST(TRY_CAST(NULLIF(LTRIM(RTRIM(max_drawdown)), '') AS FLOAT) AS DECIMAL(18,6)) AS max_drawdown,
        NULLIF(LTRIM(RTRIM(max_drawdown)), '') AS raw_max_drawdown
    FROM risk_latest
    WHERE rn = 1
),
risk_flagged AS (
    SELECT
        ticker, [date], volatility_30d, max_drawdown,
        CASE WHEN raw_volatility_30d IS NULL OR raw_max_drawdown IS NULL
        THEN 1 ELSE 0 END AS has_missing_value,
        CASE WHEN (raw_volatility_30d IS NOT NULL AND volatility_30d IS NULL)
            OR (raw_max_drawdown IS NOT NULL AND max_drawdown IS NULL)
        THEN 1 ELSE 0 END AS has_invalid_value,
        CASE WHEN volatility_30d < 0 OR volatility_30d > 1
        THEN 1 ELSE 0 END AS has_outlier_value
    FROM risk_cleaned
)
MERGE silver.monthly_risk AS tgt
USING risk_flagged AS src
    ON tgt.ticker = src.ticker AND tgt.[date] = src.[date]
WHEN MATCHED THEN
    UPDATE SET
        tgt.volatility_30d = src.volatility_30d,
        tgt.max_drawdown = src.max_drawdown,
        tgt.has_missing_value = src.has_missing_value,
        tgt.has_invalid_value = src.has_invalid_value,
        tgt.has_outlier_value = src.has_outlier_value
WHEN NOT MATCHED THEN
    INSERT (ticker, [date], volatility_30d, max_drawdown, has_missing_value, has_invalid_value, has_outlier_value)
    VALUES (src.ticker, src.[date], src.volatility_30d, src.max_drawdown, src.has_missing_value, src.has_invalid_value, src.has_outlier_value)
;
GO

SELECT
    SUM(CAST(has_missing_value AS INT)) AS rows_missing,
    SUM(CAST(has_invalid_value AS INT)) AS rows_invalid,
    SUM(CAST(has_outlier_value AS INT)) AS rows_outlier
FROM silver.monthly_risk;
GO

IF OBJECT_ID('silver.correlation_matrix', 'U') IS NULL
CREATE TABLE silver.correlation_matrix (
    ticker NVARCHAR(10) NOT NULL,
    AAPL DECIMAL(18,6),
    AMZN DECIMAL(18,6),
    JNJ DECIMAL(18,6),
    JPM DECIMAL(18,6),
    KO DECIMAL(18,6),
    LLY DECIMAL(18,6),
    MSFT DECIMAL(18,6),
    NVDA DECIMAL(18,6),
    TSLA DECIMAL(18,6),
    XOM DECIMAL(18,6),
    has_missing_value BIT NOT NULL DEFAULT 0,
    has_invalid_value BIT NOT NULL DEFAULT 0,
    has_outlier_value BIT NOT NULL DEFAULT 0,
    CONSTRAINT PK_silver_correlation_matrix PRIMARY KEY (ticker)
);

WITH corr_latest AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY (LTRIM(RTRIM(ticker)))
            ORDER BY bronze_id DESC
        ) AS rn
    FROM bronze.correlation_matrix
    WHERE NULLIF(LTRIM(RTRIM(ticker)), '') IS NOT NULL
),
corr_cleaned AS (
    SELECT
        UPPER(LTRIM(RTRIM(ticker))) AS ticker,
        TRY_CAST(NULLIF(LTRIM(RTRIM(AAPL)), '') AS DECIMAL(18,6)) AS AAPL,
        TRY_CAST(NULLIF(LTRIM(RTRIM(AMZN)), '') AS DECIMAL(18,6)) AS AMZN,
        TRY_CAST(NULLIF(LTRIM(RTRIM(JNJ)), '') AS DECIMAL(18,6)) AS JNJ,
        TRY_CAST(NULLIF(LTRIM(RTRIM(JPM)), '') AS DECIMAL(18,6)) AS JPM,
        TRY_CAST(NULLIF(LTRIM(RTRIM(KO)), '') AS DECIMAL(18,6)) AS KO,
        TRY_CAST(NULLIF(LTRIM(RTRIM(LLY)), '') AS DECIMAL(18,6)) AS LLY,
        TRY_CAST(NULLIF(LTRIM(RTRIM(MSFT)), '') AS DECIMAL(18,6)) AS MSFT,
        TRY_CAST(NULLIF(LTRIM(RTRIM(NVDA)), '') AS DECIMAL(18,6)) AS NVDA,
        TRY_CAST(NULLIF(LTRIM(RTRIM(TSLA)), '') AS DECIMAL(18,6)) AS TSLA,
        TRY_CAST(NULLIF(LTRIM(RTRIM(XOM)), '') AS DECIMAL(18,6)) AS XOM
    FROM corr_latest
    WHERE rn = 1
),
corr_flagged AS (
    SELECT
        ticker, AAPL, AMZN, JNJ, JPM, KO, LLY, MSFT, NVDA, TSLA, XOM,
        CASE WHEN
            ticker IS NULL OR AAPL IS NULL OR AMZN IS NULL OR JNJ IS NULL OR JPM IS NULL OR KO IS NULL OR LLY IS NULL OR MSFT IS NULL OR NVDA IS NULL OR TSLA IS NULL OR XOM IS NULL
        THEN 1 ELSE 0 END AS has_missing_value,
        CASE WHEN
            (ticker IS NOT NULL AND LEN(ticker) > 10)
        OR (AAPL IS NOT NULL AND TRY_CAST(AAPL AS DECIMAL(18,6)) IS NULL)
        OR (AMZN IS NOT NULL AND TRY_CAST(AMZN AS DECIMAL(18,6)) IS NULL)
        OR (JNJ IS NOT NULL AND TRY_CAST(JNJ AS DECIMAL(18,6)) IS NULL)
        OR (JPM IS NOT NULL AND TRY_CAST(JPM AS DECIMAL(18,6)) IS NULL)
        OR (KO IS NOT NULL AND TRY_CAST(KO AS DECIMAL(18,6)) IS NULL)
        OR (LLY IS NOT NULL AND TRY_CAST(LLY AS DECIMAL(18,6)) IS NULL)
        OR (MSFT IS NOT NULL AND TRY_CAST(MSFT AS DECIMAL(18,6)) IS NULL)
        OR (NVDA IS NOT NULL AND TRY_CAST(NVDA AS DECIMAL(18,6)) IS NULL)
        OR (TSLA IS NOT NULL AND TRY_CAST(TSLA AS DECIMAL(18,6)) IS NULL)
        OR (XOM IS NOT NULL AND TRY_CAST(XOM AS DECIMAL(18,6)) IS NULL)
        THEN 1 ELSE 0 END AS has_invalid_value,
        CASE WHEN
            AAPL < -1.0 OR AAPL > 1.0
        OR AMZN < -1.0 OR AMZN > 1.0
        OR JNJ < -1.0 OR JNJ > 1.0
        OR JPM < -1.0 OR JPM > 1.0
        OR KO < -1.0 OR KO > 1.0
        OR LLY < -1.0 OR LLY > 1.0
        OR MSFT < -1.0 OR MSFT > 1.0
        OR NVDA < -1.0 OR NVDA > 1.0
        OR TSLA < -1.0 OR TSLA > 1.0
        OR XOM < -1.0 OR XOM > 1.0
        THEN 1 ELSE 0 END AS has_outlier_value  
        FROM corr_cleaned
)
MERGE silver.correlation_matrix AS tgt
USING corr_flagged AS src
    ON tgt.ticker = src.ticker
WHEN MATCHED THEN
    UPDATE SET
        AAPL = src.AAPL,
        AMZN = src.AMZN,
        JNJ = src.JNJ,
        JPM = src.JPM,
        KO = src.KO,
        LLY = src.LLY,
        MSFT = src.MSFT,
        NVDA = src.NVDA,
        TSLA = src.TSLA,
        XOM = src.XOM,
        tgt.has_missing_value = src.has_missing_value,
        tgt.has_invalid_value = src.has_invalid_value,
        tgt.has_outlier_value = src.has_outlier_value
WHEN NOT MATCHED THEN
    INSERT (ticker, AAPL, AMZN, JNJ, JPM, KO, LLY, MSFT, NVDA, TSLA, XOM, has_missing_value, has_invalid_value, has_outlier_value)
    VALUES (src.ticker, src.AAPL, src.AMZN, src.JNJ, src.JPM, src.KO, src.LLY, src.MSFT, src.NVDA, src.TSLA, src.XOM, src.has_missing_value, src.has_invalid_value, src.has_outlier_value)
;
GO

SELECT
    SUM(CAST(has_missing_value AS INT)) AS rows_missing,
    SUM(CAST(has_invalid_value AS INT)) AS rows_invalid,
    SUM(CAST(has_outlier_value AS INT)) AS rows_outlier
FROM silver.correlation_matrix;
GO


IF OBJECT_ID('silver.benchmark_prices', 'U') IS NULL
CREATE TABLE silver.benchmark_prices (
    symbol NVARCHAR(10) NOT NULL,
    [date] DATE NOT NULL,
    [close] DECIMAL(18,6),
    [return] DECIMAL(18,6),
    has_missing_value BIT NOT NULL DEFAULT 0,
    has_invalid_value BIT NOT NULL DEFAULT 0,
    has_outlier_value BIT NOT NULL DEFAULT 0,
    CONSTRAINT PK_silver_benchmark_prices PRIMARY KEY (symbol, [date])
);

WITH benchmark_latest AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY (LTRIM(RTRIM(symbol))), (LTRIM(RTRIM([date])))
            ORDER BY bronze_id DESC
        ) AS rn
    FROM bronze.benchmark_prices
    WHERE NULLIF(LTRIM(RTRIM(symbol)), '') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM([date])), '') IS NOT NULL
),
BENCHMARK_cleaned AS (
    SELECT
        UPPER(LTRIM(RTRIM(symbol))) AS symbol,
        TRY_CAST(NULLIF(LTRIM(RTRIM([date])), '') AS DATE) AS [date],
        TRY_CAST(NULLIF(LTRIM(RTRIM([close])), '') AS DECIMAL(18,6)) AS [close],
        TRY_CAST(NULLIF(LTRIM(RTRIM([return])), '') AS DECIMAL(18,6)) AS [return]
    FROM benchmark_latest
    WHERE rn = 1
),
benchmark_flagged AS (
    SELECT
        symbol, [date], [close], [return],
        CASE WHEN
            symbol IS NULL OR [date] IS NULL OR [close] IS NULL OR [return] IS NULL
        THEN 1 ELSE 0 END AS has_missing_value,
        CASE WHEN
            (symbol IS NOT NULL AND LEN(symbol) > 10)
        OR ([date] IS NOT NULL AND LEN(TRY_CAST([date] AS DATE)) > 255)
        OR ([close] IS NOT NULL AND TRY_CAST([close] AS DECIMAL(18,6)) IS NULL)
        OR ([return] IS NOT NULL AND TRY_CAST([return] AS DECIMAL(18,6)) IS NULL)
        THEN 1 ELSE 0 END AS has_invalid_value,
        CASE WHEN
            [return] < -1.0 OR [return] > 1.0
        THEN 1 ELSE 0 END AS has_outlier_value
    FROM BENCHMARK_cleaned
)
MERGE silver.benchmark_prices AS tgt
USING benchmark_flagged AS src
    ON tgt.symbol = src.symbol AND tgt.[date] = src.[date]
WHEN MATCHED THEN
    UPDATE SET
        [close] = src.[close],
        [return] = src.[return],
        tgt.has_missing_value = src.has_missing_value,
        tgt.has_invalid_value = src.has_invalid_value,
        tgt.has_outlier_value = src.has_outlier_value
WHEN NOT MATCHED THEN
    INSERT (symbol, [date], [close], [return], has_missing_value, has_invalid_value, has_outlier_value)
    VALUES (src.symbol, src.[date], src.[close], src.[return], src.has_missing_value, src.has_invalid_value, src.has_outlier_value)
;
GO


SELECT
    SUM(CAST(has_missing_value AS INT)) AS rows_missing,
    SUM(CAST(has_invalid_value AS INT)) AS rows_invalid,
    SUM(CAST(has_outlier_value AS INT)) AS rows_outlier
FROM silver.benchmark_prices;
GO
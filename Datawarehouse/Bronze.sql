IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
    EXEC('bronze');
IF OBJECT_ID('bronze.market', 'U') IS NULL
CREATE TABLE bronze.market (
    bronze_id INT IDENTITY(1,1) PRIMARY KEY,
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
INSERT INTO bronze.market (
    ticker,
    [date],
    [open],
    high,
    low,
    [close],
    volume,
    [return],
    next_day_return
)
SELECT ticker, [date], [open], high, low, [close], volume, [return], next_day_return
FROM staging.market
EXCEPT
SELECT ticker, [date], [open], high, low, [close], volume, [return], next_day_return
FROM bronze.market;

IF OBJECT_ID('bronze.news', 'U') IS NULL
CREATE TABLE bronze.news (
    bronze_id INT IDENTITY(1,1) PRIMARY KEY,
    news_id NVARCHAR(255),
    article_id NVARCHAR(255),
    ticker NVARCHAR(255),
    published_at NVARCHAR(255),
    [date] NVARCHAR(255),
    title NVARCHAR(MAX),
    summary NVARCHAR(MAX),
    [source] NVARCHAR(255),
    url NVARCHAR(MAX),
    n_project_tickers NVARCHAR(255),
    n_symbols_total NVARCHAR(255),
    finbert_label NVARCHAR(255),
    finbert_positive NVARCHAR(255),
    finbert_negative NVARCHAR(255),
    finbert_neutral NVARCHAR(255),
    finbert_score NVARCHAR(255)
);
INSERT INTO bronze.news (
    news_id,
    article_id,
    ticker,
    published_at,
    [date],
    title,
    summary,
    [source],
    url,
    n_project_tickers,
    n_symbols_total,
    finbert_label,
    finbert_positive,
    finbert_negative,
    finbert_neutral,
    finbert_score
)
SELECT news_id, article_id, ticker, published_at, [date], title, summary, [source], url, n_project_tickers, n_symbols_total, finbert_label, finbert_positive, finbert_negative, finbert_neutral, finbert_score
FROM staging.news_clean
EXCEPT
SELECT news_id, article_id, ticker, published_at, [date], title, summary, [source], url, n_project_tickers, n_symbols_total, finbert_label, finbert_positive, finbert_negative, finbert_neutral, finbert_score
FROM bronze.news;


IF OBJECT_ID('bronze.artcl_senti', 'U') IS NULL
CREATE TABLE bronze.artcl_senti (
    bronze_id INT IDENTITY(1,1) PRIMARY KEY,
    article_id NVARCHAR(255),
    published_at NVARCHAR(255),
    updated_at NVARCHAR(255),
    title NVARCHAR(MAX),
    summary NVARCHAR(MAX),
    author NVARCHAR(255),
    [source] NVARCHAR(255),
    url NVARCHAR(MAX),
    symbols_raw NVARCHAR(MAX),
    symbols NVARCHAR(MAX),
    finbert_label NVARCHAR(255),
    finbert_positive NVARCHAR(255),
    finbert_negative NVARCHAR(255),
    finbert_neutral NVARCHAR(255),
    finbert_score NVARCHAR(255),
    sentiment_text NVARCHAR(MAX),
    quality_missing_title NVARCHAR(255),
    quality_missing_published_at NVARCHAR(255)
);
INSERT INTO bronze.artcl_senti (
    article_id,
    published_at,
    updated_at,
    title,
    summary,
    author,
    [source],
    url,
    symbols_raw,
    symbols,
    finbert_label,
    finbert_positive,
    finbert_negative,
    finbert_neutral,
    finbert_score,
    sentiment_text,
    quality_missing_title,
    quality_missing_published_at
)
SELECT article_id, published_at, updated_at, title, summary, author, [source], url, symbols_raw, symbols, finbert_label, finbert_positive, finbert_negative, finbert_neutral, finbert_score, sentiment_text, quality_missing_title, quality_missing_published_at
FROM staging.news_articles_sentiment
EXCEPT
SELECT article_id, published_at, updated_at, title, summary, author, [source], url, symbols_raw, symbols, finbert_label, finbert_positive, finbert_negative, finbert_neutral, finbert_score, sentiment_text, quality_missing_title, quality_missing_published_at
FROM bronze.artcl_senti;

IF OBJECT_ID('bronze.news_tickers', 'U') IS NULL
CREATE TABLE bronze.news_tickers (
    bronze_id INT IDENTITY(1,1) PRIMARY KEY,
    article_id NVARCHAR(255),
    ticker NVARCHAR(255),
    n_symbols_total NVARCHAR(255),
    n_project_tickers NVARCHAR(255),
    published_at NVARCHAR(255),
    reaction_date NVARCHAR(255)
);
INSERT INTO bronze.news_tickers(
    article_id,
    ticker,
    n_symbols_total,
    n_project_tickers,
    published_at,
    reaction_date
)
SELECT article_id , ticker, n_symbols_total, n_project_tickers, published_at, reaction_date
FROM staging.news_tickers
EXCEPT
SELECT article_id , ticker, n_symbols_total, n_project_tickers, published_at, reaction_date
FROM bronze.news_tickers;

IF OBJECT_ID('bronze.companies', 'U') IS NULL
CREATE TABLE bronze.companies (
    bronze_id INT IDENTITY(1,1) PRIMARY KEY,
    ticker NVARCHAR(255),
    company_name NVARCHAR(255),
    sector NVARCHAR(255),
    industry NVARCHAR(255),
    currency NVARCHAR(225),
    cik NVARCHAR(255),
);
INSERT INTO bronze.companies(
    ticker,
    company_name,
    sector,
    industry,
    currency,
    cik
)
SELECT ticker , company_name , sector , industry , currency , cik
FROM staging.companies
EXCEPT
SELECT ticker , company_name , sector , industry , currency , cik
FROM bronze.companies;


IF OBJECT_ID('bronze.events', 'U') IS NULL
CREATE TABLE bronze.events (
    bronze_id INT IDENTITY(1,1) PRIMARY KEY,
    event_id NVARCHAR(255),
    ticker NVARCHAR(255),
    event_type NVARCHAR(255),
    event_date NVARCHAR(255),
    reaction_date NVARCHAR(255),
    after_close NVARCHAR(255),
    eps_estimate NVARCHAR(255),
    eps_actual NVARCHAR(255),
    surprise_pct NVARCHAR(255),
    items NVARCHAR(255),
    items_description NVARCHAR(Max),
    accession_number NVARCHAR(255)
);

INSERT INTO bronze.events(
    event_id,
    ticker,
    event_type,
    event_date,
    reaction_date,
    after_close,
    eps_estimate,
    eps_actual,
    surprise_pct,
    items,
    items_description,
    accession_number
)
SELECT event_id, ticker, event_type, event_date, reaction_date, after_close, eps_estimate, eps_actual, surprise_pct, items, items_description, accession_number
FROM staging.events
EXCEPT
SELECT event_id, ticker, event_type, event_date, reaction_date, after_close, eps_estimate, eps_actual, surprise_pct, items, items_description, accession_number
FROM bronze.events;

IF OBJECT_ID('bronze.fundamentals', 'U') IS NULL
CREATE TABLE bronze.fundamentals (
    bronze_id INT IDENTITY(1,1) PRIMARY KEY,
    ticker NVARCHAR(255),
    period_end NVARCHAR(255),
    filing_date NVARCHAR(255),
    revenue NVARCHAR(255),
    net_income NVARCHAR(255),
    eps_diluted NVARCHAR(255),
    total_assets NVARCHAR(255),
    equity NVARCHAR(255),
    profit_margin NVARCHAR(255)
);
INSERT INTO bronze.fundamentals(
    ticker,
    period_end,
    filing_date,
    revenue,
    net_income,
    eps_diluted,
    total_assets,
    equity,
    profit_margin
)
SELECT ticker, period_end, filing_date, revenue, net_income, eps_diluted, total_assets, equity, profit_margin
FROM staging.fundamentals
EXCEPT
SELECT ticker, period_end, filing_date, revenue, net_income, eps_diluted, total_assets, equity, profit_margin
FROM bronze.fundamentals;

IF OBJECT_ID('bronze.monthly_risk', 'U') IS NULL
CREATE TABLE bronze.monthly_risk (
    bronze_id INT IDENTITY(1,1) PRIMARY KEY,
    ticker NVARCHAR(255),
    [date] NVARCHAR(255),
    volatility_30d NVARCHAR(255),
    max_drawdown NVARCHAR(255)
);
INSERT INTO bronze.monthly_risk(
    ticker,
    [date],
    volatility_30d,
    max_drawdown
)
SELECT ticker, [date], volatility_30d, max_drawdown
FROM staging.monthly_risk
EXCEPT
SELECT ticker, [date], volatility_30d, max_drawdown
FROM bronze.monthly_risk;

IF OBJECT_ID('bronze.market_features', 'U') IS NULL
CREATE TABLE bronze.market_features (
    bronze_id INT IDENTITY(1,1) PRIMARY KEY,
    ticker           NVARCHAR(255),
    [date]           NVARCHAR(255),
    [open]           NVARCHAR(255),
    high             NVARCHAR(255),
    low              NVARCHAR(255),
    [close]          NVARCHAR(255),
    volume           NVARCHAR(255),
    [return]         NVARCHAR(255),
    cumulative_return  NVARCHAR(255),
    ma20              NVARCHAR(255),
    ma50              NVARCHAR(255),
    ma200             NVARCHAR(255),
    rolling_volatility NVARCHAR(255),
    volume_change NVARCHAR(255),
    volume_ma20 NVARCHAR(255)
);
INSERT INTO bronze.market_features (
    ticker,
    [date],
    [open],
    high,
    low,
    [close],
    volume,
    [return],
    cumulative_return,
    ma20,
    ma50,
    ma200,
    rolling_volatility,
    volume_change,
    volume_ma20
)
SELECT ticker, [date], [open], high, low, [close], volume, [return], cumulative_return, ma20, ma50, ma200, rolling_volatility, volume_change, volume_ma20
FROM staging.market_features
EXCEPT
SELECT ticker, [date], [open], high, low, [close], volume, [return], cumulative_return, ma20, ma50, ma200, rolling_volatility, volume_change, volume_ma20
FROM bronze.market_features;

IF OBJECT_ID('bronze.risk_metrics', 'U') IS NULL
CREATE TABLE bronze.risk_metrics (
    bronze_id INT IDENTITY(1,1) PRIMARY KEY,
    ticker NVARCHAR(255),
    daily_volatility NVARCHAR(255),
    annualized_volatility NVARCHAR(255),
    max_drawdown NVARCHAR(255),
    sharpe_ratio NVARCHAR(255),
    var_95_hist NVARCHAR(255),
    var_95_param NVARCHAR(255),
    var_99_hist NVARCHAR(255),
    var_99_param NVARCHAR(255)
);
INSERT INTO bronze.risk_metrics (
    ticker,
    daily_volatility,
    annualized_volatility,
    max_drawdown,
    sharpe_ratio,
    var_95_hist,
    var_95_param,
    var_99_hist,
    var_99_param
)
SELECT ticker, daily_volatility, annualized_volatility, max_drawdown, sharpe_ratio, var_95_hist, var_95_param, var_99_hist, var_99_param
FROM staging.risk_metrics
EXCEPT
SELECT ticker, daily_volatility, annualized_volatility, max_drawdown, sharpe_ratio, var_95_hist, var_95_param, var_99_hist, var_99_param
FROM bronze.risk_metrics;

IF OBJECT_ID('bronze.correlation_matrix', 'U') IS NULL
CREATE TABLE bronze.correlation_matrix (
    bronze_id INT IDENTITY(1,1) PRIMARY KEY,
    ticker NVARCHAR(255),
    AAPL NVARCHAR(255),
    AMZN NVARCHAR(255),
    JNJ NVARCHAR(255),
    JPM NVARCHAR(255),
    KO NVARCHAR(255),
    LLY NVARCHAR(255),
    MSFT NVARCHAR(255),
    NVDA NVARCHAR(255),
    TSLA NVARCHAR(255),
    XOM NVARCHAR(255)
);

INSERT INTO bronze.correlation_matrix (
    ticker,
    AAPL,
    AMZN,
    JNJ,
    JPM,
    KO,
    LLY,
    MSFT,
    NVDA,
    TSLA,
    XOM
)
SELECT ticker, AAPL, AMZN, JNJ, JPM, KO, LLY, MSFT, NVDA, TSLA, XOM
FROM staging.correlation_matrix
EXCEPT
SELECT ticker, AAPL, AMZN, JNJ, JPM, KO, LLY, MSFT, NVDA, TSLA, XOM
FROM bronze.correlation_matrix;

IF OBJECT_ID('bronze.benchmark_prices', 'U') IS NULL
CREATE TABLE bronze.benchmark_prices (
    bronze_id INT IDENTITY(1,1) PRIMARY KEY,
    symbol NVARCHAR(255),
    [date] NVARCHAR(255),
    [close] NVARCHAR(255),
    [return] NVARCHAR(255)
);

INSERT INTO bronze.benchmark_prices (
    symbol,
    [date],
    [close],
    [return]
)
SELECT symbol, [date], [close], [return]
FROM staging.benchmark_prices
EXCEPT
SELECT symbol, [date], [close], [return]
FROM bronze.benchmark_prices;


# Data dictionary

Generated from the live database. Key: PK = primary key.

## Summary

| schema | table | columns |
|---|---|---|
| bronze | artcl_senti | 19 |
| bronze | benchmark_prices | 5 |
| bronze | companies | 7 |
| bronze | correlation_matrix | 12 |
| bronze | events | 13 |
| bronze | fundamentals | 10 |
| bronze | market | 10 |
| bronze | market_features | 16 |
| bronze | monthly_risk | 5 |
| bronze | news_tickers | 7 |
| bronze | risk_metrics | 10 |
| gold | dim_company | 7 |
| gold | dim_date | 9 |
| gold | fact_article_sentiment | 14 |
| gold | fact_benchmark_prices | 4 |
| gold | fact_correlation | 3 |
| gold | fact_events | 12 |
| gold | fact_fundamentals | 11 |
| gold | fact_market_daily (view) | 20 |
| gold | fact_market_features | 15 |
| gold | fact_market_prices | 9 |
| gold | fact_monthly_risk | 4 |
| gold | fact_news_tickers | 7 |
| gold | fact_risk_summary | 9 |
| silver | artcl_senti | 21 |
| silver | benchmark_prices | 7 |
| silver | companies | 9 |
| silver | correlation_matrix | 14 |
| silver | events | 15 |
| silver | fundamentals | 12 |
| silver | market_features | 18 |
| silver | market_prices | 12 |
| silver | monthly_risk | 7 |
| silver | news_tickers | 9 |
| silver | risk_metrics | 12 |
| staging | benchmark_prices | 4 |
| staging | companies | 6 |
| staging | correlation_matrix | 11 |
| staging | events | 12 |
| staging | fundamentals | 9 |
| staging | market | 9 |
| staging | market_features | 15 |
| staging | monthly_risk | 4 |
| staging | news_articles_sentiment | 18 |
| staging | news_clean | 16 |
| staging | news_tickers | 6 |
| staging | risk_metrics | 9 |

## bronze

### bronze.artcl_senti

19 columns: `bronze_id`, `article_id`, `published_at`, `updated_at`, `title`, `summary`, `author`, `source`, `url`, `symbols_raw`, `symbols`, `finbert_label`, `finbert_positive`, `finbert_negative`, `finbert_neutral`, `finbert_score`, `sentiment_text`, `quality_missing_title`, `quality_missing_published_at`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | bronze_id | int | no | PK |
| 2 | article_id | nvarchar(255) | yes |  |
| 3 | published_at | nvarchar(255) | yes |  |
| 4 | updated_at | nvarchar(255) | yes |  |
| 5 | title | nvarchar(max) | yes |  |
| 6 | summary | nvarchar(max) | yes |  |
| 7 | author | nvarchar(255) | yes |  |
| 8 | source | nvarchar(255) | yes |  |
| 9 | url | nvarchar(max) | yes |  |
| 10 | symbols_raw | nvarchar(max) | yes |  |
| 11 | symbols | nvarchar(max) | yes |  |
| 12 | finbert_label | nvarchar(255) | yes |  |
| 13 | finbert_positive | nvarchar(255) | yes |  |
| 14 | finbert_negative | nvarchar(255) | yes |  |
| 15 | finbert_neutral | nvarchar(255) | yes |  |
| 16 | finbert_score | nvarchar(255) | yes |  |
| 17 | sentiment_text | nvarchar(max) | yes |  |
| 18 | quality_missing_title | nvarchar(255) | yes |  |
| 19 | quality_missing_published_at | nvarchar(255) | yes |  |

### bronze.benchmark_prices

5 columns: `bronze_id`, `symbol`, `date`, `close`, `return`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | bronze_id | int | no | PK |
| 2 | symbol | nvarchar(255) | yes |  |
| 3 | date | nvarchar(255) | yes |  |
| 4 | close | nvarchar(255) | yes |  |
| 5 | return | nvarchar(255) | yes |  |

### bronze.companies

7 columns: `bronze_id`, `ticker`, `company_name`, `sector`, `industry`, `currency`, `cik`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | bronze_id | int | no | PK |
| 2 | ticker | nvarchar(255) | yes |  |
| 3 | company_name | nvarchar(255) | yes |  |
| 4 | sector | nvarchar(255) | yes |  |
| 5 | industry | nvarchar(255) | yes |  |
| 6 | currency | nvarchar(225) | yes |  |
| 7 | cik | nvarchar(255) | yes |  |

### bronze.correlation_matrix

12 columns: `bronze_id`, `ticker`, `AAPL`, `AMZN`, `JNJ`, `JPM`, `KO`, `LLY`, `MSFT`, `NVDA`, `TSLA`, `XOM`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | bronze_id | int | no | PK |
| 2 | ticker | nvarchar(255) | yes |  |
| 3 | AAPL | nvarchar(255) | yes |  |
| 4 | AMZN | nvarchar(255) | yes |  |
| 5 | JNJ | nvarchar(255) | yes |  |
| 6 | JPM | nvarchar(255) | yes |  |
| 7 | KO | nvarchar(255) | yes |  |
| 8 | LLY | nvarchar(255) | yes |  |
| 9 | MSFT | nvarchar(255) | yes |  |
| 10 | NVDA | nvarchar(255) | yes |  |
| 11 | TSLA | nvarchar(255) | yes |  |
| 12 | XOM | nvarchar(255) | yes |  |

### bronze.events

13 columns: `bronze_id`, `event_id`, `ticker`, `event_type`, `event_date`, `reaction_date`, `after_close`, `eps_estimate`, `eps_actual`, `surprise_pct`, `items`, `items_description`, `accession_number`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | bronze_id | int | no | PK |
| 2 | event_id | nvarchar(255) | yes |  |
| 3 | ticker | nvarchar(255) | yes |  |
| 4 | event_type | nvarchar(255) | yes |  |
| 5 | event_date | nvarchar(255) | yes |  |
| 6 | reaction_date | nvarchar(255) | yes |  |
| 7 | after_close | nvarchar(255) | yes |  |
| 8 | eps_estimate | nvarchar(255) | yes |  |
| 9 | eps_actual | nvarchar(255) | yes |  |
| 10 | surprise_pct | nvarchar(255) | yes |  |
| 11 | items | nvarchar(255) | yes |  |
| 12 | items_description | nvarchar(max) | yes |  |
| 13 | accession_number | nvarchar(255) | yes |  |

### bronze.fundamentals

10 columns: `bronze_id`, `ticker`, `period_end`, `filing_date`, `revenue`, `net_income`, `eps_diluted`, `total_assets`, `equity`, `profit_margin`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | bronze_id | int | no | PK |
| 2 | ticker | nvarchar(255) | yes |  |
| 3 | period_end | nvarchar(255) | yes |  |
| 4 | filing_date | nvarchar(255) | yes |  |
| 5 | revenue | nvarchar(255) | yes |  |
| 6 | net_income | nvarchar(255) | yes |  |
| 7 | eps_diluted | nvarchar(255) | yes |  |
| 8 | total_assets | nvarchar(255) | yes |  |
| 9 | equity | nvarchar(255) | yes |  |
| 10 | profit_margin | nvarchar(255) | yes |  |

### bronze.market

10 columns: `bronze_id`, `ticker`, `date`, `open`, `high`, `low`, `close`, `volume`, `return`, `next_day_return`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | bronze_id | int | no | PK |
| 2 | ticker | nvarchar(255) | yes |  |
| 3 | date | nvarchar(255) | yes |  |
| 4 | open | nvarchar(255) | yes |  |
| 5 | high | nvarchar(255) | yes |  |
| 6 | low | nvarchar(255) | yes |  |
| 7 | close | nvarchar(255) | yes |  |
| 8 | volume | nvarchar(255) | yes |  |
| 9 | return | nvarchar(255) | yes |  |
| 10 | next_day_return | nvarchar(255) | yes |  |

### bronze.market_features

16 columns: `bronze_id`, `ticker`, `date`, `open`, `high`, `low`, `close`, `volume`, `return`, `cumulative_return`, `ma20`, `ma50`, `ma200`, `rolling_volatility`, `volume_change`, `volume_ma20`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | bronze_id | int | no | PK |
| 2 | ticker | nvarchar(255) | yes |  |
| 3 | date | nvarchar(255) | yes |  |
| 4 | open | nvarchar(255) | yes |  |
| 5 | high | nvarchar(255) | yes |  |
| 6 | low | nvarchar(255) | yes |  |
| 7 | close | nvarchar(255) | yes |  |
| 8 | volume | nvarchar(255) | yes |  |
| 9 | return | nvarchar(255) | yes |  |
| 10 | cumulative_return | nvarchar(255) | yes |  |
| 11 | ma20 | nvarchar(255) | yes |  |
| 12 | ma50 | nvarchar(255) | yes |  |
| 13 | ma200 | nvarchar(255) | yes |  |
| 14 | rolling_volatility | nvarchar(255) | yes |  |
| 15 | volume_change | nvarchar(255) | yes |  |
| 16 | volume_ma20 | nvarchar(255) | yes |  |

### bronze.monthly_risk

5 columns: `bronze_id`, `ticker`, `date`, `volatility_30d`, `max_drawdown`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | bronze_id | int | no | PK |
| 2 | ticker | nvarchar(255) | yes |  |
| 3 | date | nvarchar(255) | yes |  |
| 4 | volatility_30d | nvarchar(255) | yes |  |
| 5 | max_drawdown | nvarchar(255) | yes |  |

### bronze.news_tickers

7 columns: `bronze_id`, `article_id`, `ticker`, `n_symbols_total`, `n_project_tickers`, `published_at`, `reaction_date`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | bronze_id | int | no | PK |
| 2 | article_id | nvarchar(255) | yes |  |
| 3 | ticker | nvarchar(255) | yes |  |
| 4 | n_symbols_total | nvarchar(255) | yes |  |
| 5 | n_project_tickers | nvarchar(255) | yes |  |
| 6 | published_at | nvarchar(255) | yes |  |
| 7 | reaction_date | nvarchar(255) | yes |  |

### bronze.risk_metrics

10 columns: `bronze_id`, `ticker`, `daily_volatility`, `annualized_volatility`, `max_drawdown`, `sharpe_ratio`, `var_95_hist`, `var_95_param`, `var_99_hist`, `var_99_param`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | bronze_id | int | no | PK |
| 2 | ticker | nvarchar(255) | yes |  |
| 3 | daily_volatility | nvarchar(255) | yes |  |
| 4 | annualized_volatility | nvarchar(255) | yes |  |
| 5 | max_drawdown | nvarchar(255) | yes |  |
| 6 | sharpe_ratio | nvarchar(255) | yes |  |
| 7 | var_95_hist | nvarchar(255) | yes |  |
| 8 | var_95_param | nvarchar(255) | yes |  |
| 9 | var_99_hist | nvarchar(255) | yes |  |
| 10 | var_99_param | nvarchar(255) | yes |  |

## gold

### gold.dim_company

7 columns: `company_key`, `ticker`, `company_name`, `sector`, `industry`, `currency`, `cik`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | company_key | int | no | PK |
| 2 | ticker | nvarchar(10) | no |  |
| 3 | company_name | nvarchar(150) | yes |  |
| 4 | sector | nvarchar(50) | yes |  |
| 5 | industry | nvarchar(100) | yes |  |
| 6 | currency | nvarchar(10) | yes |  |
| 7 | cik | int | yes |  |

### gold.dim_date

9 columns: `date_key`, `date`, `year`, `quarter`, `month_number`, `month_name`, `year_month`, `is_trading_day`, `is_month_end_trading_day`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | date_key | int | no | PK |
| 2 | date | date | no |  |
| 3 | year | smallint | no |  |
| 4 | quarter | tinyint | no |  |
| 5 | month_number | tinyint | no |  |
| 6 | month_name | nvarchar(10) | no |  |
| 7 | year_month | char(7) | no |  |
| 8 | is_trading_day | bit | no |  |
| 9 | is_month_end_trading_day | bit | no |  |

### gold.fact_article_sentiment

14 columns: `published_date_key`, `article_id`, `published_at`, `updated_at`, `title`, `author`, `source`, `url`, `symbols`, `finbert_label`, `finbert_positive`, `finbert_negative`, `finbert_neutral`, `finbert_score`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | published_date_key | int | yes |  |
| 2 | article_id | int | no | PK |
| 3 | published_at | datetime | yes |  |
| 4 | updated_at | datetime | yes |  |
| 5 | title | nvarchar(max) | yes |  |
| 6 | author | nvarchar(255) | yes |  |
| 7 | source | nvarchar(100) | yes |  |
| 8 | url | nvarchar(max) | yes |  |
| 9 | symbols | nvarchar(max) | yes |  |
| 10 | finbert_label | nvarchar(20) | yes |  |
| 11 | finbert_positive | float | yes |  |
| 12 | finbert_negative | float | yes |  |
| 13 | finbert_neutral | float | yes |  |
| 14 | finbert_score | float | yes |  |

### gold.fact_benchmark_prices

4 columns: `date_key`, `benchmark_symbol`, `close`, `return`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | date_key | int | no | PK |
| 2 | benchmark_symbol | nvarchar(10) | no | PK |
| 3 | close | decimal(18,8) | yes |  |
| 4 | return | decimal(18,8) | yes |  |

### gold.fact_correlation

3 columns: `company_key`, `peer_company_key`, `correlation`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | company_key | int | no | PK |
| 2 | peer_company_key | int | no | PK |
| 3 | correlation | decimal(18,8) | yes |  |

### gold.fact_events

12 columns: `company_key`, `event_date_key`, `reaction_date_key`, `event_id`, `event_type`, `after_close`, `eps_estimate`, `eps_actual`, `surprise_pct`, `items`, `items_description`, `accession_number`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | company_key | int | no |  |
| 2 | event_date_key | int | yes |  |
| 3 | reaction_date_key | int | yes |  |
| 4 | event_id | int | no | PK |
| 5 | event_type | nvarchar(25) | yes |  |
| 6 | after_close | bit | yes |  |
| 7 | eps_estimate | decimal(18,4) | yes |  |
| 8 | eps_actual | decimal(18,4) | yes |  |
| 9 | surprise_pct | decimal(18,4) | yes |  |
| 10 | items | nvarchar(100) | yes |  |
| 11 | items_description | nvarchar(max) | yes |  |
| 12 | accession_number | nvarchar(255) | yes |  |

### gold.fact_fundamentals

11 columns: `company_key`, `period_end_date_key`, `filing_date_key`, `period_end`, `filing_date`, `revenue`, `net_income`, `eps_diluted`, `total_assets`, `equity`, `profit_margin`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | company_key | int | no | PK |
| 2 | period_end_date_key | int | yes |  |
| 3 | filing_date_key | int | yes |  |
| 4 | period_end | date | no | PK |
| 5 | filing_date | date | yes |  |
| 6 | revenue | decimal(18,4) | yes |  |
| 7 | net_income | decimal(18,4) | yes |  |
| 8 | eps_diluted | decimal(18,4) | yes |  |
| 9 | total_assets | decimal(18,4) | yes |  |
| 10 | equity | decimal(18,4) | yes |  |
| 11 | profit_margin | decimal(18,4) | yes |  |

### gold.fact_market_daily (view)

20 columns: `date_key`, `company_key`, `open`, `high`, `low`, `close`, `volume`, `return`, `cumulative_return`, `ma20`, `ma50`, `ma200`, `rolling_volatility`, `volume_change`, `volume_ma20`, `volatility_30d`, `max_drawdown`, `benchmark_symbol`, `benchmark_close`, `benchmark_return`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | date_key | int | no |  |
| 2 | company_key | int | no |  |
| 3 | open | decimal(18,4) | yes |  |
| 4 | high | decimal(18,4) | yes |  |
| 5 | low | decimal(18,4) | yes |  |
| 6 | close | decimal(18,4) | yes |  |
| 7 | volume | bigint | yes |  |
| 8 | return | decimal(18,6) | yes |  |
| 9 | cumulative_return | decimal(18,6) | yes |  |
| 10 | ma20 | decimal(18,4) | yes |  |
| 11 | ma50 | decimal(18,4) | yes |  |
| 12 | ma200 | decimal(18,4) | yes |  |
| 13 | rolling_volatility | decimal(18,6) | yes |  |
| 14 | volume_change | decimal(18,6) | yes |  |
| 15 | volume_ma20 | decimal(18,4) | yes |  |
| 16 | volatility_30d | decimal(18,6) | yes |  |
| 17 | max_drawdown | decimal(18,6) | yes |  |
| 18 | benchmark_symbol | nvarchar(10) | yes |  |
| 19 | benchmark_close | decimal(18,8) | yes |  |
| 20 | benchmark_return | decimal(18,8) | yes |  |

### gold.fact_market_features

15 columns: `company_key`, `date_key`, `open`, `high`, `low`, `close`, `volume`, `return`, `cumulative_return`, `ma20`, `ma50`, `ma200`, `rolling_volatility`, `volume_change`, `volume_ma20`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | company_key | int | no | PK |
| 2 | date_key | int | no | PK |
| 3 | open | decimal(18,4) | yes |  |
| 4 | high | decimal(18,4) | yes |  |
| 5 | low | decimal(18,4) | yes |  |
| 6 | close | decimal(18,4) | yes |  |
| 7 | volume | bigint | yes |  |
| 8 | return | decimal(18,6) | yes |  |
| 9 | cumulative_return | decimal(18,6) | yes |  |
| 10 | ma20 | decimal(18,4) | yes |  |
| 11 | ma50 | decimal(18,4) | yes |  |
| 12 | ma200 | decimal(18,4) | yes |  |
| 13 | rolling_volatility | decimal(18,6) | yes |  |
| 14 | volume_change | decimal(18,6) | yes |  |
| 15 | volume_ma20 | decimal(18,4) | yes |  |

### gold.fact_market_prices

9 columns: `company_key`, `date_key`, `open`, `high`, `low`, `close`, `volume`, `return`, `next_day_return`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | company_key | int | no | PK |
| 2 | date_key | int | no | PK |
| 3 | open | decimal(18,4) | yes |  |
| 4 | high | decimal(18,4) | yes |  |
| 5 | low | decimal(18,4) | yes |  |
| 6 | close | decimal(18,4) | yes |  |
| 7 | volume | bigint | yes |  |
| 8 | return | decimal(18,6) | yes |  |
| 9 | next_day_return | decimal(18,6) | yes |  |

### gold.fact_monthly_risk

4 columns: `company_key`, `date_key`, `volatility_30d`, `max_drawdown`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | company_key | int | no | PK |
| 2 | date_key | int | no | PK |
| 3 | volatility_30d | decimal(18,6) | yes |  |
| 4 | max_drawdown | decimal(18,6) | yes |  |

### gold.fact_news_tickers

7 columns: `company_key`, `published_date_key`, `reaction_date_key`, `article_id`, `published_at`, `n_symbols_total`, `n_project_tickers`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | company_key | int | no | PK |
| 2 | published_date_key | int | yes |  |
| 3 | reaction_date_key | int | yes |  |
| 4 | article_id | int | no | PK |
| 5 | published_at | datetime | yes |  |
| 6 | n_symbols_total | int | yes |  |
| 7 | n_project_tickers | int | yes |  |

### gold.fact_risk_summary

9 columns: `company_key`, `daily_volatility`, `annualized_volatility`, `max_drawdown`, `sharpe_ratio`, `var_95_hist`, `var_95_param`, `var_99_hist`, `var_99_param`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | company_key | int | no | PK |
| 2 | daily_volatility | decimal(18,8) | yes |  |
| 3 | annualized_volatility | decimal(18,8) | yes |  |
| 4 | max_drawdown | decimal(18,8) | yes |  |
| 5 | sharpe_ratio | decimal(18,8) | yes |  |
| 6 | var_95_hist | decimal(18,8) | yes |  |
| 7 | var_95_param | decimal(18,8) | yes |  |
| 8 | var_99_hist | decimal(18,8) | yes |  |
| 9 | var_99_param | decimal(18,8) | yes |  |

## silver

### silver.artcl_senti

21 columns: `article_id`, `published_at`, `updated_at`, `title`, `summary`, `author`, `source`, `url`, `symbols_raw`, `symbols`, `finbert_label`, `finbert_positive`, `finbert_negative`, `finbert_neutral`, `finbert_score`, `sentiment_text`, `quality_missing_title`, `quality_missing_published_at`, `has_missing_value`, `has_invalid_value`, `has_outlier_value`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | article_id | int | no | PK |
| 2 | published_at | datetime | yes |  |
| 3 | updated_at | datetime | yes |  |
| 4 | title | nvarchar(max) | yes |  |
| 5 | summary | nvarchar(max) | yes |  |
| 6 | author | nvarchar(50) | yes |  |
| 7 | source | nvarchar(25) | yes |  |
| 8 | url | nvarchar(max) | yes |  |
| 9 | symbols_raw | nvarchar(max) | yes |  |
| 10 | symbols | nvarchar(max) | yes |  |
| 11 | finbert_label | nvarchar(20) | yes |  |
| 12 | finbert_positive | float | yes |  |
| 13 | finbert_negative | float | yes |  |
| 14 | finbert_neutral | float | yes |  |
| 15 | finbert_score | float | yes |  |
| 16 | sentiment_text | nvarchar(max) | yes |  |
| 17 | quality_missing_title | nvarchar(25) | yes |  |
| 18 | quality_missing_published_at | nvarchar(25) | yes |  |
| 19 | has_missing_value | bit | no |  |
| 20 | has_invalid_value | bit | no |  |
| 21 | has_outlier_value | bit | no |  |

### silver.benchmark_prices

7 columns: `symbol`, `date`, `close`, `return`, `has_missing_value`, `has_invalid_value`, `has_outlier_value`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | symbol | nvarchar(10) | no | PK |
| 2 | date | date | no | PK |
| 3 | close | decimal(18,6) | yes |  |
| 4 | return | decimal(18,6) | yes |  |
| 5 | has_missing_value | bit | no |  |
| 6 | has_invalid_value | bit | no |  |
| 7 | has_outlier_value | bit | no |  |

### silver.companies

9 columns: `ticker`, `company_name`, `sector`, `industry`, `currency`, `cik`, `has_missing_value`, `has_invalid_value`, `has_outlier_value`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | ticker | nvarchar(10) | no | PK |
| 2 | company_name | nvarchar(150) | no |  |
| 3 | sector | nvarchar(50) | no |  |
| 4 | industry | nvarchar(100) | no |  |
| 5 | currency | nvarchar(10) | no |  |
| 6 | cik | int | yes |  |
| 7 | has_missing_value | bit | no |  |
| 8 | has_invalid_value | bit | no |  |
| 9 | has_outlier_value | bit | no |  |

### silver.correlation_matrix

14 columns: `ticker`, `AAPL`, `AMZN`, `JNJ`, `JPM`, `KO`, `LLY`, `MSFT`, `NVDA`, `TSLA`, `XOM`, `has_missing_value`, `has_invalid_value`, `has_outlier_value`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | ticker | nvarchar(10) | no | PK |
| 2 | AAPL | decimal(18,6) | yes |  |
| 3 | AMZN | decimal(18,6) | yes |  |
| 4 | JNJ | decimal(18,6) | yes |  |
| 5 | JPM | decimal(18,6) | yes |  |
| 6 | KO | decimal(18,6) | yes |  |
| 7 | LLY | decimal(18,6) | yes |  |
| 8 | MSFT | decimal(18,6) | yes |  |
| 9 | NVDA | decimal(18,6) | yes |  |
| 10 | TSLA | decimal(18,6) | yes |  |
| 11 | XOM | decimal(18,6) | yes |  |
| 12 | has_missing_value | bit | no |  |
| 13 | has_invalid_value | bit | no |  |
| 14 | has_outlier_value | bit | no |  |

### silver.events

15 columns: `event_id`, `ticker`, `event_type`, `event_date`, `reaction_date`, `after_close`, `eps_estimate`, `eps_actual`, `surprise_pct`, `items`, `items_description`, `accession_number`, `has_missing_value`, `has_invalid_value`, `has_outlier_value`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | event_id | int | no | PK |
| 2 | ticker | nvarchar(10) | no |  |
| 3 | event_type | nvarchar(25) | no |  |
| 4 | event_date | date | no |  |
| 5 | reaction_date | date | no |  |
| 6 | after_close | bit | yes |  |
| 7 | eps_estimate | decimal(18,4) | yes |  |
| 8 | eps_actual | decimal(18,4) | yes |  |
| 9 | surprise_pct | decimal(18,4) | yes |  |
| 10 | items | nvarchar(100) | yes |  |
| 11 | items_description | nvarchar(max) | yes |  |
| 12 | accession_number | nvarchar(255) | yes |  |
| 13 | has_missing_value | bit | no |  |
| 14 | has_invalid_value | bit | no |  |
| 15 | has_outlier_value | bit | no |  |

### silver.fundamentals

12 columns: `ticker`, `period_end`, `filing_date`, `revenue`, `net_income`, `eps_diluted`, `total_assets`, `equity`, `profit_margin`, `has_missing_value`, `has_invalid_value`, `has_outlier_value`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | ticker | nvarchar(10) | no | PK |
| 2 | period_end | date | no | PK |
| 3 | filing_date | date | no |  |
| 4 | revenue | decimal(18,4) | yes |  |
| 5 | net_income | decimal(18,4) | yes |  |
| 6 | eps_diluted | decimal(18,4) | yes |  |
| 7 | total_assets | decimal(18,4) | yes |  |
| 8 | equity | decimal(18,4) | yes |  |
| 9 | profit_margin | decimal(18,4) | yes |  |
| 10 | has_missing_value | bit | no |  |
| 11 | has_invalid_value | bit | no |  |
| 12 | has_outlier_value | bit | no |  |

### silver.market_features

18 columns: `ticker`, `date`, `open`, `high`, `low`, `close`, `volume`, `return`, `cumulative_return`, `ma20`, `ma50`, `ma200`, `rolling_volatility`, `volume_change`, `volume_ma20`, `has_missing_value`, `has_invalid_value`, `has_outlier_value`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | ticker | nvarchar(10) | no | PK |
| 2 | date | date | no | PK |
| 3 | open | decimal(18,4) | no |  |
| 4 | high | decimal(18,4) | no |  |
| 5 | low | decimal(18,4) | no |  |
| 6 | close | decimal(18,4) | no |  |
| 7 | volume | bigint | no |  |
| 8 | return | decimal(18,6) | yes |  |
| 9 | cumulative_return | decimal(18,6) | yes |  |
| 10 | ma20 | decimal(18,4) | yes |  |
| 11 | ma50 | decimal(18,4) | yes |  |
| 12 | ma200 | decimal(18,4) | yes |  |
| 13 | rolling_volatility | decimal(18,6) | yes |  |
| 14 | volume_change | decimal(18,6) | yes |  |
| 15 | volume_ma20 | decimal(18,4) | yes |  |
| 16 | has_missing_value | bit | no |  |
| 17 | has_invalid_value | bit | no |  |
| 18 | has_outlier_value | bit | no |  |

### silver.market_prices

12 columns: `ticker`, `date`, `open`, `high`, `low`, `close`, `volume`, `return`, `next_day_return`, `has_missing_value`, `has_invalid_value`, `has_outlier_value`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | ticker | nvarchar(10) | no | PK |
| 2 | date | date | no | PK |
| 3 | open | decimal(18,4) | no |  |
| 4 | high | decimal(18,4) | no |  |
| 5 | low | decimal(18,4) | no |  |
| 6 | close | decimal(18,4) | no |  |
| 7 | volume | bigint | no |  |
| 8 | return | decimal(18,6) | yes |  |
| 9 | next_day_return | decimal(18,6) | yes |  |
| 10 | has_missing_value | bit | no |  |
| 11 | has_invalid_value | bit | no |  |
| 12 | has_outlier_value | bit | no |  |

### silver.monthly_risk

7 columns: `ticker`, `date`, `volatility_30d`, `max_drawdown`, `has_missing_value`, `has_invalid_value`, `has_outlier_value`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | ticker | nvarchar(10) | no | PK |
| 2 | date | date | no | PK |
| 3 | volatility_30d | decimal(18,6) | yes |  |
| 4 | max_drawdown | decimal(18,6) | yes |  |
| 5 | has_missing_value | bit | no |  |
| 6 | has_invalid_value | bit | no |  |
| 7 | has_outlier_value | bit | no |  |

### silver.news_tickers

9 columns: `article_id`, `ticker`, `n_symbols_total`, `n_project_tickers`, `published_at`, `reaction_date`, `has_missing_value`, `has_invalid_value`, `has_outlier_value`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | article_id | int | no | PK |
| 2 | ticker | nvarchar(10) | no | PK |
| 3 | n_symbols_total | int | yes |  |
| 4 | n_project_tickers | int | yes |  |
| 5 | published_at | datetime | yes |  |
| 6 | reaction_date | datetime | yes |  |
| 7 | has_missing_value | bit | no |  |
| 8 | has_invalid_value | bit | no |  |
| 9 | has_outlier_value | bit | no |  |

### silver.risk_metrics

12 columns: `ticker`, `daily_volatility`, `annualized_volatility`, `max_drawdown`, `sharpe_ratio`, `var_95_hist`, `var_95_param`, `var_99_hist`, `var_99_param`, `has_missing_value`, `has_invalid_value`, `has_outlier_value`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | ticker | nvarchar(10) | no | PK |
| 2 | daily_volatility | decimal(18,8) | yes |  |
| 3 | annualized_volatility | decimal(18,8) | yes |  |
| 4 | max_drawdown | decimal(18,8) | yes |  |
| 5 | sharpe_ratio | decimal(18,8) | yes |  |
| 6 | var_95_hist | decimal(18,8) | yes |  |
| 7 | var_95_param | decimal(18,8) | yes |  |
| 8 | var_99_hist | decimal(18,8) | yes |  |
| 9 | var_99_param | decimal(18,8) | yes |  |
| 10 | has_missing_value | bit | no |  |
| 11 | has_invalid_value | bit | no |  |
| 12 | has_outlier_value | bit | no |  |

## staging

### staging.benchmark_prices

4 columns: `symbol`, `date`, `close`, `return`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | symbol | nvarchar(255) | yes |  |
| 2 | date | nvarchar(255) | yes |  |
| 3 | close | nvarchar(255) | yes |  |
| 4 | return | nvarchar(255) | yes |  |

### staging.companies

6 columns: `ticker`, `company_name`, `sector`, `industry`, `currency`, `cik`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | ticker | nvarchar(255) | yes |  |
| 2 | company_name | nvarchar(255) | yes |  |
| 3 | sector | nvarchar(255) | yes |  |
| 4 | industry | nvarchar(255) | yes |  |
| 5 | currency | nvarchar(255) | yes |  |
| 6 | cik | nvarchar(255) | yes |  |

### staging.correlation_matrix

11 columns: `ticker`, `AAPL`, `AMZN`, `JNJ`, `JPM`, `KO`, `LLY`, `MSFT`, `NVDA`, `TSLA`, `XOM`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | ticker | nvarchar(255) | yes |  |
| 2 | AAPL | nvarchar(255) | yes |  |
| 3 | AMZN | nvarchar(255) | yes |  |
| 4 | JNJ | nvarchar(255) | yes |  |
| 5 | JPM | nvarchar(255) | yes |  |
| 6 | KO | nvarchar(255) | yes |  |
| 7 | LLY | nvarchar(255) | yes |  |
| 8 | MSFT | nvarchar(255) | yes |  |
| 9 | NVDA | nvarchar(255) | yes |  |
| 10 | TSLA | nvarchar(255) | yes |  |
| 11 | XOM | nvarchar(255) | yes |  |

### staging.events

12 columns: `event_id`, `ticker`, `event_type`, `event_date`, `reaction_date`, `after_close`, `eps_estimate`, `eps_actual`, `surprise_pct`, `items`, `items_description`, `accession_number`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | event_id | nvarchar(255) | yes |  |
| 2 | ticker | nvarchar(255) | yes |  |
| 3 | event_type | nvarchar(255) | yes |  |
| 4 | event_date | nvarchar(255) | yes |  |
| 5 | reaction_date | nvarchar(255) | yes |  |
| 6 | after_close | nvarchar(255) | yes |  |
| 7 | eps_estimate | nvarchar(255) | yes |  |
| 8 | eps_actual | nvarchar(255) | yes |  |
| 9 | surprise_pct | nvarchar(255) | yes |  |
| 10 | items | nvarchar(255) | yes |  |
| 11 | items_description | nvarchar(255) | yes |  |
| 12 | accession_number | nvarchar(255) | yes |  |

### staging.fundamentals

9 columns: `ticker`, `period_end`, `filing_date`, `revenue`, `net_income`, `eps_diluted`, `total_assets`, `equity`, `profit_margin`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | ticker | nvarchar(255) | yes |  |
| 2 | period_end | nvarchar(255) | yes |  |
| 3 | filing_date | nvarchar(255) | yes |  |
| 4 | revenue | nvarchar(255) | yes |  |
| 5 | net_income | nvarchar(255) | yes |  |
| 6 | eps_diluted | nvarchar(255) | yes |  |
| 7 | total_assets | nvarchar(255) | yes |  |
| 8 | equity | nvarchar(255) | yes |  |
| 9 | profit_margin | nvarchar(255) | yes |  |

### staging.market

9 columns: `ticker`, `date`, `open`, `high`, `low`, `close`, `volume`, `return`, `next_day_return`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | ticker | nvarchar(255) | yes |  |
| 2 | date | nvarchar(255) | yes |  |
| 3 | open | nvarchar(255) | yes |  |
| 4 | high | nvarchar(255) | yes |  |
| 5 | low | nvarchar(255) | yes |  |
| 6 | close | nvarchar(255) | yes |  |
| 7 | volume | nvarchar(255) | yes |  |
| 8 | return | nvarchar(255) | yes |  |
| 9 | next_day_return | nvarchar(255) | yes |  |

### staging.market_features

15 columns: `ticker`, `date`, `open`, `high`, `low`, `close`, `volume`, `return`, `cumulative_return`, `ma20`, `ma50`, `ma200`, `rolling_volatility`, `volume_change`, `volume_ma20`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | ticker | nvarchar(255) | yes |  |
| 2 | date | nvarchar(255) | yes |  |
| 3 | open | nvarchar(255) | yes |  |
| 4 | high | nvarchar(255) | yes |  |
| 5 | low | nvarchar(255) | yes |  |
| 6 | close | nvarchar(255) | yes |  |
| 7 | volume | nvarchar(255) | yes |  |
| 8 | return | nvarchar(255) | yes |  |
| 9 | cumulative_return | nvarchar(255) | yes |  |
| 10 | ma20 | nvarchar(255) | yes |  |
| 11 | ma50 | nvarchar(255) | yes |  |
| 12 | ma200 | nvarchar(255) | yes |  |
| 13 | rolling_volatility | nvarchar(255) | yes |  |
| 14 | volume_change | nvarchar(255) | yes |  |
| 15 | volume_ma20 | nvarchar(255) | yes |  |

### staging.monthly_risk

4 columns: `ticker`, `date`, `volatility_30d`, `max_drawdown`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | ticker | nvarchar(255) | yes |  |
| 2 | date | nvarchar(255) | yes |  |
| 3 | volatility_30d | nvarchar(255) | yes |  |
| 4 | max_drawdown | nvarchar(255) | yes |  |

### staging.news_articles_sentiment

18 columns: `article_id`, `published_at`, `updated_at`, `title`, `summary`, `author`, `source`, `url`, `symbols_raw`, `symbols`, `finbert_label`, `finbert_positive`, `finbert_negative`, `finbert_neutral`, `finbert_score`, `sentiment_text`, `quality_missing_title`, `quality_missing_published_at`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | article_id | nvarchar(255) | yes |  |
| 2 | published_at | nvarchar(255) | yes |  |
| 3 | updated_at | nvarchar(255) | yes |  |
| 4 | title | nvarchar(4000) | yes |  |
| 5 | summary | nvarchar(4000) | yes |  |
| 6 | author | nvarchar(255) | yes |  |
| 7 | source | nvarchar(255) | yes |  |
| 8 | url | nvarchar(4000) | yes |  |
| 9 | symbols_raw | nvarchar(max) | yes |  |
| 10 | symbols | nvarchar(max) | yes |  |
| 11 | finbert_label | nvarchar(255) | yes |  |
| 12 | finbert_positive | nvarchar(255) | yes |  |
| 13 | finbert_negative | nvarchar(255) | yes |  |
| 14 | finbert_neutral | nvarchar(255) | yes |  |
| 15 | finbert_score | nvarchar(255) | yes |  |
| 16 | sentiment_text | nvarchar(4000) | yes |  |
| 17 | quality_missing_title | nvarchar(255) | yes |  |
| 18 | quality_missing_published_at | nvarchar(255) | yes |  |

### staging.news_clean

16 columns: `news_id`, `article_id`, `ticker`, `published_at`, `date`, `title`, `summary`, `source`, `url`, `n_project_tickers`, `n_symbols_total`, `finbert_label`, `finbert_positive`, `finbert_negative`, `finbert_neutral`, `finbert_score`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | news_id | nvarchar(255) | yes |  |
| 2 | article_id | nvarchar(255) | yes |  |
| 3 | ticker | nvarchar(255) | yes |  |
| 4 | published_at | nvarchar(255) | yes |  |
| 5 | date | nvarchar(255) | yes |  |
| 6 | title | nvarchar(4000) | yes |  |
| 7 | summary | nvarchar(4000) | yes |  |
| 8 | source | nvarchar(255) | yes |  |
| 9 | url | nvarchar(4000) | yes |  |
| 10 | n_project_tickers | nvarchar(255) | yes |  |
| 11 | n_symbols_total | nvarchar(255) | yes |  |
| 12 | finbert_label | nvarchar(255) | yes |  |
| 13 | finbert_positive | nvarchar(255) | yes |  |
| 14 | finbert_negative | nvarchar(255) | yes |  |
| 15 | finbert_neutral | nvarchar(255) | yes |  |
| 16 | finbert_score | nvarchar(255) | yes |  |

### staging.news_tickers

6 columns: `article_id`, `ticker`, `n_symbols_total`, `n_project_tickers`, `published_at`, `reaction_date`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | article_id | nvarchar(255) | yes |  |
| 2 | ticker | nvarchar(255) | yes |  |
| 3 | n_symbols_total | nvarchar(255) | yes |  |
| 4 | n_project_tickers | nvarchar(255) | yes |  |
| 5 | published_at | nvarchar(255) | yes |  |
| 6 | reaction_date | nvarchar(255) | yes |  |

### staging.risk_metrics

9 columns: `ticker`, `daily_volatility`, `annualized_volatility`, `max_drawdown`, `sharpe_ratio`, `var_95_hist`, `var_95_param`, `var_99_hist`, `var_99_param`

| # | column | type | nullable | key |
|---|---|---|---|---|
| 1 | ticker | nvarchar(255) | yes |  |
| 2 | daily_volatility | nvarchar(255) | yes |  |
| 3 | annualized_volatility | nvarchar(255) | yes |  |
| 4 | max_drawdown | nvarchar(255) | yes |  |
| 5 | sharpe_ratio | nvarchar(255) | yes |  |
| 6 | var_95_hist | nvarchar(255) | yes |  |
| 7 | var_95_param | nvarchar(255) | yes |  |
| 8 | var_99_hist | nvarchar(255) | yes |  |
| 9 | var_99_param | nvarchar(255) | yes |  |

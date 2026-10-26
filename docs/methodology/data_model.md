# Data Model

This document defines the integrated data model for the project: which tables we need, how they
connect, and what Power BI will eventually receive.

## 1. Decisions

| Question | Answer |
|---|---|
| What tables do we need? | `companies`, `market_prices`, `news_articles`, `news_tickers`, `events` (core). `fundamentals`, `risk` and `dim_date` are optional extensions. |
| How will they connect? | `companies` is the central dimension. Every other table links to it through `ticker`. News reaches `companies` through the `news_tickers` bridge table. |
| At what grain is news stored? | Two grains. `news_articles` has one row per unique Alpaca article. `news_tickers` has one row per unique article-ticker association. |
| What is `news_clean.csv`? | A flattened export, one row per article-ticker pair, derived from `news_articles` and `news_tickers`. It is a convenience file, not a second source of truth. |
| Which tickers are kept? | Only the ten project tickers: `AAPL`, `JPM`, `MSFT`, `NVDA`, `JNJ`, `XOM`, `KO`, `AMZN`, `LLY`, `TSLA`. Other tickers on an article are dropped from the ticker tables. |
| How is sentiment calculated? | By the project, once per article, with FinBERT (`ProsusAI/finbert`) on headline plus summary. `finbert_score = P(positive) - P(negative)`. Alpaca provides no sentiment score, so `av_score` is not part of this model. |
| What are `events`? | Structured earnings announcements and SEC 8-K filings only. General news articles do not automatically become events. |
| What will Power BI eventually receive? | `market_clean.csv` and `news_clean.csv` (required). `companies.csv` and `events_clean.csv` are recommended so relationships and slicers work (see section 5). `news_articles_sentiment.csv` and `news_tickers.csv` are the normalized alternative to `news_clean.csv`. |

## 2. Data model

```
                              companies
                              PK: ticker
                                  |
      +---------------+-----------+-----------+---------------+
      |               |                       |               |
 market_prices   news_tickers              events       fundamentals
 PK: ticker,     PK: article_id,           PK: event_id (optional)
     date            ticker
      |               |
      v               v
    risk          news_articles
 (optional,       PK: article_id
  derived)
```

`news_tickers.ticker` links to `companies`; `news_tickers.article_id` links to `news_articles`.
`dim_date` (optional) links to the date columns of the fact tables (section 4).

Data flow for the news tables:

```
Alpaca raw dataset (unchanged)
        |
        v
00_alpaca_news_profile.ipynb
        |
        v
02_news_cleaning_and_finbert.ipynb
        |
        +--> news_articles_sentiment.csv   (one row per unique article, sentiment scored once)
        |
        v
03_news_ticker_mapping.ipynb
        |
        +--> news_tickers.csv              (one row per article-ticker association)
        |
        +--> news_clean.csv                (flattened, one row per article-ticker pair)
```

Power BI input files:

```
market_prices                          ->  market_clean.csv
news_articles + news_tickers (joined)  ->  news_clean.csv
```

The warehouse should store `news_articles` and `news_tickers` separately. `news_clean.csv` can be
imported into Power BI or exposed as a database view.

## 3. Tables

Data types use generic names. The Power BI type is shown where it differs.

### 3.1 `companies` (dimension)

One row per company. Small, static, and built by hand from the ticker list plus the SEC ticker map.
The ten rows are the project tickers listed in section 1.

| Column | Data type | Key | Description |
|---|---|---|---|
| `ticker` | string | **PK** | Uppercase stock symbol, for example `AAPL` |
| `company_name` | string | | Full company name |
| `sector` | string | | Sector used for grouping (Technology, Finance, Healthcare, Energy, Consumer) |
| `cik` | integer | | SEC Central Index Key, used to pull fundamentals and 8-K filings |

Source: manual list. `cik` comes from `https://www.sec.gov/files/company_tickers.json`.
This table is **not produced by the notebooks**, so it must be created separately.

### 3.2 `market_prices` (fact), exported as `market_clean.csv`

One row per stock per trading day.

| Column | Data type | Key | Description |
|---|---|---|---|
| `ticker` | string | **PK (part 1)**, FK -> `companies.ticker` | Stock symbol |
| `date` | date | **PK (part 2)** | Trading day |
| `open` | decimal | | Opening price |
| `high` | decimal | | Highest price of the day |
| `low` | decimal | | Lowest price of the day |
| `close` | decimal | | Closing price. The adjustment convention (splits, dividends) must be documented |
| `volume` | integer | | Shares traded |
| `return` | decimal | | Return for the trading day, as defined by Person 1. Empty on the first day of each stock |
| `next_day_return` | decimal | | Return of the following trading day, if retained. Empty on the last day of each stock |

Primary key: composite (`ticker`, `date`).
Source: `prices.csv` and the return calculation in `final_dataset.csv`.

### 3.3 `news_articles` (fact), exported as `news_articles_sentiment.csv`

One row per unique Alpaca article. FinBERT is run once per article, before ticker expansion.

| Column | Data type | Key | Description |
|---|---|---|---|
| `article_id` | string | **PK** | Original Alpaca `id`, kept as a string. Never replace it with a row number |
| `published_at` | datetime | | Parsed `created_at`, timezone-aware, UTC |
| `updated_at` | datetime | | Parsed Alpaca `updated_at`. If an ID repeats in the raw data, the most recently updated version is kept |
| `title` | string | | Cleaned `headline` (HTML removed, whitespace normalized) |
| `summary` | string | | Cleaned summary. Null if unavailable |
| `content` | string | | Cleaned article body. Left out of the export by default (`KEEP_CONTENT = False`) because it is most of the file size |
| `author` | string | | Author, if available |
| `source` | string | | Publisher or source, if supplied. Otherwise null |
| `url` | string | | Original article URL |
| `symbols_raw` | string | | Original symbols value as received, kept for traceability |
| `symbols` | string | | Full parsed ticker list as JSON, for example `["AAPL", "COST", "AMZN"]`. Contains **all** Alpaca tickers, not only project tickers |
| `finbert_label` | string | | `positive`, `negative` or `neutral` (highest-probability class) |
| `finbert_positive` | decimal | | FinBERT probability of positive |
| `finbert_negative` | decimal | | FinBERT probability of negative |
| `finbert_neutral` | decimal | | FinBERT probability of neutral |
| `finbert_score` | decimal | | `finbert_positive - finbert_negative`, from -1 to +1. Neutral is not forced to 0 |
| `sentiment_text` | string | | The text that was scored (headline plus summary, or headline alone). FinBERT truncates it at 128 tokens. Kept for reproducibility |
| `quality_missing_title` | boolean | | True if the headline was missing |
| `quality_missing_published_at` | boolean | | True if the timestamp was missing or unparseable |

Primary key: `article_id`. One article appears only once.
Articles with no usable text keep null FinBERT columns. Sentiment is never invented.
Source: raw Alpaca CSV, cleaned and scored by `02_news_cleaning_and_finbert.ipynb`.

### 3.4 `news_tickers` (bridge / association table), exported as `news_tickers.csv`

One row per unique association between an article and a project ticker.

| Column | Data type | Key | Description |
|---|---|---|---|
| `article_id` | string | **PK (part 1)**, FK -> `news_articles.article_id` | Original article identifier |
| `ticker` | string | **PK (part 2)**, FK -> `companies.ticker` | One project ticker associated with the article |

Primary key: composite (`article_id`, `ticker`). The same article can have several rows, but the same
article-ticker pair never repeats.
Only the ten project tickers are kept. Relevance is not inferred beyond Alpaca's ticker tags unless a
separate relevance method is added. An article tagged `[AAPL, COST, BAC, BABA, AMZN]` produces two rows,
`AAPL` and `AMZN`.
Articles with no project ticker have no rows here but stay in `news_articles`.
Source: `news_articles.symbols`, filtered and expanded by `03_news_ticker_mapping.ipynb`.

### 3.5 `news_clean` (flattened export), exported as `news_clean.csv`

Derived dataset, not an authoritative warehouse table. It joins `news_articles` to `news_tickers` and has
one row per article-ticker pair.

| Column | Data type | Key | Description |
|---|---|---|---|
| `news_id` | integer | **PK** | Row number generated after expansion (sorted by `article_id`, `ticker`). Not stable between runs, so do not use it as a permanent identifier |
| `article_id` | string | | Original Alpaca ID. Repeats across tickers for multi-ticker articles |
| `ticker` | string | FK -> `companies.ticker` | One project ticker per row |
| `published_at` | datetime | | Original UTC publication timestamp |
| `date` | date | | UTC calendar date of `published_at`. This is **not** the market-reaction date (see section 6) |
| `title` | string | | Cleaned headline |
| `summary` | string | | Cleaned summary |
| `source` | string | | Source, if available |
| `url` | string | | Original URL |
| `n_project_tickers` | integer | | How many of the ten project tickers the article mentions |
| `n_symbols_total` | integer | | How many tickers Alpaca tagged in total. Large values usually mean a market roundup |
| `finbert_label` | string | | Article-level label copied onto each row |
| `finbert_positive` | decimal | | Article-level probability, copied |
| `finbert_negative` | decimal | | Article-level probability, copied |
| `finbert_neutral` | decimal | | Article-level probability, copied |
| `finbert_score` | decimal | | Article-level score, copied. -1 to +1 |

Primary key: `news_id`. Natural key: (`article_id`, `ticker`), which must be unique.
Source: `03_news_ticker_mapping.ipynb`.

**Interpretation warning:** the same article-level sentiment is repeated for every ticker the article
mentions. It is not ticker-specific sentiment. Describe it as article sentiment associated with a ticker.
`n_project_tickers` and `n_symbols_total` let analysts down-weight or exclude multi-ticker articles.

### 3.6 `events` (fact)

One row per company event. Earnings announcements and 8-K filings share one table, separated by `event_type`.
Columns that do not apply to an event type are left empty.

| Column | Data type | Key | Description |
|---|---|---|---|
| `event_id` | integer | **PK** | Surrogate key, generated when cleaning |
| `ticker` | string | FK -> `companies.ticker` | Stock symbol |
| `event_type` | string | | `earnings` or `8-K` |
| `event_date` | date | | Earnings announcement date, or SEC filing date for 8-K |
| `reaction_date` | date | | First trading day the market could reasonably react, based on the available timestamp and the documented rules |
| `after_close` | boolean | | Earnings only. Timing flag, if available |
| `eps_estimate` | decimal | | Earnings only. Expected EPS |
| `eps_actual` | decimal | | Earnings only. Reported EPS |
| `surprise_pct` | decimal | | Earnings only. Surprise in percent |
| `items` | string | | 8-K only. Item codes such as `2.02`, if available |
| `items_description` | string | | 8-K only. Plain-English description of the items, if available |

Primary key: `event_id`.
Source: structured Yahoo Finance earnings events (`earnings_events.csv`) and SEC EDGAR 8-K records
(`events_8k.csv`), stacked into one table. General Alpaca articles do not become events. If an event-extraction
feature is added later, document it separately and avoid duplicate events.

### 3.7 `fundamentals` (optional)

One row per company per fiscal quarter.

| Column | Data type | Key | Description |
|---|---|---|---|
| `ticker` | string | **PK (part 1)**, FK -> `companies.ticker` | Stock symbol |
| `period_end` | date | **PK (part 2)** | Last day of the fiscal quarter |
| `filing_date` | date | | Day the numbers became public. Used to avoid look-ahead bias |
| `revenue` | decimal | | Quarterly revenue (USD) |
| `net_income` | decimal | | Quarterly net income (USD) |
| `eps_diluted` | decimal | | Diluted EPS (USD per share) |
| `total_assets` | decimal | | Total assets (USD) |
| `equity` | decimal | | Stockholders' equity (USD) |
| `profit_margin` | decimal | | `net_income / revenue` |

Primary key: composite (`ticker`, `period_end`).
Source: `fundamentals.csv`. Revenue, net income and EPS do not include the fourth quarter.

### 3.8 `risk` (optional, derived)

Calculated from `market_prices`. This table is a proposal and is not produced by the notebooks yet.
Define the grain before implementing it: daily rolling risk and period-level risk are different grains.

| Column | Data type | Key | Description |
|---|---|---|---|
| `ticker` | string | **PK (part 1)**, FK -> `companies.ticker` | Stock symbol |
| `date` | date | **PK (part 2)** | Trading day |
| `volatility_30d` | decimal | | Standard deviation of `return` over the last 30 trading days |
| `max_drawdown` | decimal | | Largest drop from a running peak up to this date |

Primary key: composite (`ticker`, `date`).

### 3.9 `dim_date` (optional)

One row per calendar date, so Power BI can filter news, prices and events with one shared calendar.

| Column | Data type | Key | Description |
|---|---|---|---|
| `date` | date | **PK** | Calendar date. Add year, month, quarter and similar attributes as needed |

Primary key: `date`. Built in Power BI or generated once for the project period.

## 4. Relationships

| From (many) | To (one) | Join column | Cardinality |
|---|---|---|---|
| `market_prices.ticker` | `companies.ticker` | `ticker` | many-to-one |
| `news_tickers.ticker` | `companies.ticker` | `ticker` | many-to-one |
| `news_tickers.article_id` | `news_articles.article_id` | `article_id` | many-to-one |
| `events.ticker` | `companies.ticker` | `ticker` | many-to-one |
| `fundamentals.ticker` | `companies.ticker` | `ticker` | many-to-one |
| `risk` (`ticker`, `date`) | `market_prices` (`ticker`, `date`) | `ticker` + `date` | one-to-one, only if `risk` has exactly one row per ticker and date |
| `market_prices.date` | `dim_date.date` | `date` | many-to-one |
| `news_clean.date` | `dim_date.date` | `date` | many-to-one, after the date convention is defined |
| `events.reaction_date` | `dim_date.date` | `date` | many-to-one |

Notes on the links between the fact tables:

- News and `market_prices` do not link directly. Both link to `companies`, and both carry a `date`.
  Do not join raw article rows to daily prices and then sum prices or volumes: several articles on one day
  would multiply the market rows.
- To compare sentiment with returns, first aggregate news to one row per `ticker` and `date`
  (`news_count`, `mean_sentiment`, `positive_count`, `negative_count`, `neutral_count`) and then join that
  to `market_prices`.
- `events.reaction_date` joins to `market_prices.date` for event studies.
- `fundamentals` attaches to `market_prices` by **latest `filing_date` on or before `date`**, not by exact date.
- For the flattened `news_clean.csv`, `ticker` links to `companies.ticker` and `date` can link to `dim_date.date`.
  Do not create a direct many-to-many relationship between news and prices.

## 5. What Power BI receives

| File | Table | Grain | Status |
|---|---|---|---|
| `market_clean.csv` | `market_prices` | one row per ticker and trading day | Required |
| `news_clean.csv` | `news_clean` | one row per article-ticker pair | Required (simple model) |
| `companies.csv` | `companies` | one row per company | Recommended |
| `events_clean.csv` | `events` | one row per earnings or 8-K event | Recommended |
| `news_articles_sentiment.csv` | `news_articles` | one row per unique article | Optional (normalized model, auditing) |
| `news_tickers.csv` | `news_tickers` | one row per article-ticker pair | Optional (normalized model) |

Power BI setup:

1. Import the files above.
2. Create relationships from `companies[ticker]` (one side) to the `ticker` column of each other table
   (many side), single direction.
3. Add a `dim_date` table (a calendar table) and link `market_prices[date]`, `news_clean[date]` and
   `events[reaction_date]` to it. This is the standard way to analyse news and prices together without a
   direct many-to-many link.
4. Without `companies.csv`, the model has no shared dimension, so slicers by company or sector will not filter
   all tables at once.
5. For the normalized news model, import `news_articles_sentiment.csv` and `news_tickers.csv` instead of
   `news_clean.csv` and link `news_articles[article_id]` to `news_tickers[article_id]`.
6. Do not use `news_clean.csv` and the normalized news tables in the same visuals without a deliberate model.
   Mixing them double counts articles.

## 6. Data quality rules

1. Days with no news have no row in the news tables. Do not fill them with 0, because 0 is also a neutral
   article's score, and do not fill them with a neutral label.
2. Monthly article counts and coverage must be documented. The earlier raw CSV had months with no saved
   articles, so a missing month is not a month with zero news. Every project ticker should have articles in
   every year, otherwise investigate the collection first.
3. Keep the original `published_at` in UTC and never overwrite it. News published after market close
   (4 PM New York time), on weekends or on holidays belongs to the next trading day. Derive a separate
   market-reaction date with a documented New York trading-calendar rule. The current notebooks do not apply
   this rule yet, and `news_clean.date` is only the UTC calendar date.
4. Keep `ticker` in upper case everywhere so joins match.
5. Uniqueness: `companies.ticker`, `market_prices` (`ticker`, `date`), `news_articles.article_id`,
   `news_tickers` (`article_id`, `ticker`) and `news_clean` (`article_id`, `ticker`) must each be unique.
6. Referential integrity: every `news_tickers.article_id` exists in `news_articles`, and every
   `news_tickers.ticker` exists in `companies`.
7. Every non-null `finbert_score` is within -1 to +1, and the three FinBERT probabilities sum to 1.
8. Sentiment is article-level. Report it that way unless a ticker-specific model is added.
9. Use lagged sentiment or clearly defined event windows when comparing sentiment with later returns.
   Correlation does not establish causation.
10. Fundamentals must be joined by `filing_date`, never by `period_end`, to avoid look-ahead bias.
11. Missing `source`, summary or content stays null when genuinely unavailable. Values are never invented.
12. Empty values are expected in `return` (first day), `next_day_return` (last day) and some fundamentals
    columns (banks).
13. The news notebooks were tested on synthetic data only and have not been run end to end on the final
    dataset, so confirm the column names against real output before building the Power BI model.

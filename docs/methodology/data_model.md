# Data Model

This document defines the integrated data model for the project: which tables we need, how they
connect, and what Power BI will eventually receive.

## 1. Decisions

| Question | Answer |
|---|---|
| What tables do we need? | `companies`, `market_prices`, `news`, `events` (core). `fundamentals` and `risk` are optional extensions. |
| How will they connect? | `companies` is the central dimension. Every other table links to it through `ticker`. |
| What will Power BI eventually receive? | `market_clean.csv` and `news_clean.csv` (required). `companies.csv` and `events_clean.csv` are recommended so relationships and slicers work (see section 5). |

## 2. Initial data model

```
                          companies
                          PK: ticker
                              |
        +---------------------+---------------------+
        |                     |                     |
   market_prices            news                  events
   PK: ticker, date      PK: news_id          PK: event_id
        |
        v
      risk (derived from market_prices, optional)
```

Power BI input files:

```
market_prices  ->  market_clean.csv
news           ->  news_clean.csv
```

## 3. Tables

Data types use generic names. The Power BI type is shown where it differs.

### 3.1 `companies` (dimension)

One row per company. Small, static, and built by hand from the ticker list plus the SEC ticker map.

| Column | Data type | Key | Description |
|---|---|---|---|
| `ticker` | string | **PK** | Stock symbol, for example `AAPL` |
| `company_name` | string | | Full company name |
| `sector` | string | | Sector used for grouping (Technology, Finance, Healthcare, Energy, Consumer) |
| `cik` | integer | | SEC Central Index Key, used to pull fundamentals and 8-K filings |

Source: manual list. `cik` comes from `https://www.sec.gov/files/company_tickers.json`.
This table is **not produced by the notebook**, so it must be created separately.

### 3.2 `market_prices` (fact), exported as `market_clean.csv`

One row per stock per trading day.

| Column | Data type | Key | Description |
|---|---|---|---|
| `ticker` | string | **PK (part 1)**, FK -> `companies.ticker` | Stock symbol |
| `date` | date | **PK (part 2)** | Trading day |
| `open` | decimal | | Opening price (adjusted) |
| `high` | decimal | | Highest price of the day |
| `low` | decimal | | Lowest price of the day |
| `close` | decimal | | Closing price (adjusted for splits and dividends) |
| `volume` | integer | | Shares traded |
| `return` | decimal | | Percentage change of `close` versus the previous trading day. Empty on the first day of each stock |
| `next_day_return` | decimal | | Return of the following trading day. Empty on the last day of each stock |

Primary key: composite (`ticker`, `date`).
Source: `prices.csv` and the return calculation in `final_dataset.csv`.

### 3.3 `news` (fact), exported as `news_clean.csv`

One row per news article.

| Column | Data type | Key | Description |
|---|---|---|---|
| `news_id` | integer | **PK** | Surrogate key, generated when cleaning (row number) |
| `ticker` | string | FK -> `companies.ticker` | Stock the article is tagged with |
| `published_at` | datetime | | Publication time, parsed from the raw `published` text (for example `20240115T143000`) |
| `date` | date | | Calendar date of `published_at`, used to link to `market_prices` |
| `title` | string | | Headline |
| `summary` | string | | Article summary |
| `source` | string | | Publisher name |
| `av_score` | decimal | | Alpha Vantage sentiment score for this ticker, roughly -1 to +1 |
| `finbert_label` | string | | `positive`, `negative` or `neutral` |
| `finbert_score` | decimal | | FinBERT score from -1 to +1. Neutral is always 0 |

Primary key: `news_id`. Natural key for deduplication: (`ticker`, `title`, `published_at`).
Source: `news_with_sentiment.csv`.

### 3.4 `events` (fact)

One row per company event. Earnings announcements and 8-K filings share one table, separated by `event_type`.
Columns that do not apply to an event type are left empty.

| Column | Data type | Key | Description |
|---|---|---|---|
| `event_id` | integer | **PK** | Surrogate key, generated when cleaning |
| `ticker` | string | FK -> `companies.ticker` | Stock symbol |
| `event_type` | string | | `earnings` or `8-K` |
| `event_date` | date | | `announce_date` for earnings, `filing_date` for 8-K |
| `reaction_date` | date | | First trading day the market can react. Equals `event_date` for 8-K |
| `after_close` | boolean | | Earnings only. True if announced after 4 PM |
| `eps_estimate` | decimal | | Earnings only. Expected EPS |
| `eps_actual` | decimal | | Earnings only. Reported EPS |
| `surprise_pct` | decimal | | Earnings only. Surprise in percent |
| `items` | string | | 8-K only. Item codes such as `2.02` |
| `items_description` | string | | 8-K only. Plain-English description of the items |

Primary key: `event_id`.
Source: `earnings_events.csv` and `events_8k.csv`, stacked into one table.

### 3.5 `fundamentals` (optional)

One row per company per fiscal quarter.

| Column | Data type | Key | Description |
|---|---|---|---|
| `ticker` | string | **PK (part 1)**, FK -> `companies.ticker` | Stock symbol |
| `period_end` | date | **PK (part 2)** | Last day of the fiscal quarter |
| `filing_date` | date | | Day the numbers became public |
| `revenue` | decimal | | Quarterly revenue (USD) |
| `net_income` | decimal | | Quarterly net income (USD) |
| `eps_diluted` | decimal | | Diluted EPS (USD per share) |
| `total_assets` | decimal | | Total assets (USD) |
| `equity` | decimal | | Stockholders' equity (USD) |
| `profit_margin` | decimal | | `net_income / revenue` |

Primary key: composite (`ticker`, `period_end`).
Source: `fundamentals.csv`. Revenue, net income and EPS do not include the fourth quarter.

### 3.6 `risk` (optional, derived)

Calculated from `market_prices`. This table is a proposal and is not produced by the notebook yet.

| Column | Data type | Key | Description |
|---|---|---|---|
| `ticker` | string | **PK (part 1)**, FK -> `companies.ticker` | Stock symbol |
| `date` | date | **PK (part 2)** | Trading day |
| `volatility_30d` | decimal | | Standard deviation of `return` over the last 30 trading days |
| `max_drawdown` | decimal | | Largest drop from a running peak up to this date |

Primary key: composite (`ticker`, `date`).

## 4. Relationships

| From (many) | To (one) | Join column | Cardinality |
|---|---|---|---|
| `market_prices.ticker` | `companies.ticker` | `ticker` | many-to-one |
| `news.ticker` | `companies.ticker` | `ticker` | many-to-one |
| `events.ticker` | `companies.ticker` | `ticker` | many-to-one |
| `fundamentals.ticker` | `companies.ticker` | `ticker` | many-to-one |
| `risk` (`ticker`, `date`) | `market_prices` (`ticker`, `date`) | `ticker` + `date` | one-to-one |

Notes on the links between the fact tables:

- `news` and `market_prices` do not link directly. Both link to `companies`, and both carry a `date`.
  To compare sentiment with returns, aggregate `news` to one row per `ticker` and `date`
  (`finbert_mean`, `av_mean`, `news_count`) and then join to `market_prices`.
- `events.reaction_date` joins to `market_prices.date` for event studies.
- `fundamentals` attaches to `market_prices` by **latest `filing_date` on or before `date`**, not by exact date.

## 5. What Power BI receives

| File | Table | Status |
|---|---|---|
| `market_clean.csv` | `market_prices` | Required |
| `news_clean.csv` | `news` | Required |
| `companies.csv` | `companies` | Recommended |
| `events_clean.csv` | `events` | Recommended |

Power BI setup:

1. Import the files above.
2. Create relationships from `companies[ticker]` (one side) to the `ticker` column of each other table (many side), single direction.
3. Add a `dim_date` table (a calendar table) and link `market_prices[date]`, `news[date]` and `events[reaction_date]` to it.
   This is the standard way to analyse news and prices together without a direct many-to-many link.
4. Without `companies.csv`, the model has no shared dimension, so slicers by company or sector will not filter all tables at once.

## 6. Data quality rules

1. Days with no news have no row in `news`. Do not fill them with 0, because 0 is also the value of a neutral article.
2. News published after market close (4 PM New York time) belongs to the next trading day. The current notebook does not apply this rule yet.
3. Keep `ticker` in upper case everywhere so joins match.
4. Fundamentals must be joined by `filing_date`, never by `period_end`, to avoid look-ahead bias.
5. Empty values are expected in `return` (first day), `next_day_return` (last day), and some fundamentals columns (banks).
6. The notebook code was checked for syntax only and has not been run end to end, so confirm the column names against real output before building the Power BI model.

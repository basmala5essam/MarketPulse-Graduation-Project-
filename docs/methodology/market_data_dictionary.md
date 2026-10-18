# Market Data Dictionary

This document provides the formal data dictionary and specification for the stock market dataset used in **MarketPulse**. It covers data sources, schema definitions, business rules, mathematical formulas, and integration roles for Person 1 (Market Data & Analysis) and downstream consumers (Person 3 for Risk Analytics and Person 4 for Power BI Data Modeling).

---

## 1. Overview & Data Provenance

| Property | Value |
|---|---|
| **Data Source** | Yahoo Finance (via `yfinance` API) |
| **Asset Class** | US Equities (Large-Cap Blue Chip Stocks) |
| **Observation Frequency** | Daily (End-of-Day / EOD Trading Sessions) |
| **Timeframe Covered** | `2021-01-04` through `2025-12-30` (5 Calendar Years) |
| **Total Observations** | 12,540 rows (1,254 trading days × 10 tickers) |
| **Raw File Path** | `data/raw/yahoo_prices_raw.csv` |
| **Processed File Path** | `data/processed/market_clean.csv` |
| **Table Name in Data Model** | `market_prices` (Fact Table) |
| **Primary Key** | Composite: (`ticker`, `date`) |

### Companies Covered
The dataset covers 10 leading US publicly traded corporations across 5 diversified sectors:

| Ticker | Company Name | Sector | Industry | Currency |
|---|---|---|---|---|
| `AAPL` | Apple Inc. | Technology | Consumer Electronics | USD |
| `AMZN` | Amazon.com, Inc. | Consumer Cyclical | Internet Retail | USD |
| `JNJ` | Johnson & Johnson | Healthcare | Pharmaceuticals | USD |
| `JPM` | JPMorgan Chase & Co. | Financial Services | Diversified Banking | USD |
| `KO` | The Coca-Cola Company | Consumer Defensive | Non-Alcoholic Beverages | USD |
| `LLY` | Eli Lilly and Company | Healthcare | Pharmaceuticals | USD |
| `MSFT` | Microsoft Corporation | Technology | Software—Infrastructure | USD |
| `NVDA` | NVIDIA Corporation | Technology | Semiconductors | USD |
| `TSLA` | Tesla, Inc. | Consumer Cyclical | Auto Manufacturers | USD |
| `XOM` | Exxon Mobil Corporation | Energy | Oil & Gas Integrated | USD |

---

## 2. Data Dictionary Table

| Column Name | Raw / Derived | Python/Pandas Type | Power BI / SQL Type | Key / Constraint | Description & Purpose | Example |
|---|---|---|---|---|---|---|
| `ticker` | Raw | `str` / `object` | Text (`VARCHAR(10)`) | **PK (Part 1)**, FK $\to$ `companies.ticker` | Stock ticker symbol in uppercase. Uniquely identifies the corporation. | `AAPL` |
| `date` | Raw | `datetime64[ns]` / `str` | Date (`DATE`) | **PK (Part 2)**, FK $\to$ `dim_date.date` | Calendar trading date formatted in ISO 8601 (`YYYY-MM-DD`). | `2021-01-04` |
| `open` | Raw | `float64` | Decimal Number (`DECIMAL(18,4)`) | Not Null, $> 0$ | Opening stock price for the regular trading session (adjusted for stock splits). | `129.6225` |
| `high` | Raw | `float64` | Decimal Number (`DECIMAL(18,4)`) | Not Null, $\ge \max(\text{open}, \text{low}, \text{close})$ | Highest intra-day traded price during regular trading hours. | `129.7099` |
| `low` | Raw | `float64` | Decimal Number (`DECIMAL(18,4)`) | Not Null, $\le \min(\text{open}, \text{high}, \text{close})$ | Lowest intra-day traded price during regular trading hours. | `123.0599` |
| `close` | Raw | `float64` | Decimal Number (`DECIMAL(18,4)`) | Not Null, $> 0$ | Final price at 4:00 PM EST market close, adjusted for corporate actions (splits/dividends). | `125.6325` |
| `volume` | Raw | `int64` | Whole Number (`BIGINT`) | Not Null, $\ge 0$ | Total number of shares transacted during the session. Measures market liquidity. | `143301900` |
| `return` | Derived | `float64` | Decimal Number / % (`DECIMAL(10,6)`) | Nullable (First day per ticker is Null) | Daily percentage price return calculated as $\frac{P_t - P_{t-1}}{P_{t-1}}$. Essential for risk calculations. | `0.012363` (+1.24%) |
| `next_day_return` | Derived | `float64` | Decimal Number / % (`DECIMAL(10,6)`) | Nullable (Last day per ticker is Null) | Next trading day's price return: $\frac{P_{t+1} - P_t}{P_t}$. Used for event studies and sentiment lead-lag models. | `-0.033661` (-3.37%) |

---

## 3. Financial Mechanics & Formulas

### 3.1 OHLCV Mechanics
Stock exchanges (e.g., NYSE, NASDAQ) trade between 9:30 AM and 4:00 PM Eastern Time on US business days:
1. **Open**: The price determined by the opening cross auction at 9:30 AM EST.
2. **High & Low**: The intraday boundaries of volatility. By definition:
   $$\text{Low} \le \text{Open} \le \text{High}$$
   $$\text{Low} \le \text{Close} \le \text{High}$$
   $$\text{High} \ge \text{Low}$$
3. **Close (Adjusted Close)**: Reflects the true economic value of holding a share by factoring in stock splits (e.g. AAPL's 4-for-1 split or NVDA's 10-for-1 split) and cash dividend payouts. Using adjusted prices prevents artificial drops in returns.
4. **Volume**: The total share volume traded. High volume indicates high liquidity and institutional participation; low volume indicates thinner trading.

### 3.2 Daily Return Calculation
Daily return measures the percentage capital gain or loss over a single trading day:
$$R_t = \frac{\text{Close}_t - \text{Close}_{t-1}}{\text{Close}_{t-1}} = \frac{\text{Close}_t}{\text{Close}_{t-1}} - 1$$

- **First Day Handling**: On the very first recorded trading date (`2021-01-04`), no prior trading day exists in the dataset. Therefore, `return` is naturally `NaN` (or `NULL`).
- **Grouping**: Returns are computed strictly **within each ticker group** sorted chronologically by date. Never calculate returns across tickers.

### 3.3 Next-Day Return Calculation (Lead Return)
To answer whether news sentiment or SEC event filings predict subsequent stock movements, we compute the return of the following trading day:
$$R_{t+1} = \frac{\text{Close}_{t+1} - \text{Close}_t}{\text{Close}_t}$$

- **Implementation**: Calculated as `df.groupby('ticker')['return'].shift(-1)`.
- **Last Day Handling**: On the final recorded trading date (`2025-12-30`), no future trading day exists. Therefore, `next_day_return` is `NaN` (or `NULL`).

---

## 4. Integration with Downstream Team Members

The `market_clean.csv` output produced by Person 1 serves as the central fact table in the overall MarketPulse analytical architecture:

```
                  ┌────────────────────────┐
                  │    companies (dim)     │
                  │       PK: ticker       │
                  └───────────┬────────────┘
                              │ 1
                              │
                              │ *
                  ┌───────────┴────────────┐
                  │ market_prices (fact)   │
                  │ PK: (ticker, date)     │
                  │ File: market_clean.csv │
                  └───────────┬────────────┘
                              │
          ┌───────────────────┴───────────────────┐
          │                                       │
          ▼                                       ▼
┌──────────────────────────────┐        ┌──────────────────────────────┐
│       Person 3 (Laila)       │        │       Person 4 (Kiro)        │
│   Risk & Portfolio Metrics   │        │     Power BI Integration     │
├──────────────────────────────┤        ├──────────────────────────────┤
│ - Daily Returns              │        │ - Star Schema modeling       │
│ - Historical Volatility      │        │ - Connect to Dim_Date        │
│ - Beta (vs S&P 500)          │        │ - Dynamic DAX measures       │
│ - Maximum Drawdown           │        │ - Interactive dashboards     │
│ - Value at Risk (VaR 95/99)  │        │ - Cross-filtering by sector  │
│ - Sharpe & Sortino Ratios    │        │   and company                │
└──────────────────────────────┘        └──────────────────────────────┘
```

1. **For Person 3 (Laila - Risk Analysis)**:
   - Uses `return` directly to compute daily standard deviation, annualized volatility ($\sigma \times \sqrt{252}$), and Value at Risk (VaR).
   - Uses `close` to construct running peak equity curves and compute Maximum Drawdown (MDD).
2. **For Person 4 (Kiro - Data Modeling & Power BI)**:
   - Imports `market_clean.csv` into Power BI Desktop.
   - Links `ticker` to `companies[ticker]` (one-to-many relationship).
   - Links `date` to `dim_date[date]` to synchronize prices with news articles and earnings events.

---

## 5. Data Quality Rules & Constraints

To ensure downstream calculations run without failure, the market dataset adheres to the following strict validation rules:

1. **Uniqueness**: Composite key `(ticker, date)` must be unique with zero duplicate records.
2. **Completeness**: No missing values allowed in price or volume columns (`open`, `high`, `low`, `close`, `volume`).
3. **Date Consistency**: Dates must be valid calendar dates formatted as `YYYY-MM-DD` and strictly ordered.
4. **Trading Synchronicity**: All 10 companies must trade on identical calendar days without unexplained omissions.
5. **Price Invariants**:
   - $\text{Price} > 0$ for all OHLC fields.
   - $\text{High} \ge \text{Low}$.
   - $\text{Open} \in [\text{Low}, \text{High}]$.
   - $\text{Close} \in [\text{Low}, \text{High}]$.
6. **Volume Non-Negativity**: $\text{Volume} \ge 0$.

# MarketPulse — Alpaca News Data Dictionary

## 1. Dataset Overview

- **Source:** Alpaca News API
- **Dataset type:** Raw financial news articles
- **Total rows:** 79,549
- **Total columns:** 11

## 2. Dataset Profile

| Metric | Value |
|---|---:|
| raw_rows | 79,549 |
| raw_columns | 11 |
| unique_article_ids | 79,549 |
| duplicate_id_rows | 0 |
| missing_headline_rows | 0 |
| missing_created_at_rows | 0 |

## 3. Column Definitions

| Column | Data Type | Missing Values | Unique Values | Description |
|---|---|---:|---:|---|
| `author` | str | 0 | 363 | Author or publisher attribution provided by the source. |
| `content` | str | 21,805 | 57,717 | Article content provided by the API; may be incomplete or absent. |
| `created_at` | str | 0 | 79,482 | Timestamp indicating when the article was created or published, as provided by Alpaca. |
| `headline` | str | 0 | 71,846 | Headline or title of the news article. |
| `id` | int64 | 0 | 79,549 | Unique identifier assigned to the news article by Alpaca. |
| `images` | str | 0 | 51,142 | Image metadata associated with the article, when available. |
| `source` | str | 14,514 | 1 | Publisher or source identifier for the article. |
| `summary` | str | 21,837 | 43,280 | Summary text provided for the article, when available. |
| `symbols` | str | 0 | 29,557 | Ticker symbols associated with the article; an article may have multiple symbols. |
| `updated_at` | str | 0 | 79,492 | Timestamp indicating the article's last update, when provided. |
| `url` | str | 0 | 79,549 | Link to the original news article. |

## 4. Data Quality Notes

- Check duplicate article IDs before downstream processing.
- Check missing headlines and timestamps.
- Parse timestamps into a consistent timezone-aware format; preserve UTC.
- Parse the `symbols` field into a structured list before ticker mapping.
- Clean HTML and whitespace from text fields before sentiment analysis.
- Do not assume missing article content means the article has no useful information; the headline and summary may still be available.

## 5. Downstream Use in MarketPulse

- Deduplicate articles using the original article ID.
- Apply FinBERT once per unique article.
- Keep article-level sentiment separate from article–ticker associations.
- Filter ticker associations using the team's agreed project ticker list.
- Document any transformations performed during cleaning.

---

*Generated automatically from the raw Alpaca news DataFrame.*

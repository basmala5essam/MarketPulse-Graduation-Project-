"""
Monthly risk table: one row per (ticker, month).

Columns (same as the proposed table):
    ticker          stock symbol
    date            last trading day of the month
    volatility_30d  std of daily returns over the last 30 trading days, as of `date`
    max_drawdown    largest drop from a running peak, from the start of the data up to `date`
                    (a negative number, e.g. -0.35 = -35%)

Output:
    data/processed/risk_monthly.csv

Run from the project root:
    py src/risk/monthly_risk.py
"""

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_INPUT = PROJECT_ROOT / "data" / "raw" / "yahoo_prices_raw.csv"
DEFAULT_OUTPUT = PROJECT_ROOT / "data" / "processed" / "risk_monthly.csv"

WINDOW = 30  # trading days


def build_monthly_risk(df: pd.DataFrame, window: int = WINDOW) -> pd.DataFrame:
    df = df.sort_values(["ticker", "date"]).copy()
    g = df.groupby("ticker")["close"]

    # Daily figures, calculated per ticker on the full daily history
    df["return"] = g.pct_change()
    df["volatility_30d"] = df.groupby("ticker")["return"].transform(
        lambda s: s.rolling(window, min_periods=window).std()
    )
    df["max_drawdown"] = df["close"] / g.cummax() - 1
    df["max_drawdown"] = df.groupby("ticker")["max_drawdown"].cummin()

    # Keep the last trading day of each month, per ticker
    df["month"] = df["date"].dt.to_period("M")
    monthly = df.groupby(["ticker", "month"], as_index=False).tail(1)

    out = monthly[["ticker", "date", "volatility_30d", "max_drawdown"]]
    return out.sort_values(["ticker", "date"]).reset_index(drop=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build the monthly risk table.")
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    df = pd.read_csv(args.input, parse_dates=["date"])
    out = build_monthly_risk(df)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(args.output, index=False)

    print(f"Rows: {len(out)} | Tickers: {out['ticker'].nunique()} | "
          f"Months per ticker: {out.groupby('ticker').size().iloc[0]}")
    print(f"Saved: {args.output}")
    print(out.head(8).to_string(index=False))


if __name__ == "__main__":
    main()

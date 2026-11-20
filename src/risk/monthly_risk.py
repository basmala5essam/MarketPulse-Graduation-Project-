"""
Monthly risk table: one row per (ticker, month).

Columns:
    ticker                 stock symbol
    month_end              last trading day of the month
    monthly_return         compounded daily returns inside the month
                           (January 2021 starts from the first close, there is no earlier price)
    vol_20d_ann            std of the last 20 daily returns x sqrt(252), as of `month_end`
                           (same definition as the daily risk series)
    drawdown_eom           close on `month_end` / highest close since the start - 1 (0 or negative)
    max_drawdown_in_month  worst drop inside the month, from that month's own running peak

Output:
    data/processed/risk_monthly.csv

Run from the project root:
    py src/risk/monthly_risk.py
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_INPUT = PROJECT_ROOT / "data" / "raw" / "yahoo_prices_raw.csv"
DEFAULT_OUTPUT = PROJECT_ROOT / "data" / "processed" / "risk_monthly.csv"

WINDOW = 20  # trading days
TRADING_DAYS = 252


def build_monthly_risk(df: pd.DataFrame, window: int = WINDOW) -> pd.DataFrame:
    df = df[["ticker", "date", "close"]].sort_values(["ticker", "date"]).reset_index(drop=True)
    g = df.groupby("ticker")["close"]

    # Daily figures, calculated per ticker on the full daily history
    df["return"] = g.pct_change()
    df["vol_20d_ann"] = df.groupby("ticker")["return"].transform(
        lambda s: s.rolling(window, min_periods=window).std() * np.sqrt(TRADING_DAYS)
    )
    df["drawdown"] = df["close"] / g.cummax() - 1  # from the running peak since the start (can recover)
    df["month"] = df["date"].dt.to_period("M")
    df["month_drawdown"] = df["close"] / df.groupby(["ticker", "month"])["close"].cummax() - 1

    keys = ["ticker", "month"]
    agg = (
        df.groupby(keys)
        .agg(
            monthly_return=("return", lambda s: (1 + s).prod() - 1),
            max_drawdown_in_month=("month_drawdown", "min"),
        )
        .reset_index()
    )
    last = (
        df.groupby(keys).tail(1)[keys + ["date", "vol_20d_ann", "drawdown"]]
        .rename(columns={"date": "month_end", "drawdown": "drawdown_eom"})
    )
    out = last.merge(agg, on=keys, validate="1:1")
    cols = ["ticker", "month_end", "monthly_return", "vol_20d_ann", "drawdown_eom", "max_drawdown_in_month"]
    return out[cols].sort_values(["ticker", "month_end"]).reset_index(drop=True)


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

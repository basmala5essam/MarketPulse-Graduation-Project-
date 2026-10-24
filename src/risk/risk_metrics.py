"""
Risk engine: per-stock risk metrics and the return correlation matrix.

Metrics (per ticker):
    - daily and annualized volatility
    - beta against a benchmark (optional: only when --benchmark is given)
    - maximum drawdown
    - Sharpe ratio
    - Value at Risk (historical and parametric, 95% and 99%, 1-day)

Outputs:
    data/processed/risk_metrics.csv
    data/processed/correlation_matrix.csv

Usage (from the project root):
    python src/risk/risk_metrics.py                                  # no beta yet
    python src/risk/risk_metrics.py --benchmark data/raw/SPY.csv     # adds beta (CSV: date, close)
    python src/risk/risk_metrics.py --risk-free-rate 0.03

Only needs pandas and numpy.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from statistics import NormalDist

import numpy as np
import pandas as pd

TRADING_DAYS = 252
PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_INPUT = PROJECT_ROOT / "data" / "raw" / "yahoo_prices_raw.csv"
DEFAULT_OUT_DIR = PROJECT_ROOT / "data" / "processed"

EQUAL_WEIGHT = "equal_weight"


# --------------------------------------------------------------------------
# Data loading
# --------------------------------------------------------------------------
def load_prices(path: Path = DEFAULT_INPUT) -> pd.DataFrame:
    """Load the raw file and return a wide DataFrame of close prices (date x ticker)."""
    df = pd.read_csv(path, parse_dates=["date"])
    df = df.sort_values(["ticker", "date"])
    return df.pivot(index="date", columns="ticker", values="close").sort_index()


def compute_returns(prices: pd.DataFrame) -> pd.DataFrame:
    """Daily simple returns. The first row (no previous close) is dropped."""
    return prices.pct_change().iloc[1:]


def load_benchmark_returns(
    benchmark: str, prices: pd.DataFrame, returns: pd.DataFrame
) -> tuple[pd.Series, str]:
    """
    Benchmark daily returns, chosen by the `benchmark` argument:
        "equal_weight"  -> equal-weighted portfolio of all tickers (default)
        "<TICKER>"      -> a ticker already present in the price data
        "<path>.csv"    -> a CSV with at least `date` and `close` columns (e.g. SPY)
    """
    if benchmark == EQUAL_WEIGHT:
        return returns.mean(axis=1).rename("benchmark"), "Equal-weighted portfolio of all tickers"

    if benchmark in prices.columns:
        return returns[benchmark].rename("benchmark"), f"{benchmark} (from price data)"

    path = Path(benchmark)
    if path.exists():
        bench = pd.read_csv(path, parse_dates=["date"]).sort_values("date")
        close = bench.set_index("date")["close"]
        return close.pct_change().dropna().rename("benchmark"), f"{path.name}"

    raise ValueError(
        f"Benchmark '{benchmark}' is not '{EQUAL_WEIGHT}', a ticker in the data "
        f"({list(prices.columns)}), or an existing CSV file."
    )


# --------------------------------------------------------------------------
# Metrics
# --------------------------------------------------------------------------
def volatility(returns: pd.DataFrame) -> pd.DataFrame:
    daily = returns.std()
    return pd.DataFrame(
        {
            "daily_volatility": daily,
            "annualized_volatility": daily * np.sqrt(TRADING_DAYS),
        }
    )


def beta(returns: pd.DataFrame, bench: pd.Series) -> pd.Series:
    """Beta = Cov(stock, benchmark) / Var(benchmark), on dates both have."""
    aligned = returns.join(bench, how="inner").dropna()
    b = aligned["benchmark"]
    cov = aligned.drop(columns="benchmark").apply(lambda s: s.cov(b))
    return (cov / b.var()).rename("beta")


def max_drawdown(prices: pd.DataFrame) -> pd.Series:
    """Worst peak-to-trough fall of the close price (a negative number)."""
    drawdown = prices / prices.cummax() - 1
    return drawdown.min().rename("max_drawdown")


def sharpe_ratio(returns: pd.DataFrame, risk_free_rate: float = 0.0) -> pd.Series:
    """Annualized Sharpe = (annualized mean return - risk-free rate) / annualized volatility."""
    ann_return = returns.mean() * TRADING_DAYS
    ann_vol = returns.std() * np.sqrt(TRADING_DAYS)
    return ((ann_return - risk_free_rate) / ann_vol).rename("sharpe_ratio")


def value_at_risk(returns: pd.DataFrame, confidence_levels=(0.95, 0.99)) -> pd.DataFrame:
    """
    1-day VaR, reported as a positive loss fraction (0.03 = 3% of value).
        historical: empirical quantile of daily returns
        parametric: normal distribution using each stock's mean and std
    """
    out = {}
    for c in confidence_levels:
        label = int(round(c * 100))
        z = NormalDist().inv_cdf(1 - c)
        out[f"var_{label}_hist"] = -returns.quantile(1 - c)
        out[f"var_{label}_param"] = -(returns.mean() + z * returns.std())
    return pd.DataFrame(out)


def correlation_matrix(returns: pd.DataFrame) -> pd.DataFrame:
    return returns.corr()


# --------------------------------------------------------------------------
# Pipeline
# --------------------------------------------------------------------------
def build_risk_metrics(
    prices: pd.DataFrame,
    benchmark: str | None = None,
    risk_free_rate: float = 0.0,
) -> tuple[pd.DataFrame, pd.DataFrame, str]:
    """
    Return (risk_metrics, correlation_matrix, benchmark_description).

    Beta is only calculated when a benchmark is given. With benchmark=None
    (the default) the beta column is left out of the results.
    """
    returns = compute_returns(prices)

    parts = [volatility(returns)]
    if benchmark:
        bench, bench_desc = load_benchmark_returns(benchmark, prices, returns)
        parts.append(beta(returns, bench))
    else:
        bench_desc = "None (beta skipped; pass --benchmark to add it)"
    parts += [
        max_drawdown(prices.loc[returns.index]),
        sharpe_ratio(returns, risk_free_rate),
        value_at_risk(returns),
    ]

    metrics = pd.concat(parts, axis=1)
    metrics.index.name = "ticker"
    metrics = metrics.sort_values("annualized_volatility", ascending=False)

    corr = correlation_matrix(returns)
    return metrics, corr, bench_desc


def main() -> None:
    parser = argparse.ArgumentParser(description="Compute risk metrics for all tickers.")
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT, help="raw prices CSV")
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR, help="output folder")
    parser.add_argument(
        "--benchmark",
        default=None,
        help="optional; enables beta. Use a CSV path with date,close (e.g. SPY), "
        "a ticker in the data, or 'equal_weight'. Default: no benchmark, beta skipped",
    )
    parser.add_argument(
        "--risk-free-rate",
        type=float,
        default=0.0,
        help="annual risk-free rate for Sharpe, e.g. 0.03 for 3%% (default 0)",
    )
    args = parser.parse_args()

    prices = load_prices(args.input)
    metrics, corr, bench_desc = build_risk_metrics(prices, args.benchmark, args.risk_free_rate)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    metrics.to_csv(args.out_dir / "risk_metrics.csv")
    corr.to_csv(args.out_dir / "correlation_matrix.csv")

    print(f"Benchmark: {bench_desc}")
    print(f"Risk-free rate: {args.risk_free_rate:.2%}")
    print(f"Tickers: {len(metrics)} | Period: {prices.index.min().date()} -> {prices.index.max().date()}\n")
    with pd.option_context("display.width", 200, "display.max_columns", 30):
        print(metrics.round(4))
    print(f"\nSaved: {args.out_dir / 'risk_metrics.csv'}")
    print(f"Saved: {args.out_dir / 'correlation_matrix.csv'}")


if __name__ == "__main__":
    main()

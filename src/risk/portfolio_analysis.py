"""
Portfolio analysis
Reads : data/processed/market_clean.csv
Writes: data/processed/portfolio_weights.csv
        data/processed/portfolio_daily.csv
        data/processed/portfolio_metrics.csv

Run from the repo root:  python src/portfolio_analysis.py
"""
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.optimize import minimize

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "processed"
TRADING_DAYS = 252
RISK_FREE = 0.0

# ---------------------------------------------------------------- load returns
market = pd.read_csv(DATA / "market_clean.csv", parse_dates=["date"])
returns = (
    market.pivot(index="date", columns="ticker", values="return")
    .sort_index()
    .dropna()          # drops the first day (no return)
)
tickers = sorted(returns.columns)
returns = returns[tickers]
n = len(tickers)


# ---------------------------------------------------------------- weights
def fixed_weights(selected):
    return {t: (1 / len(selected) if t in selected else 0.0) for t in tickers}


def min_variance_weights(ret):
    """Long-only minimum-variance weights (sum = 1, w >= 0)."""
    cov = ret.cov().values
    result = minimize(
        lambda w: w @ cov @ w,
        x0=np.ones(n) / n,
        jac=lambda w: 2 * cov @ w,
        method="SLSQP",
        bounds=[(0, 1)] * n,
        constraints=[{"type": "eq", "fun": lambda w: w.sum() - 1}],
        options={"ftol": 1e-15, "maxiter": 1000},
    )
    if not result.success:
        raise RuntimeError(f"Optimization failed: {result.message}")
    w = np.clip(result.x, 0, None)
    return dict(zip(tickers, w / w.sum()))


portfolios = {
    "P1": ("Equal-weight", {t: 1 / n for t in tickers}),
    "P2": ("Defensive", fixed_weights(["JNJ", "KO", "LLY", "XOM", "JPM"])),
    "P3": ("Growth", fixed_weights(["AAPL", "MSFT", "NVDA", "AMZN", "TSLA"])),
    # NOTE: estimated and evaluated on the SAME data -> in-sample (see notes)
    "P4": ("Minimum variance", min_variance_weights(returns)),
}

# ---------------------------------------------------------------- compute
weight_rows, daily_frames, metric_rows = [], [], []

for pid, (name, w) in portfolios.items():
    wv = np.array([w[t] for t in tickers])
    assert abs(wv.sum() - 1) < 1e-9, f"{pid} weights do not sum to 1"
    weight_rows += [(pid, t, w[t]) for t in tickers]

    # R_p = sum(w_i * R_i)
    r = returns.values @ wv

    # value index starting at 100, and drawdown vs running peak
    value_index = 100 * np.cumprod(1 + r)
    peak = np.maximum.accumulate(np.r_[100, value_index])[1:]
    drawdown = value_index / peak - 1

    daily_frames.append(pd.DataFrame({
        "portfolio_id": pid,
        "date": returns.index.strftime("%Y-%m-%d"),
        "daily_return": r,
        "value_index": value_index,
        "drawdown": drawdown,
    }))

    ann_return = r.mean() * TRADING_DAYS
    ann_vol = r.std(ddof=1) * np.sqrt(TRADING_DAYS)
    metric_rows.append({
        "portfolio_id": pid,
        "portfolio_name": name,
        "ann_return": ann_return,
        "ann_vol": ann_vol,
        "sharpe": (ann_return - RISK_FREE) / ann_vol,
        "max_drawdown": drawdown.min(),
        "var_95_hist": np.percentile(r, 5),   # negative number = loss
    })

weights_df = pd.DataFrame(weight_rows, columns=["portfolio_id", "ticker", "weight"])
daily_df = pd.concat(daily_frames, ignore_index=True)
metrics_df = pd.DataFrame(metric_rows)

# ---------------------------------------------------------------- checks
sums = weights_df.groupby("portfolio_id")["weight"].sum()
assert np.allclose(sums, 1), "Each portfolio's weights must sum to 1"

avg_indiv_vol = (returns.std(ddof=1) * np.sqrt(TRADING_DAYS)).mean()
ew_vol = metrics_df.loc[metrics_df.portfolio_id == "P1", "ann_vol"].iloc[0]
assert ew_vol < avg_indiv_vol, "Equal-weight vol should be < average stock vol"
print(f"Equal-weight vol {ew_vol:.4f} < average individual vol {avg_indiv_vol:.4f}  OK")

# ---------------------------------------------------------------- save
weights_df.to_csv(DATA / "portfolio_weights.csv", index=False, float_format="%.10f")
daily_df.to_csv(DATA / "portfolio_daily.csv", index=False, float_format="%.8f")
metrics_df.round(6).to_csv(DATA / "portfolio_metrics.csv", index=False)

print(metrics_df.round(4).to_string(index=False))

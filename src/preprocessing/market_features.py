"""
MarketPulse — Week 4: Final Market-Analysis Feature Engineering Pipeline
Author: Mariam

Builds the market features dataset from `data/processed/market_clean.csv` and exports
`data/processed/market_features.csv`.

Calculated Features:
1. Returns:
   - return (Daily Return: percentage change in closing price)
   - cumulative_return (Cumulative Return from the first trading day of each ticker)
2. Trend (Simple Moving Averages of Closing Price):
   - ma20 (20-day moving average)
   - ma50 (50-day moving average)
   - ma200 (200-day moving average)
3. Volatility:
   - rolling_volatility (20-day rolling standard deviation of daily returns)
4. Volume:
   - volume_change (Daily percentage change in trading volume)
   - volume_ma20 (20-day moving average of trading volume representing volume trends)
"""

from pathlib import Path
import pandas as pd


def build_market_features(input_path: Path, output_path: Path) -> pd.DataFrame:
    """Load cleaned market data, engineer required analytical features, and save to CSV."""
    df = pd.read_csv(input_path)

    # Ensure strict chronological ordering per ticker before rolling/cumulative calculations
    df["date"] = pd.to_datetime(df["date"], format="%Y-%m-%d")
    df = df.sort_values(by=["ticker", "date"], ascending=[True, True]).reset_index(drop=True)

    # 1. Returns: Daily Return & Cumulative Return
    df["return"] = df.groupby("ticker")["close"].pct_change()
    df["cumulative_return"] = df.groupby("ticker")["close"].transform(lambda s: (s / s.iloc[0]) - 1.0)

    # 2. Trend: Moving Averages (MA20, MA50, MA200)
    df["ma20"] = df.groupby("ticker")["close"].transform(lambda s: s.rolling(window=20).mean())
    df["ma50"] = df.groupby("ticker")["close"].transform(lambda s: s.rolling(window=50).mean())
    df["ma200"] = df.groupby("ticker")["close"].transform(lambda s: s.rolling(window=200).mean())

    # 3. Volatility: Rolling Volatility (20-day rolling standard deviation of daily returns)
    df["rolling_volatility"] = df.groupby("ticker")["return"].transform(lambda s: s.rolling(window=20).std())

    # 4. Volume: Volume Change & Volume Trends (20-day rolling average volume)
    df["volume_change"] = df.groupby("ticker")["volume"].pct_change()
    df["volume_ma20"] = df.groupby("ticker")["volume"].transform(lambda s: s.rolling(window=20).mean())

    # Format date back to ISO YYYY-MM-DD and round floating-point columns cleanly
    df["date"] = df["date"].dt.strftime("%Y-%m-%d")
    float_cols = [
        "open",
        "high",
        "low",
        "close",
        "return",
        "cumulative_return",
        "ma20",
        "ma50",
        "ma200",
        "rolling_volatility",
        "volume_change",
        "volume_ma20",
    ]
    for col in float_cols:
        if col in df.columns:
            df[col] = df[col].round(6)

    # Reorder columns strictly to base OHLCV + Week 4 required features
    ordered_cols = [
        "ticker",
        "date",
        "open",
        "high",
        "low",
        "close",
        "volume",
        "return",
        "cumulative_return",
        "ma20",
        "ma50",
        "ma200",
        "rolling_volatility",
        "volume_change",
        "volume_ma20",
    ]
    df = df[ordered_cols]

    output_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(output_path, index=False)
    return df


def main() -> None:
    repo_root = Path(__file__).resolve().parents[2]
    input_csv = repo_root / "data" / "processed" / "market_clean.csv"
    output_csv = repo_root / "data" / "processed" / "market_features.csv"

    print(f"Loading cleaned market dataset from: {input_csv}")
    features_df = build_market_features(input_csv, output_csv)
    print(f"Saved market features dataset to:    {output_csv}")
    print(f"Shape: {features_df.shape[0]:,} rows x {features_df.shape[1]} columns")
    print(f"Columns: {list(features_df.columns)}")


if __name__ == "__main__":
    main()

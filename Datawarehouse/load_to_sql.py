"""
Load several CSV files into SQL Server staging tables from your own computer.

How to use:
1. Change USERNAME (and DATA_DIR if your folder is different) in the settings below.
2. Run everything:            python load_to_sql.py
   Run only some tables:      python load_to_sql.py news_tickers
                              python load_to_sql.py market news_clean
3. Type the SQL password when asked (it will not show on screen, that is normal).

What it does for each table:
- If the staging table does not exist, it creates it from the CSV columns (all text, sized to fit the data).
- If it exists, it checks that every CSV column exists in the table, then empties it (TRUNCATE).
- Then it loads all rows. Running the script twice never duplicates rows.
"""
import os
import sys
import getpass
import urllib.parse

import pandas as pd
from sqlalchemy import create_engine, text

# ---------------- Settings ----------------
SERVER = "196.221.145.204,1433"
DATABASE = "MarketPulseDW"
USERNAME = "R5"                      # <-- change this (copy it from your current script)
DRIVER = "ODBC Driver 18 for SQL Server"    # use "ODBC Driver 17 for SQL Server" if you prefer that one

SCHEMA = "staging"
DATA_DIR = r"C:\Users\Lenovo\Desktop\MarketPulse-Graduation-Project-\data\processed"

# (staging table name, CSV file name)
JOBS = [
    ("market",                  "market_clean.csv"),
    ("news_clean",              "news_clean.csv"),
    ("news_articles_sentiment", "news_articles_sentiment.csv"),
    ("news_tickers",            "news_tickers.csv"),
    ("companies",                "companies.csv"),
    ("events",                    "events_clean.csv"),
    ("fundamentals",                    "fundamentals_clean.csv"),
    ("monthly_risk",                    "risk_monthly.csv"),
    ("market_features",                    "market_features.csv"),
    ("risk_metrics",                    "risk_metrics.csv"),
    ("correlation_matrix",                    "correlation_matrix.csv"),
    ("benchmark_prices",                    "benchmark_prices.csv"),


]

CHUNKSIZE = 1000
FAST_EXECUTEMANY = True   # much faster; if you get a memory/truncation error on a news table, set this to False
# ------------------------------------------


def odbc_escape(value):
    """Wrap a value in braces so characters like ; { } = in a password do not break the connection string."""
    return "{" + value.replace("}", "}}") + "}"


def quote_name(name):
    """Safe SQL Server identifier: [name]"""
    return "[" + str(name).replace("]", "]]") + "]"


def sql_type(longest):
    """Pick a text type that fits the longest value in the column."""
    if longest <= 255:
        return "NVARCHAR(255)"
    if longest <= 4000:
        return "NVARCHAR(4000)"
    return "NVARCHAR(MAX)"


def build_create_sql(schema, table, df):
    """CREATE TABLE statement with one text column per CSV column."""
    lines = []
    for col in df.columns:
        longest = df[col].dropna().astype(str).str.len().max()
        longest = 0 if pd.isna(longest) else int(longest)
        lines.append(f"    {quote_name(col)} {sql_type(longest)} NULL")
    return f"CREATE TABLE {quote_name(schema)}.{quote_name(table)} (\n" + ",\n".join(lines) + "\n)"


def load_one(engine, table, path):
    if not os.path.exists(path):
        raise FileNotFoundError(f"File not found: {path}")

    # Everything is read as text, to match the staging (text) columns.
    df = pd.read_csv(path, dtype=str)
    print(f"  Read {len(df)} rows, {len(df.columns)} columns")
    print("  Columns:", df.columns.tolist())
    if df.empty:
        raise ValueError("The CSV has no rows, nothing to load.")

    with engine.connect() as conn:
        table_cols = pd.read_sql(
            text("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS "
                 "WHERE TABLE_SCHEMA = :s AND TABLE_NAME = :t"),
            conn,
            params={"s": SCHEMA, "t": table},
        )["COLUMN_NAME"].tolist()

    if not table_cols:
        with engine.begin() as conn:
            conn.exec_driver_sql(build_create_sql(SCHEMA, table, df))
        print(f"  Table {SCHEMA}.{table} did not exist, created it from the CSV columns.")
    else:
        existing = {c.lower() for c in table_cols}
        missing = [c for c in df.columns if c.lower() not in existing]
        if missing:
            raise ValueError(f"These CSV columns are not in {SCHEMA}.{table}: {missing}. "
                             f"Table columns: {table_cols}")
        with engine.begin() as conn:
            conn.exec_driver_sql(f"TRUNCATE TABLE {quote_name(SCHEMA)}.{quote_name(table)}")

    df.to_sql(table, engine, schema=SCHEMA, if_exists="append", index=False, chunksize=CHUNKSIZE)
    return len(df)


def main():
    wanted = [a.lower() for a in sys.argv[1:]]
    jobs = [j for j in JOBS if not wanted or j[0].lower() in wanted]
    if not jobs:
        sys.exit(f"No matching table. Available: {[j[0] for j in JOBS]}")

    password = getpass.getpass("SQL password: ")
    conn_str = (
        f"DRIVER={{{DRIVER}}};"
        f"SERVER={SERVER};"
        f"DATABASE={DATABASE};"
        f"UID={odbc_escape(USERNAME)};PWD={odbc_escape(password)};"
        "TrustServerCertificate=yes;"
    )
    engine = create_engine(
        "mssql+pyodbc:///?odbc_connect=" + urllib.parse.quote_plus(conn_str),
        fast_executemany=FAST_EXECUTEMANY,
    )

    # Fail once, clearly, if the login does not work (instead of failing on every table).
    try:
        with engine.connect():
            pass
    except Exception as e:
        sys.exit(f"Could not connect to the server: {str(e).splitlines()[0]}")

    results = []
    for table, filename in jobs:
        print(f"\n=== {SCHEMA}.{table}  <-  {filename} ===")
        try:
            n = load_one(engine, table, os.path.join(DATA_DIR, filename))
            print(f"  Done. Loaded {n} rows.")
            results.append((table, "OK", f"{n} rows"))
        except Exception as e:
            message = str(e).strip().splitlines()[0][:300]
            print("  FAILED:", message)
            results.append((table, "FAILED", message))

    print("\n=== Summary ===")
    for table, status, info in results:
        print(f"{status:7} {SCHEMA}.{table}: {info}")


if __name__ == "__main__":
    main()

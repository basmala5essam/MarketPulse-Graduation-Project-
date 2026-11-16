"""
Run a .sql file on SQL Server from your own computer, the same way SSMS does.

Why this exists: some editor extensions cut a script at every semicolon and remove it before
sending it to the server. MERGE needs its final semicolon, so it fails there.
This runner only splits the file on lines that contain just GO, so every semicolon is kept.

How to use:
1. Change USERNAME below (use the same one as in load_to_sql.py).
2. Run:   python run_sql.py Silver_market_prices.sql
   (the path can be a file in the same folder, or a full path)
3. Type the SQL password when asked (it will not show on screen, that is normal).

It runs the batches in order and stops at the first error, showing which batch failed.
SELECT results are printed (first 50 rows).
"""
import re
import sys
import getpass

import pyodbc

# ---------------- Settings ----------------
SERVER = "196.221.145.204,1433"
DATABASE = "MarketPulseDW"
USERNAME = "R5"                      # <-- change this
DRIVER = "ODBC Driver 18 for SQL Server"
MAX_ROWS_PRINTED = 50
# ------------------------------------------


def odbc_escape(value):
    return "{" + value.replace("}", "}}") + "}"


def split_batches(sql_text):
    """Split on lines that contain only GO. Drops batches that contain nothing but comments."""
    parts = re.split(r"^\s*GO\s*(?:--.*)?$", sql_text, flags=re.IGNORECASE | re.MULTILINE)
    batches = []
    for part in parts:
        without_comments = re.sub(r"--.*", "", part)
        if without_comments.strip():
            batches.append(part.strip())
    return batches


def print_rows(cursor):
    columns = [c[0] for c in cursor.description]
    rows = cursor.fetchmany(MAX_ROWS_PRINTED + 1)
    shown = rows[:MAX_ROWS_PRINTED]
    table = [columns] + [["NULL" if v is None else str(v) for v in r] for r in shown]
    widths = [max(len(row[i]) for row in table) for i in range(len(columns))]
    for n, row in enumerate(table):
        print("    " + "  ".join(cell.ljust(widths[i]) for i, cell in enumerate(row)))
        if n == 0:
            print("    " + "  ".join("-" * w for w in widths))
    if len(rows) > MAX_ROWS_PRINTED:
        print(f"    ... (only the first {MAX_ROWS_PRINTED} rows are shown)")


def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: python run_sql.py <file.sql>")

    path = sys.argv[1]
    with open(path, encoding="utf-8-sig") as f:
        batches = split_batches(f.read())
    if not batches:
        sys.exit("The file has no SQL to run.")
    print(f"{path}: {len(batches)} batches")

    password = getpass.getpass("SQL password: ")
    conn_str = (
        f"DRIVER={{{DRIVER}}};SERVER={SERVER};DATABASE={DATABASE};"
        f"UID={odbc_escape(USERNAME)};PWD={odbc_escape(password)};"
        "TrustServerCertificate=yes;"
    )
    try:
        conn = pyodbc.connect(conn_str, autocommit=True)
    except Exception as e:
        sys.exit(f"Could not connect to the server: {str(e).splitlines()[0]}")

    cursor = conn.cursor()
    for number, batch in enumerate(batches, start=1):
        first_line = next((l.strip() for l in batch.splitlines() if l.strip() and not l.strip().startswith("--")), "")
        print(f"\n[{number}/{len(batches)}] {first_line[:80]}")
        try:
            cursor.execute(batch)
            while True:
                if cursor.description:
                    print_rows(cursor)
                elif cursor.rowcount is not None and cursor.rowcount >= 0:
                    print(f"    {cursor.rowcount} rows affected")
                if not cursor.nextset():
                    break
            print("    OK")
        except Exception as e:
            print("    FAILED:", str(e).strip())
            sys.exit(f"Stopped at batch {number}. Fix it and run the file again.")

    print("\nAll batches finished.")


if __name__ == "__main__":
    main()

"""
Write the column names of every table in the warehouse to a markdown file (a data dictionary).

It reads the live database, so it shows what is really on the server (not what a script says).

How to use:
1. Change USERNAME below (the same one you use in run_sql.py).
2. Run:   python export_columns.py
3. Type the SQL password when asked (it will not show on screen, that is normal).
4. Open data_dictionary.md (it is created in the folder you ran the command from).
"""
import getpass
import sys
from collections import OrderedDict

import pyodbc

# ---------------- Settings ----------------
SERVER = "196.221.145.204,1433"
DATABASE = "MarketPulseDW"
USERNAME =  "R5"                       # <-- change this
DRIVER = "ODBC Driver 18 for SQL Server"
SCHEMAS = ["staging", "bronze", "silver", "gold"]
OUTPUT = "data_dictionary.md"
# ------------------------------------------

COLUMNS_SQL = """
SELECT c.TABLE_SCHEMA, c.TABLE_NAME, t.TABLE_TYPE, c.COLUMN_NAME, c.DATA_TYPE,
       c.CHARACTER_MAXIMUM_LENGTH, c.NUMERIC_PRECISION, c.NUMERIC_SCALE, c.IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS AS c
JOIN INFORMATION_SCHEMA.TABLES AS t
    ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME
WHERE c.TABLE_SCHEMA IN ({placeholders})
ORDER BY c.TABLE_SCHEMA, c.TABLE_NAME, c.ORDINAL_POSITION
"""

PK_SQL = """
SELECT k.TABLE_SCHEMA, k.TABLE_NAME, k.COLUMN_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS tc
JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS k
    ON k.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA AND k.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY' AND tc.TABLE_SCHEMA IN ({placeholders})
"""


def odbc_escape(value):
    return "{" + value.replace("}", "}}") + "}"


def format_type(data_type, char_len, precision, scale):
    data_type = data_type.lower()
    if data_type in ("nvarchar", "varchar", "nchar", "char", "varbinary"):
        return f"{data_type}(max)" if char_len == -1 else f"{data_type}({char_len})"
    if data_type in ("decimal", "numeric"):
        return f"{data_type}({precision},{scale})"
    return data_type


def build_markdown(column_rows, pk_rows):
    """column_rows: (schema, table, table_type, column, data_type, char_len, precision, scale, is_nullable)
       pk_rows: (schema, table, column)"""
    pks = {(r[0], r[1], r[2]) for r in pk_rows}
    tables = OrderedDict()
    for schema, table, table_type, col, dtype, clen, prec, scale, nullable in column_rows:
        info = tables.setdefault((schema, table), {"type": table_type, "cols": []})
        info["cols"].append((col, format_type(dtype, clen, prec, scale), nullable == "YES", (schema, table, col) in pks))

    lines = ["# Data dictionary", "",
             "Generated from the live database. Key: PK = primary key.", "",
             "## Summary", "", "| schema | table | columns |", "|---|---|---|"]
    for (schema, table), info in tables.items():
        kind = " (view)" if info["type"] == "VIEW" else ""
        lines.append(f"| {schema} | {table}{kind} | {len(info['cols'])} |")

    current = None
    for (schema, table), info in tables.items():
        if schema != current:
            current = schema
            lines += ["", f"## {schema}"]
        kind = " (view)" if info["type"] == "VIEW" else ""
        lines += ["", f"### {schema}.{table}{kind}", "",
                  f"{len(info['cols'])} columns: " + ", ".join(f"`{c[0]}`" for c in info["cols"]), "",
                  "| # | column | type | nullable | key |", "|---|---|---|---|---|"]
        for i, (col, dtype, nullable, is_pk) in enumerate(info["cols"], start=1):
            lines.append(f"| {i} | {col} | {dtype} | {'yes' if nullable else 'no'} | {'PK' if is_pk else ''} |")
    return "\n".join(lines) + "\n", tables


def main():
    password = getpass.getpass("SQL password: ")
    conn_str = (
        f"DRIVER={{{DRIVER}}};SERVER={SERVER};DATABASE={DATABASE};"
        f"UID={odbc_escape(USERNAME)};PWD={odbc_escape(password)};TrustServerCertificate=yes;"
    )
    try:
        conn = pyodbc.connect(conn_str, timeout=30)
    except Exception as e:
        sys.exit(f"Could not connect to the server: {str(e).splitlines()[0]}")

    placeholders = ", ".join("?" for _ in SCHEMAS)
    cursor = conn.cursor()
    cursor.execute(COLUMNS_SQL.format(placeholders=placeholders), SCHEMAS)
    column_rows = [tuple(r) for r in cursor.fetchall()]
    cursor.execute(PK_SQL.format(placeholders=placeholders), SCHEMAS)
    pk_rows = [tuple(r) for r in cursor.fetchall()]

    markdown, tables = build_markdown(column_rows, pk_rows)
    with open(OUTPUT, "w", encoding="utf-8") as f:
        f.write(markdown)

    print(f"Wrote {OUTPUT}: {len(tables)} tables")
    for schema in SCHEMAS:
        names = [t for (s, t) in tables if s == schema]
        print(f"  {schema}: {len(names)} tables")


if __name__ == "__main__":
    main()

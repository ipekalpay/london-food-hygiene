"""Load the cleaned CSV into a SQLite database and run every query in sql/analysis_queries.sql."""
import sqlite3
from pathlib import Path
import pandas as pd

root = Path(__file__).resolve().parents[1]
con = sqlite3.connect(root / "data" / "food_hygiene.db")
pd.read_csv(root / "data" / "london_food_hygiene_clean.csv").to_sql("establishments", con, if_exists="replace", index=False)

sql = (root / "sql" / "analysis_queries.sql").read_text()
for block in [b.strip() for b in sql.split(";") if b.strip()]:
    title = next((l[3:] for l in block.splitlines() if l.startswith("-- Q")), "query")
    print(f"\n=== {title} ===")
    print(pd.read_sql(block, con).to_string(index=False))

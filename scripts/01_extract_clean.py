"""Extract London food hygiene ratings from the FSA open data XML files and clean them.

Usage: python scripts/01_extract_clean.py <folder with FHRS XML files>
Output: data/london_food_hygiene_clean.csv
"""
import sys
from pathlib import Path
import xml.etree.ElementTree as ET
import pandas as pd

src = Path(sys.argv[1])
out = Path(__file__).resolve().parents[1] / "data" / "london_food_hygiene_clean.csv"

rows = []
for f in sorted(src.glob("FHRS*.xml")):
    for e in ET.parse(f).getroot().iter("EstablishmentDetail"):
        g = lambda tag: (e.findtext(tag) or "").strip()
        rows.append({
            "fhrs_id": g("FHRSID"),
            "business_name": g("BusinessName"),
            "business_type": g("BusinessType"),
            "postcode": g("PostCode"),
            "borough": g("LocalAuthorityName"),
            "rating_value": g("RatingValue"),
            "rating_date": g("RatingDate"),
            "score_hygiene": g("Scores/Hygiene"),
            "score_structural": g("Scores/Structural"),
            "score_confidence_in_management": g("Scores/ConfidenceInManagement"),
            "latitude": g("Geocode/Latitude"),
            "longitude": g("Geocode/Longitude"),
        })

df = pd.DataFrame(rows)
raw_n = len(df)

# 1. Remove duplicate establishments
df = df.drop_duplicates("fhrs_id")

# 2. Keep only numeric 0-5 ratings (drop "Exempt", "AwaitingInspection", etc.) but record how many
df["rating_status"] = df["rating_value"].where(~df["rating_value"].str.fullmatch(r"[0-5]"), "Rated")
df["rating_value"] = pd.to_numeric(df["rating_value"], errors="coerce").astype("Int64")

# 3. Types
df["rating_date"] = pd.to_datetime(df["rating_date"], errors="coerce")
for c in ["score_hygiene", "score_structural", "score_confidence_in_management", "latitude", "longitude"]:
    df[c] = pd.to_numeric(df[c], errors="coerce")

# 4. Tidy text
df["postcode"] = df["postcode"].str.upper().str.replace(r"\s+", " ", regex=True)
df["postcode_district"] = df["postcode"].str.split(" ").str[0].where(df["postcode"] != "")
df["borough"] = df["borough"].str.replace(r"\s+", " ", regex=True)

# 5. Derived fields
df["low_rating_flag"] = (df["rating_value"] <= 2).astype("Int64").where(df["rating_value"].notna())
df["years_since_inspection"] = ((pd.Timestamp("2026-11-18") - df["rating_date"]).dt.days / 365.25).round(1)

df.to_csv(out, index=False)
print(f"raw rows: {raw_n:,}  after de-dup: {len(df):,}  rated 0-5: {df['rating_value'].notna().sum():,}")
print(df["rating_status"].value_counts().to_string())
print("boroughs:", df["borough"].nunique())

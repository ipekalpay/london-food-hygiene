-- London Food Hygiene Ratings: analysis queries (SQLite)
-- Table: establishments (one row per food business, source: Food Standards Agency, extracted 18 Nov 2026)

-- Q1 Overall rating distribution (rated businesses only)
SELECT rating_value,
       COUNT(*) AS businesses,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM establishments
WHERE rating_value IS NOT NULL
GROUP BY rating_value
ORDER BY rating_value;

-- Q2 Boroughs ranked by share of low-rated (0-2) businesses
SELECT borough,
       COUNT(*) AS rated_businesses,
       SUM(low_rating_flag) AS low_rated,
       ROUND(100.0 * SUM(low_rating_flag) / COUNT(*), 1) AS pct_low_rated,
       ROUND(AVG(rating_value), 2) AS avg_rating
FROM establishments
WHERE rating_value IS NOT NULL
GROUP BY borough
ORDER BY pct_low_rated DESC;

-- Q3 Business types: which sectors carry the most risk? (types with 500+ rated businesses)
SELECT business_type,
       COUNT(*) AS rated_businesses,
       ROUND(100.0 * SUM(low_rating_flag) / COUNT(*), 1) AS pct_low_rated,
       ROUND(100.0 * SUM(rating_value = 5) / COUNT(*), 1) AS pct_top_rated
FROM establishments
WHERE rating_value IS NOT NULL
GROUP BY business_type
HAVING COUNT(*) >= 500
ORDER BY pct_low_rated DESC;

-- Q4 Restaurants only: low-rated share by borough, with a rank (window function)
SELECT borough,
       COUNT(*) AS restaurants,
       ROUND(100.0 * SUM(low_rating_flag) / COUNT(*), 1) AS pct_low_rated,
       RANK() OVER (ORDER BY 1.0 * SUM(low_rating_flag) / COUNT(*) DESC) AS risk_rank
FROM establishments
WHERE rating_value IS NOT NULL
  AND business_type = 'Restaurant/Cafe/Canteen'
GROUP BY borough
ORDER BY risk_rank
LIMIT 10;

-- Q5 Which inspection area drives low ratings? Average sub-scores (higher = worse) by rating
SELECT rating_value,
       ROUND(AVG(score_hygiene), 1) AS avg_hygiene_score,
       ROUND(AVG(score_structural), 1) AS avg_structural_score,
       ROUND(AVG(score_confidence_in_management), 1) AS avg_management_score
FROM establishments
WHERE rating_value IS NOT NULL
GROUP BY rating_value
ORDER BY rating_value;

-- Q6 Inspection backlog: businesses awaiting inspection or not inspected for 3+ years, by borough
SELECT borough,
       SUM(rating_status = 'AwaitingInspection') AS awaiting_inspection,
       SUM(years_since_inspection >= 3) AS inspected_3plus_years_ago,
       COUNT(*) AS all_businesses,
       ROUND(100.0 * (SUM(rating_status = 'AwaitingInspection') + SUM(years_since_inspection >= 3)) / COUNT(*), 1) AS pct_backlog
FROM establishments
GROUP BY borough
ORDER BY pct_backlog DESC
LIMIT 10;

-- Q7 Do older inspections hide lower ratings? Average rating by years since inspection
SELECT CASE
         WHEN years_since_inspection < 1 THEN '0-1 yrs'
         WHEN years_since_inspection < 2 THEN '1-2 yrs'
         WHEN years_since_inspection < 3 THEN '2-3 yrs'
         WHEN years_since_inspection < 5 THEN '3-5 yrs'
         ELSE '5+ yrs'
       END AS since_last_inspection,
       COUNT(*) AS businesses,
       ROUND(AVG(rating_value), 2) AS avg_rating,
       ROUND(100.0 * SUM(low_rating_flag) / COUNT(*), 1) AS pct_low_rated
FROM establishments
WHERE rating_value IS NOT NULL AND years_since_inspection IS NOT NULL
GROUP BY since_last_inspection
ORDER BY since_last_inspection;

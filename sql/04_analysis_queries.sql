/* =====================================================================
   StreamVerse OTT Analytics - 04_analysis_queries.sql
   24 business questions, answered with the clean dim_ and fact_ tables.
   Educational project - all data is simulated.
   Run after: 01_create_tables, 02_load_data, 03_data_cleaning
   ===================================================================== */
USE streamverse;

/* ============================== LEVEL 1: BASICS ============================== */

-- Q1. How many users signed up each year?
SELECT YEAR(signup_date) AS signup_year,
       COUNT(*)          AS users
FROM dim_users
GROUP BY YEAR(signup_date)
ORDER BY signup_year;

-- Q2. How many movies vs series are in the catalog?
SELECT type, COUNT(*) AS titles
FROM dim_content
GROUP BY type;

-- Q3. How many titles are there in each language?
SELECT language, COUNT(*) AS titles
FROM dim_content
GROUP BY language
ORDER BY titles DESC;

-- Q4. What is the average IMDb rating by genre?
SELECT g.genre_name,
       ROUND(AVG(c.imdb_rating), 2) AS avg_rating
FROM dim_content c
JOIN dim_genre g ON g.genre_id = c.genre_id
GROUP BY g.genre_id, g.genre_name
ORDER BY avg_rating DESC;

/* ======================= LEVEL 2: JOINS AND AGGREGATION ======================= */

-- Q5. Top 10 titles by total watch hours (minutes / 60)
SELECT c.content_id, c.title,
       ROUND(SUM(wh.minutes_watched) / 60, 1) AS total_watch_hours
FROM fact_watch_history wh
JOIN dim_content c ON c.content_id = wh.content_id
GROUP BY c.content_id, c.title
ORDER BY total_watch_hours DESC
LIMIT 10;

-- Q6. Watch hours by genre (the top row is the most-watched genre)
SELECT g.genre_name,
       ROUND(SUM(wh.minutes_watched) / 60, 1) AS total_watch_hours
FROM fact_watch_history wh
JOIN dim_content c ON c.content_id = wh.content_id
JOIN dim_genre g   ON g.genre_id   = c.genre_id
GROUP BY g.genre_id, g.genre_name
ORDER BY total_watch_hours DESC;
-- Sanity check: the genre totals must add up to this number
-- SELECT ROUND(SUM(minutes_watched) / 60, 1) FROM fact_watch_history;

-- Q7. Users and revenue by plan
SELECT p.plan_name,
       COUNT(*)           AS users,
       SUM(s.amount_paid) AS revenue
FROM fact_subscriptions s
JOIN dim_plan p ON p.plan_id = s.plan_id
GROUP BY p.plan_id, p.plan_name;

-- Q8a. Total watch hours by device type
SELECT d.device_type,
       ROUND(SUM(wh.minutes_watched) / 60, 1) AS total_watch_hours
FROM fact_watch_history wh
JOIN dim_device d ON d.device_id = wh.device_id
GROUP BY d.device_type
ORDER BY total_watch_hours DESC;

-- Q8b. Which device does each plan use most? (share of each plan's watch hours)
WITH device_plan AS (
    SELECT p.plan_name, d.device_type,
           SUM(wh.minutes_watched) / 60 AS watch_hours
    FROM fact_watch_history wh
    JOIN dim_device d         ON d.device_id = wh.device_id
    JOIN fact_subscriptions s ON s.user_id   = wh.user_id
    JOIN dim_plan p           ON p.plan_id   = s.plan_id
    GROUP BY p.plan_name, d.device_type
)
SELECT plan_name, device_type,
       ROUND(watch_hours, 1) AS watch_hours,
       ROUND(watch_hours * 100.0 / SUM(watch_hours) OVER (PARTITION BY plan_name), 1) AS pct_of_plan
FROM device_plan
ORDER BY plan_name, pct_of_plan DESC;

-- Q9. Which cities have more than 500 users?
SELECT city, COUNT(*) AS users
FROM dim_users
GROUP BY city
HAVING COUNT(*) > 500
ORDER BY users DESC;

/* ========================== LEVEL 3: TIME PATTERNS ========================== */

-- Q10a. At which hour of the day do people watch the most?
SELECT watch_hour,
       COUNT(*) AS sessions,
       ROUND(SUM(minutes_watched) / 60, 1) AS watch_hours,
       ROUND(SUM(minutes_watched) * 100.0 / SUM(SUM(minutes_watched)) OVER (), 1) AS pct_of_total
FROM fact_watch_history
GROUP BY watch_hour
ORDER BY watch_hours DESC;

-- Q10b. Same question grouped into time-of-day buckets
WITH hourly AS (
    SELECT
        CASE
            WHEN watch_hour BETWEEN 4  AND 5  THEN 'Early Morning'
            WHEN watch_hour BETWEEN 6  AND 11 THEN 'Morning'
            WHEN watch_hour BETWEEN 12 AND 15 THEN 'Afternoon'
            WHEN watch_hour BETWEEN 16 AND 19 THEN 'Evening'
            WHEN watch_hour BETWEEN 20 AND 22 THEN 'Night'
            ELSE 'Late Night'                      -- hours 23 and 0-3
        END AS time_of_day,
        CASE
            WHEN watch_hour BETWEEN 4  AND 5  THEN 1
            WHEN watch_hour BETWEEN 6  AND 11 THEN 2
            WHEN watch_hour BETWEEN 12 AND 15 THEN 3
            WHEN watch_hour BETWEEN 16 AND 19 THEN 4
            WHEN watch_hour BETWEEN 20 AND 22 THEN 5
            ELSE 6
        END AS sort_order,
        minutes_watched
    FROM fact_watch_history
)
SELECT time_of_day,
       COUNT(*) AS sessions,
       ROUND(SUM(minutes_watched) / 60, 1) AS watch_hours,
       ROUND(SUM(minutes_watched) * 100.0 / SUM(SUM(minutes_watched)) OVER (), 1) AS pct_of_total
FROM hourly
GROUP BY sort_order, time_of_day
ORDER BY sort_order;

-- Q11. Weekday vs weekend: average watch hours per calendar day
WITH daily AS (
    SELECT watch_date, SUM(minutes_watched) / 60 AS hrs
    FROM fact_watch_history
    GROUP BY watch_date
)
SELECT CASE WHEN DAYOFWEEK(watch_date) IN (1, 7) THEN 'Weekend' ELSE 'Weekday' END AS day_type,
       COUNT(*) AS days,
       ROUND(AVG(hrs), 1) AS avg_hours_per_day
FROM daily
GROUP BY day_type
ORDER BY avg_hours_per_day DESC;

-- Q12 / Q19 / Q20. Monthly revenue estimate, running total, and month-over-month growth
-- Assumption: monthly revenue = plan price x subscribers active at any point in the month
-- (an approximation; it totals about 11% above the real SUM(amount_paid)).
WITH subs AS (
    SELECT DATE_FORMAT(fs.start_date, '%Y-%m-01') AS start_month,
           DATE_FORMAT(COALESCE(fs.end_date, '2024-12-31'), '%Y-%m-01') AS end_month,
           dp.price
    FROM fact_subscriptions fs
    JOIN dim_plan dp ON dp.plan_id = fs.plan_id
),
months AS (
    SELECT DISTINCT DATE_FORMAT(full_date, '%Y-%m-01') AS month_start
    FROM dim_date
),
mom AS (
    SELECT m.month_start,
           COUNT(*)     AS active_subscribers,
           SUM(s.price) AS revenue
    FROM months m
    JOIN subs s ON m.month_start >= s.start_month
               AND m.month_start <= s.end_month
    GROUP BY m.month_start
),
prev AS (
    SELECT *,
           SUM(revenue) OVER (ORDER BY month_start) AS running_total,
           LAG(revenue) OVER (ORDER BY month_start) AS prev_revenue
    FROM mom
),
pct AS (
    SELECT *,
           ROUND((revenue - prev_revenue) * 100.0 / prev_revenue, 1) AS growth_pct
    FROM prev
)
SELECT *,
       CASE WHEN growth_pct IS NULL THEN 'N/A'
            WHEN growth_pct > 0     THEN 'Up'
            WHEN growth_pct < 0     THEN 'Down'
            ELSE 'Flat' END AS trend
FROM pct;

-- Q13. Watch time by age band (no gaps between the ranges; NULL ages become Unknown)
SELECT
    CASE
        WHEN u.age < 20  THEN '1. Under 20'
        WHEN u.age < 30  THEN '2. 20-29'
        WHEN u.age < 40  THEN '3. 30-39'
        WHEN u.age >= 40 THEN '4. 40+'
        ELSE '5. Unknown'
    END AS age_band,
    COUNT(DISTINCT u.user_id) AS users,
    COUNT(*) AS sessions,
    ROUND(AVG(wh.minutes_watched) / 60, 2) AS avg_hours_per_session,
    ROUND(SUM(wh.minutes_watched) / 60 / COUNT(DISTINCT u.user_id), 1) AS avg_hours_per_user
FROM dim_users u
JOIN fact_watch_history wh ON wh.user_id = u.user_id
GROUP BY age_band
ORDER BY age_band;

/* ========================= LEVEL 4: SUBSCRIPTIONS AND CHURN ========================= */
-- Churned = status Cancelled or Expired.

-- Q14. Overall churn rate
SELECT COUNT(*) AS total_subscribers,
       SUM(CASE WHEN status IN ('Cancelled', 'Expired') THEN 1 ELSE 0 END) AS churned,
       ROUND(SUM(CASE WHEN status IN ('Cancelled', 'Expired') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS churn_pct
FROM fact_subscriptions;

-- Q15. Churn rate by plan
SELECT p.plan_name,
       COUNT(*) AS total_subscribers,
       SUM(CASE WHEN s.status IN ('Cancelled', 'Expired') THEN 1 ELSE 0 END) AS churned,
       ROUND(SUM(CASE WHEN s.status IN ('Cancelled', 'Expired') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS churn_pct
FROM fact_subscriptions s
JOIN dim_plan p ON p.plan_id = s.plan_id
GROUP BY p.plan_name
ORDER BY churn_pct DESC;

-- Q16. How many users left within 30 days of starting?
-- (active users have a NULL end_date, so DATEDIFF is NULL and they are not counted)
SELECT COUNT(*) AS total_subscribers,
       SUM(status IN ('Cancelled', 'Expired')) AS churned,
       SUM(DATEDIFF(end_date, start_date) <= 30) AS left_within_30_days,
       ROUND(SUM(DATEDIFF(end_date, start_date) <= 30) * 100.0 / COUNT(*), 1) AS pct_of_all_subscribers,
       ROUND(SUM(DATEDIFF(end_date, start_date) <= 30) * 100.0
             / SUM(status IN ('Cancelled', 'Expired')), 1) AS pct_of_churned
FROM fact_subscriptions;

-- Q17a. Average subscription length (months) for churned users
SELECT COUNT(*) AS churned_subscribers,
       ROUND(AVG(DATEDIFF(end_date, start_date) / 30), 1) AS avg_months
FROM fact_subscriptions
WHERE status IN ('Cancelled', 'Expired');

-- Q17b. Distribution of tenure (months) for churned users: the month-1 spike
SELECT ROUND(DATEDIFF(end_date, start_date) / 30) AS months_subscribed,
       COUNT(*) AS churned_users
FROM fact_subscriptions
WHERE status IN ('Cancelled', 'Expired')
GROUP BY months_subscribed
ORDER BY months_subscribed;

/* ============================ LEVEL 5: WINDOW FUNCTIONS AND CTEs ============================ */

-- Q18. Top 3 titles per language by watch hours, with each title's share of its language
WITH cte1 AS (
    SELECT c.content_id, c.title, c.language,
           SUM(wh.minutes_watched / 60) AS total_hrs
    FROM fact_watch_history wh
    JOIN dim_content c ON wh.content_id = c.content_id
    GROUP BY c.content_id, c.title, c.language
),
cte2 AS (
    SELECT *,
           ROUND(total_hrs * 100.0 / SUM(total_hrs) OVER (PARTITION BY language), 2) AS lang_share,
           DENSE_RANK() OVER (PARTITION BY language ORDER BY total_hrs DESC) AS rnk
    FROM cte1
)
SELECT content_id, title, language, ROUND(total_hrs, 2) AS total_hrs, lang_share, rnk
FROM cte2
WHERE rnk <= 3
ORDER BY language, rnk;
-- Q18b. How concentrated is viewing? Top-3 share per language
-- (replace the final SELECT above with:)
--   SELECT language, ROUND(SUM(lang_share), 1) AS top3_share
--   FROM cte2 WHERE rnk <= 3 GROUP BY language ORDER BY top3_share DESC;

-- Q21. Hidden gems: rated above 8.3 but in the bottom 25% of watch time
-- LEFT JOIN keeps titles with zero views (the most hidden of all)
WITH content_popularity AS (
    SELECT c.content_id, c.title, c.type, c.language, c.imdb_rating,
           COALESCE(SUM(wh.minutes_watched), 0) / 60.0 AS total_hrs,
           NTILE(4) OVER (ORDER BY COALESCE(SUM(wh.minutes_watched), 0)) AS popularity_tier
    FROM dim_content c
    LEFT JOIN fact_watch_history wh ON c.content_id = wh.content_id
    GROUP BY c.content_id, c.title, c.type, c.language, c.imdb_rating
)
SELECT title, type, language, imdb_rating, ROUND(total_hrs, 1) AS total_hrs
FROM content_popularity
WHERE popularity_tier = 1 AND imdb_rating > 8.3
ORDER BY total_hrs DESC;

-- Q21b. Evidence: average watch hours of high-rated titles vs the rest
WITH content_hours AS (
    SELECT c.content_id, c.imdb_rating,
           COALESCE(SUM(wh.minutes_watched), 0) / 60.0 AS total_hrs
    FROM dim_content c
    LEFT JOIN fact_watch_history wh ON c.content_id = wh.content_id
    GROUP BY c.content_id, c.imdb_rating
)
SELECT imdb_rating > 8.3 AS high_rated,
       COUNT(*) AS titles,
       ROUND(AVG(total_hrs), 1) AS avg_hrs
FROM content_hours
WHERE imdb_rating IS NOT NULL
GROUP BY high_rated;

-- Q22. 3-month retention by signup cohort
-- Retained = still subscribed 3 months after signup. Cohorts that have not had
-- 3 months yet (relative to the last day in the data) are excluded.
WITH cohort AS (
    SELECT user_id,
           DATE_FORMAT(start_date, '%Y-%m-01') AS cohort_month,
           CASE WHEN end_date IS NULL
                  OR end_date >= DATE_ADD(start_date, INTERVAL 3 MONTH)
                THEN 1 ELSE 0 END AS retained
    FROM fact_subscriptions
    WHERE DATE_ADD(start_date, INTERVAL 3 MONTH) <= '2024-12-31'
)
SELECT cohort_month,
       COUNT(*)      AS cohort_size,
       SUM(retained) AS retained_users,
       ROUND(SUM(retained) * 100.0 / COUNT(*), 1) AS retention_pct
FROM cohort
GROUP BY cohort_month
ORDER BY cohort_month;

/* ============================ LEVEL 6: BUSINESS INSIGHTS ============================ */

-- Q23a. City x language watch hours (the full grid)
SELECT du.city, dc.language,
       ROUND(SUM(wh.minutes_watched) / 60, 2) AS total_hrs
FROM dim_users du
JOIN fact_watch_history wh ON du.user_id = wh.user_id
JOIN dim_content dc        ON wh.content_id = dc.content_id
GROUP BY du.city, dc.language
ORDER BY total_hrs DESC;

-- Q23b. Each city's favourite language and how dominant it is (share of the city's viewing)
WITH city_lang AS (
    SELECT du.city, dc.language,
           SUM(wh.minutes_watched) / 60 AS hrs
    FROM dim_users du
    JOIN fact_watch_history wh ON wh.user_id = du.user_id
    JOIN dim_content dc        ON dc.content_id = wh.content_id
    GROUP BY du.city, dc.language
),
ranked AS (
    SELECT *,
           ROUND(hrs * 100.0 / SUM(hrs) OVER (PARTITION BY city), 1) AS pct_of_city,
           ROW_NUMBER() OVER (PARTITION BY city ORDER BY hrs DESC) AS rn
    FROM city_lang
)
SELECT city, language AS top_language, ROUND(hrs, 1) AS hrs, pct_of_city
FROM ranked
WHERE rn = 1
ORDER BY pct_of_city DESC;

-- Q24a. Are the top 10% of users (by watch time) concentrated in one plan?
WITH user_hours AS (
    SELECT du.user_id, p.plan_name,
           SUM(wh.minutes_watched) / 60 AS hrs
    FROM fact_watch_history wh
    JOIN dim_users du         ON wh.user_id = du.user_id
    JOIN fact_subscriptions s ON du.user_id = s.user_id
    JOIN dim_plan p           ON s.plan_id  = p.plan_id
    GROUP BY du.user_id, p.plan_name
),
ranked AS (
    SELECT *, NTILE(10) OVER (ORDER BY hrs DESC) AS decile   -- decile 1 = top 10%
    FROM user_hours
)
SELECT plan_name,
       COUNT(*)         AS all_users,
       SUM(decile = 1)  AS top10_users,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)         AS pct_of_all_users,
       ROUND(SUM(decile = 1) * 100.0 / SUM(SUM(decile = 1)) OVER (), 1) AS pct_of_top10_users
FROM ranked
GROUP BY plan_name
ORDER BY plan_name;

-- Q24b. Power-user statistic: share of all watch hours from the top 10% of users
WITH user_hours AS (
    SELECT user_id, SUM(minutes_watched) / 60 AS hrs
    FROM fact_watch_history
    GROUP BY user_id
),
ranked AS (
    SELECT *, NTILE(10) OVER (ORDER BY hrs DESC) AS decile
    FROM user_hours
)
SELECT ROUND(SUM(CASE WHEN decile = 1 THEN hrs END) * 100.0 / SUM(hrs), 1) AS top10_share_of_hours
FROM ranked;

/* ---------------------------------------------------------------------
   Q25 (recommendations) is written up in the README: "Key findings and
   recommendations".
   --------------------------------------------------------------------- */

/* =====================================================================
   StreamVerse OTT Analytics - 05_views_for_powerbi.sql
   Views that add derived columns for Power BI.
   Power BI should ALSO import the clean tables directly:
     dim_users (or vw_dim_users), dim_content, dim_genre, dim_plan,
     dim_device, dim_date, fact_watch_history (or vw_fact_watch),
     fact_subscriptions (or vw_subscriptions), fact_ratings
   Educational project - all data is simulated.
   ===================================================================== */
USE streamverse;

/* ---------------------------------------------------------------------
   1. vw_dim_users  : users with age bands (sortable) for slicers/charts
   --------------------------------------------------------------------- */
CREATE OR REPLACE VIEW vw_dim_users AS
SELECT
    user_id, name, gender, age, city, state, signup_date,
    CASE
        WHEN age IS NULL THEN 'Unknown'
        WHEN age < 20    THEN 'Under 20'
        WHEN age < 30    THEN '20-29'
        WHEN age < 40    THEN '30-39'
        ELSE '40+'
    END AS age_band,
    CASE
        WHEN age IS NULL THEN 5
        WHEN age < 20    THEN 1
        WHEN age < 30    THEN 2
        WHEN age < 40    THEN 3
        ELSE 4
    END AS age_band_sort          -- in Power BI: sort age_band by age_band_sort
FROM dim_users;

/* ---------------------------------------------------------------------
   2. vw_fact_watch : watch history + hours + time-of-day bucket
   --------------------------------------------------------------------- */
CREATE OR REPLACE VIEW vw_fact_watch AS
SELECT
    watch_id, user_id, content_id, device_id, watch_date, watch_hour,
    minutes_watched,
    minutes_watched / 60.0 AS hours_watched,
    completed,
    CASE
        WHEN watch_hour BETWEEN 4  AND 5  THEN 'Early Morning'
        WHEN watch_hour BETWEEN 6  AND 11 THEN 'Morning'
        WHEN watch_hour BETWEEN 12 AND 15 THEN 'Afternoon'
        WHEN watch_hour BETWEEN 16 AND 19 THEN 'Evening'
        WHEN watch_hour BETWEEN 20 AND 22 THEN 'Night'
        ELSE 'Late Night'
    END AS time_of_day,
    CASE
        WHEN watch_hour BETWEEN 4  AND 5  THEN 1
        WHEN watch_hour BETWEEN 6  AND 11 THEN 2
        WHEN watch_hour BETWEEN 12 AND 15 THEN 3
        WHEN watch_hour BETWEEN 16 AND 19 THEN 4
        WHEN watch_hour BETWEEN 20 AND 22 THEN 5
        ELSE 6
    END AS time_of_day_sort
FROM fact_watch_history;

/* ---------------------------------------------------------------------
   3. vw_subscriptions : churn flags, tenure, plan details
   --------------------------------------------------------------------- */
CREATE OR REPLACE VIEW vw_subscriptions AS
SELECT
    s.sub_id, s.user_id, s.plan_id, p.plan_name, p.price,
    s.start_date, s.end_date, s.status, s.amount_paid,
    CASE WHEN s.status IN ('Cancelled', 'Expired') THEN 1 ELSE 0 END AS is_churned,
    DATEDIFF(COALESCE(s.end_date, '2024-12-31'), s.start_date)       AS tenure_days,
    ROUND(DATEDIFF(COALESCE(s.end_date, '2024-12-31'), s.start_date) / 30.0, 1) AS tenure_months,
    CASE WHEN DATEDIFF(s.end_date, s.start_date) <= 30 THEN 1 ELSE 0 END AS left_within_30_days,
    CASE
        WHEN DATE_ADD(s.start_date, INTERVAL 3 MONTH) > '2024-12-31' THEN NULL   -- too new to judge
        WHEN s.end_date IS NULL OR s.end_date >= DATE_ADD(s.start_date, INTERVAL 3 MONTH) THEN 1
        ELSE 0
    END AS retained_3m
FROM fact_subscriptions s
JOIN dim_plan p ON p.plan_id = s.plan_id;

/* ---------------------------------------------------------------------
   4. vw_monthly_revenue : estimated monthly revenue and active subscribers
   Assumption: plan price x subscribers active at any point in the month.
   --------------------------------------------------------------------- */
CREATE OR REPLACE VIEW vw_monthly_revenue AS
WITH subs AS (
    SELECT CAST(DATE_FORMAT(fs.start_date, '%Y-%m-01') AS DATE) AS start_month,
           CAST(DATE_FORMAT(COALESCE(fs.end_date, '2024-12-31'), '%Y-%m-01') AS DATE) AS end_month,
           fs.plan_id, dp.price
    FROM fact_subscriptions fs
    JOIN dim_plan dp ON dp.plan_id = fs.plan_id
),
months AS (
    SELECT DISTINCT CAST(DATE_FORMAT(full_date, '%Y-%m-01') AS DATE) AS month_start
    FROM dim_date
)
SELECT m.month_start,
       s.plan_id,
       COUNT(*)     AS active_subscribers,
       SUM(s.price) AS revenue
FROM months m
JOIN subs s ON m.month_start >= s.start_month
           AND m.month_start <= s.end_month
GROUP BY m.month_start, s.plan_id;

/* ---------------------------------------------------------------------
   5. vw_content_popularity : hours, popularity tier and hidden-gem flag
   --------------------------------------------------------------------- */
CREATE OR REPLACE VIEW vw_content_popularity AS
WITH hrs AS (
    SELECT c.content_id,
           COALESCE(SUM(w.minutes_watched), 0) / 60.0 AS total_hours
    FROM dim_content c
    LEFT JOIN fact_watch_history w ON w.content_id = c.content_id
    GROUP BY c.content_id
),
tiered AS (
    SELECT content_id, total_hours,
           NTILE(4) OVER (ORDER BY total_hours) AS popularity_tier   -- 1 = least watched 25%
    FROM hrs
)
SELECT c.content_id, c.title, c.type, c.language, g.genre_name,
       c.release_year, c.duration_min, c.imdb_rating, c.maturity_rating,
       ROUND(t.total_hours, 1) AS total_hours,
       t.popularity_tier,
       CASE WHEN t.popularity_tier = 1 AND c.imdb_rating > 8.3 THEN 1 ELSE 0 END AS is_hidden_gem
FROM dim_content c
JOIN dim_genre g ON g.genre_id = c.genre_id
JOIN tiered t    ON t.content_id = c.content_id;

/* ---------------------------------------------------------------------
   CHECKS - run these after creating the views
   --------------------------------------------------------------------- */
SELECT COUNT(*) AS users_rows         FROM vw_dim_users;          -- 5000
SELECT COUNT(*) AS watch_rows         FROM vw_fact_watch;         -- 100000
SELECT SUM(is_churned) AS churned     FROM vw_subscriptions;      -- about 3183
SELECT SUM(revenue)    AS total_est   FROM vw_monthly_revenue;    -- 9276612
SELECT SUM(is_hidden_gem) AS gems     FROM vw_content_popularity; -- 15

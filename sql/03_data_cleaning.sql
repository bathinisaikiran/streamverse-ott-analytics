/* =====================================================================
   StreamVerse OTT Analytics - 03_data_cleaning.sql
   Cleans the raw STAGING data and fills the FINAL star-schema tables.
   Run order: 01_create_tables -> 02 load (CSV import) -> 03 (this file)
   ===================================================================== */
USE streamverse;
SET SQL_SAFE_UPDATES = 0;

/* =====================================================================
   PART 1: DATA PROFILING - find the problems BEFORE fixing them
   ===================================================================== */

-- 1.1 Duplicate users (same user_id appears more than once)
SELECT user_id, COUNT(*) AS copies
FROM stg_dim_users GROUP BY user_id HAVING COUNT(*) > 1;

-- 1.2 Duplicate watch records
SELECT COUNT(*) AS duplicate_watch_rows
FROM (SELECT watch_id FROM stg_fact_watch_history
      GROUP BY watch_id HAVING COUNT(*) > 1) d;

-- 1.3 Inconsistent city names (casing / extra spaces)
SELECT city, COUNT(*) AS users
FROM stg_dim_users GROUP BY city ORDER BY LOWER(TRIM(city)), city;

-- 1.4 Missing values per column
SELECT
    SUM(NULLIF(TRIM(age), '')    IS NULL) AS missing_age,
    SUM(NULLIF(TRIM(gender), '') IS NULL) AS missing_gender
FROM stg_dim_users;

SELECT SUM(NULLIF(TRIM(minutes_watched), '') IS NULL) AS missing_minutes
FROM stg_fact_watch_history;

SELECT SUM(NULLIF(TRIM(imdb_rating), '') IS NULL) AS missing_imdb
FROM stg_dim_content;

/* =====================================================================
   PART 2: CLEAN + LOAD INTO FINAL TABLES
   (re-runnable: empties the final tables first)
   ===================================================================== */
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE fact_ratings;
TRUNCATE fact_watch_history;
TRUNCATE fact_subscriptions;
TRUNCATE dim_content;
TRUNCATE dim_users;
TRUNCATE dim_date;
TRUNCATE dim_device;
TRUNCATE dim_plan;
TRUNCATE dim_genre;
SET FOREIGN_KEY_CHECKS = 1;

-- 2.1 Small lookup tables: just cast types
INSERT INTO dim_genre (genre_id, genre_name)
SELECT CAST(genre_id AS UNSIGNED), TRIM(genre_name) FROM stg_dim_genre;

INSERT INTO dim_plan (plan_id, plan_name, price, screens)
SELECT CAST(plan_id AS UNSIGNED), TRIM(plan_name), CAST(price AS UNSIGNED), CAST(screens AS UNSIGNED)
FROM stg_dim_plan;

INSERT INTO dim_device (device_id, device_type)
SELECT CAST(device_id AS UNSIGNED), TRIM(device_type) FROM stg_dim_device;

-- 2.2 Date dimension: text -> DATE, 'True'/'False' -> 1/0
INSERT INTO dim_date (full_date, day_of_month, month_num, month_name, quarter_num, year_num, weekday_name, is_weekend)
SELECT STR_TO_DATE(TRIM(full_date), '%Y-%m-%d'),
       CAST(`day` AS UNSIGNED), CAST(`month` AS UNSIGNED), TRIM(month_name),
       CAST(`quarter` AS UNSIGNED), CAST(`year` AS UNSIGNED), TRIM(weekday),
       IF(LOWER(TRIM(is_weekend)) = 'true', 1, 0)
FROM stg_dim_date;

-- 2.3 Users: remove duplicates, standardise city, fix age, fill missing gender
INSERT INTO dim_users (user_id, name, gender, age, city, state, signup_date)
SELECT user_id, name, gender, age, city, state, signup_date
FROM (
    SELECT CAST(user_id AS UNSIGNED)                               AS user_id,
           TRIM(name)                                              AS name,
           COALESCE(NULLIF(TRIM(gender), ''), 'Unknown')           AS gender,
           CAST(CAST(NULLIF(TRIM(age), '') AS DECIMAL(5,1)) AS UNSIGNED) AS age,   -- '30.0' -> 30
           CONCAT(UPPER(LEFT(TRIM(city), 1)), LOWER(SUBSTRING(TRIM(city), 2)))     AS city,  -- ' hyderabad ' -> 'Hyderabad'
           TRIM(state)                                             AS state,
           STR_TO_DATE(TRIM(signup_date), '%Y-%m-%d')              AS signup_date,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY user_id) AS rn
    FROM stg_dim_users
) t
WHERE rn = 1;                                                      -- keep one copy of each user

-- 2.4 Content (missing IMDb ratings stay NULL - we don't invent ratings)
INSERT INTO dim_content (content_id, title, type, genre_id, language, release_year, duration_min, imdb_rating, maturity_rating)
SELECT CAST(content_id AS UNSIGNED), TRIM(title), TRIM(type), CAST(genre_id AS UNSIGNED),
       TRIM(language), CAST(release_year AS UNSIGNED), CAST(duration_min AS UNSIGNED),
       CAST(NULLIF(TRIM(imdb_rating), '') AS DECIMAL(3,1)), TRIM(maturity_rating)
FROM stg_dim_content;

-- 2.5 Subscriptions (blank end_date = still active -> NULL)
INSERT INTO fact_subscriptions (sub_id, user_id, plan_id, start_date, end_date, status, amount_paid)
SELECT CAST(sub_id AS UNSIGNED), CAST(user_id AS UNSIGNED), CAST(plan_id AS UNSIGNED),
       STR_TO_DATE(TRIM(start_date), '%Y-%m-%d'),
       STR_TO_DATE(NULLIF(TRIM(end_date), ''), '%Y-%m-%d'),
       TRIM(status), CAST(amount_paid AS UNSIGNED)
FROM stg_fact_subscriptions;

-- 2.6 Watch history: remove duplicate watch_ids
INSERT INTO fact_watch_history (watch_id, user_id, content_id, device_id, watch_date, watch_hour, minutes_watched, completed)
SELECT watch_id, user_id, content_id, device_id, watch_date, watch_hour, minutes_watched, completed
FROM (
    SELECT CAST(watch_id AS UNSIGNED)   AS watch_id,
           CAST(user_id AS UNSIGNED)    AS user_id,
           CAST(content_id AS UNSIGNED) AS content_id,
           CAST(device_id AS UNSIGNED)  AS device_id,
           STR_TO_DATE(TRIM(watch_date), '%Y-%m-%d') AS watch_date,
           CAST(watch_hour AS UNSIGNED) AS watch_hour,
           CAST(CAST(NULLIF(TRIM(minutes_watched), '') AS DECIMAL(10,1)) AS UNSIGNED) AS minutes_watched,
           TRIM(completed)              AS completed,
           ROW_NUMBER() OVER (PARTITION BY watch_id ORDER BY watch_id) AS rn
    FROM stg_fact_watch_history
) t
WHERE rn = 1;

-- Fill missing minutes_watched with that title's average (about 1% of rows)
UPDATE fact_watch_history f
JOIN (SELECT content_id, ROUND(AVG(minutes_watched)) AS avg_min
      FROM fact_watch_history
      WHERE minutes_watched IS NOT NULL
      GROUP BY content_id) a ON a.content_id = f.content_id
SET f.minutes_watched = a.avg_min
WHERE f.minutes_watched IS NULL;

-- 2.7 Ratings
INSERT INTO fact_ratings (rating_id, user_id, content_id, rating, review_date)
SELECT CAST(rating_id AS UNSIGNED), CAST(user_id AS UNSIGNED), CAST(content_id AS UNSIGNED),
       CAST(rating AS UNSIGNED), STR_TO_DATE(TRIM(review_date), '%Y-%m-%d')
FROM stg_fact_ratings;

/* =====================================================================
   PART 3: VALIDATION - compare with the profiling results above
   ===================================================================== */
-- Expected: users 5000 | content 300 | watch 100000 | subs 5000 | ratings ~6242
SELECT 'dim_users' AS tbl, COUNT(*) AS rows_now FROM dim_users
UNION ALL SELECT 'dim_content', COUNT(*) FROM dim_content
UNION ALL SELECT 'fact_watch_history', COUNT(*) FROM fact_watch_history
UNION ALL SELECT 'fact_subscriptions', COUNT(*) FROM fact_subscriptions
UNION ALL SELECT 'fact_ratings', COUNT(*) FROM fact_ratings;

-- Cities should now be 10 clean values
SELECT city, COUNT(*) AS users FROM dim_users GROUP BY city ORDER BY users DESC;

-- Remaining NULLs: only age (left unknown on purpose) and imdb_rating
SELECT SUM(age IS NULL) AS null_age, SUM(gender = 'Unknown') AS unknown_gender FROM dim_users;
SELECT SUM(minutes_watched IS NULL) AS null_minutes FROM fact_watch_history;

SET SQL_SAFE_UPDATES = 1;

/* =====================================================================
   StreamVerse OTT Analytics - 02_load_data.sql
   Loads the 9 CSVs into the STAGING tables.

   BEFORE YOU RUN:
   1. Replace YOUR_PATH below with the full path to this repo's data/raw folder.
      Use forward slashes, e.g.  C:/projects/streamverse-ott-analytics/data/raw/
   2. Enable local infile (run once):  SET GLOBAL local_infile = 1;
   3. In MySQL Workbench: Edit connection -> Advanced tab -> Others, add:
          OPT_LOCAL_INFILE=1
      then reconnect.
   ===================================================================== */
USE streamverse;

/* Windows-created CSVs end lines with \r\n.  If you see odd characters at
   the end of the last column after loading, change '\r\n' to '\n'.      */

TRUNCATE stg_dim_users;
LOAD DATA LOCAL INFILE 'YOUR_PATH/data/raw/dim_users.csv'
INTO TABLE stg_dim_users FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n' IGNORE 1 ROWS;

TRUNCATE stg_dim_content;
LOAD DATA LOCAL INFILE 'YOUR_PATH/data/raw/dim_content.csv'
INTO TABLE stg_dim_content FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n' IGNORE 1 ROWS;

TRUNCATE stg_dim_genre;
LOAD DATA LOCAL INFILE 'YOUR_PATH/data/raw/dim_genre.csv'
INTO TABLE stg_dim_genre FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n' IGNORE 1 ROWS;

TRUNCATE stg_dim_plan;
LOAD DATA LOCAL INFILE 'YOUR_PATH/data/raw/dim_plan.csv'
INTO TABLE stg_dim_plan FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n' IGNORE 1 ROWS;

TRUNCATE stg_dim_device;
LOAD DATA LOCAL INFILE 'YOUR_PATH/data/raw/dim_device.csv'
INTO TABLE stg_dim_device FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n' IGNORE 1 ROWS;

TRUNCATE stg_dim_date;
LOAD DATA LOCAL INFILE 'YOUR_PATH/data/raw/dim_date.csv'
INTO TABLE stg_dim_date FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n' IGNORE 1 ROWS;

TRUNCATE stg_fact_watch_history;
LOAD DATA LOCAL INFILE 'YOUR_PATH/data/raw/fact_watch_history.csv'
INTO TABLE stg_fact_watch_history FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n' IGNORE 1 ROWS;

TRUNCATE stg_fact_subscriptions;
LOAD DATA LOCAL INFILE 'YOUR_PATH/data/raw/fact_subscriptions.csv'
INTO TABLE stg_fact_subscriptions FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n' IGNORE 1 ROWS;

TRUNCATE stg_fact_ratings;
LOAD DATA LOCAL INFILE 'YOUR_PATH/data/raw/fact_ratings.csv'
INTO TABLE stg_fact_ratings FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n' IGNORE 1 ROWS;

/* ---------------- Verify: row counts should match ---------------------
   users 5060 | content 300 | genre 12 | plan 3 | device 4 | date 731
   watch ~100400 | subscriptions 5000 | ratings ~6242
   ----------------------------------------------------------------------*/
SELECT 'stg_dim_users' AS tbl, COUNT(*) AS row_count FROM stg_dim_users
UNION ALL SELECT 'stg_dim_content', COUNT(*) FROM stg_dim_content
UNION ALL SELECT 'stg_dim_genre', COUNT(*) FROM stg_dim_genre
UNION ALL SELECT 'stg_dim_plan', COUNT(*) FROM stg_dim_plan
UNION ALL SELECT 'stg_dim_device', COUNT(*) FROM stg_dim_device
UNION ALL SELECT 'stg_dim_date', COUNT(*) FROM stg_dim_date
UNION ALL SELECT 'stg_fact_watch_history', COUNT(*) FROM stg_fact_watch_history
UNION ALL SELECT 'stg_fact_subscriptions', COUNT(*) FROM stg_fact_subscriptions
UNION ALL SELECT 'stg_fact_ratings', COUNT(*) FROM stg_fact_ratings;

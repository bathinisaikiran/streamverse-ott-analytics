/* =====================================================================
   StreamVerse OTT Analytics - 01_create_tables.sql
   Creates the database, STAGING tables (raw CSV landing zone) and
   FINAL star-schema tables (with primary/foreign keys).
   Educational project - all data is simulated.
   ===================================================================== */

CREATE DATABASE IF NOT EXISTS streamverse;
USE streamverse;

/* ---------------------------------------------------------------------
   PART 1: STAGING TABLES
   Everything is VARCHAR on purpose: raw CSVs contain blanks, floats like
   '30.0' for ages, duplicates and messy text. We cast types while cleaning.
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS stg_dim_users, stg_dim_content, stg_dim_genre, stg_dim_plan,
                     stg_dim_device, stg_dim_date, stg_fact_watch_history,
                     stg_fact_subscriptions, stg_fact_ratings;

CREATE TABLE stg_dim_users (
    user_id VARCHAR(20), name VARCHAR(100), gender VARCHAR(20), age VARCHAR(20),
    city VARCHAR(100), state VARCHAR(100), signup_date VARCHAR(30)
);

CREATE TABLE stg_dim_content (
    content_id VARCHAR(20), title VARCHAR(150), type VARCHAR(20), genre_id VARCHAR(20),
    language VARCHAR(50), release_year VARCHAR(10), duration_min VARCHAR(10),
    imdb_rating VARCHAR(10), maturity_rating VARCHAR(20)
);

CREATE TABLE stg_dim_genre  (genre_id VARCHAR(20), genre_name VARCHAR(50));
CREATE TABLE stg_dim_plan   (plan_id VARCHAR(20), plan_name VARCHAR(50), price VARCHAR(20), screens VARCHAR(10));
CREATE TABLE stg_dim_device (device_id VARCHAR(20), device_type VARCHAR(50));

CREATE TABLE stg_dim_date (
    full_date VARCHAR(30), day VARCHAR(5), month VARCHAR(5), month_name VARCHAR(20),
    quarter VARCHAR(5), year VARCHAR(5), weekday VARCHAR(20), is_weekend VARCHAR(10)
);

CREATE TABLE stg_fact_watch_history (
    watch_id VARCHAR(20), user_id VARCHAR(20), content_id VARCHAR(20), device_id VARCHAR(20),
    watch_date VARCHAR(30), watch_hour VARCHAR(5), minutes_watched VARCHAR(20), completed VARCHAR(5)
);

CREATE TABLE stg_fact_subscriptions (
    sub_id VARCHAR(20), user_id VARCHAR(20), plan_id VARCHAR(20), start_date VARCHAR(30),
    end_date VARCHAR(30), status VARCHAR(20), amount_paid VARCHAR(20)
);

CREATE TABLE stg_fact_ratings (
    rating_id VARCHAR(20), user_id VARCHAR(20), content_id VARCHAR(20),
    rating VARCHAR(5), review_date VARCHAR(30)
);

/* ---------------------------------------------------------------------
   PART 2: FINAL TABLES (star schema)
   Created now, filled in 02_data_cleaning.sql
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS fact_ratings, fact_subscriptions, fact_watch_history,
                     dim_users, dim_content, dim_genre, dim_plan, dim_device, dim_date;

CREATE TABLE dim_genre (
    genre_id   INT PRIMARY KEY,
    genre_name VARCHAR(50) NOT NULL
);

CREATE TABLE dim_plan (
    plan_id   INT PRIMARY KEY,
    plan_name VARCHAR(50) NOT NULL,
    price     INT NOT NULL,
    screens   INT NOT NULL
);

CREATE TABLE dim_device (
    device_id   INT PRIMARY KEY,
    device_type VARCHAR(50) NOT NULL
);

CREATE TABLE dim_date (
    full_date    DATE PRIMARY KEY,
    day_of_month TINYINT,
    month_num    TINYINT,
    month_name   VARCHAR(20),
    quarter_num  TINYINT,
    year_num     SMALLINT,
    weekday_name VARCHAR(20),
    is_weekend   BOOLEAN
);

CREATE TABLE dim_users (
    user_id     INT PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    gender      VARCHAR(20),
    age         TINYINT UNSIGNED,
    city        VARCHAR(100),
    state       VARCHAR(100),
    signup_date DATE
);

CREATE TABLE dim_content (
    content_id      INT PRIMARY KEY,
    title           VARCHAR(150) NOT NULL,
    type            VARCHAR(20),
    genre_id        INT,
    language        VARCHAR(50),
    release_year    SMALLINT,
    duration_min    SMALLINT,
    imdb_rating     DECIMAL(3,1),
    maturity_rating VARCHAR(20),
    FOREIGN KEY (genre_id) REFERENCES dim_genre(genre_id)
);

CREATE TABLE fact_subscriptions (
    sub_id      INT PRIMARY KEY,
    user_id     INT NOT NULL,
    plan_id     INT NOT NULL,
    start_date  DATE,
    end_date    DATE NULL,            -- NULL = still active
    status      VARCHAR(20),
    amount_paid INT,
    FOREIGN KEY (user_id) REFERENCES dim_users(user_id),
    FOREIGN KEY (plan_id) REFERENCES dim_plan(plan_id)
);

CREATE TABLE fact_watch_history (
    watch_id        INT PRIMARY KEY,
    user_id         INT NOT NULL,
    content_id      INT NOT NULL,
    device_id       INT NOT NULL,
    watch_date      DATE,
    watch_hour      TINYINT,
    minutes_watched INT NULL,
    completed       CHAR(1),
    FOREIGN KEY (user_id)    REFERENCES dim_users(user_id),
    FOREIGN KEY (content_id) REFERENCES dim_content(content_id),
    FOREIGN KEY (device_id)  REFERENCES dim_device(device_id),
    INDEX idx_watch_date (watch_date),
    INDEX idx_watch_user (user_id),
    INDEX idx_watch_content (content_id)
);

CREATE TABLE fact_ratings (
    rating_id   INT PRIMARY KEY,
    user_id     INT NOT NULL,
    content_id  INT NOT NULL,
    rating      TINYINT,
    review_date DATE,
    FOREIGN KEY (user_id)    REFERENCES dim_users(user_id),
    FOREIGN KEY (content_id) REFERENCES dim_content(content_id)
);

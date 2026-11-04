"""
StreamVerse OTT Analytics - synthetic data generator
Educational project. All data is simulated.

Requires: pandas, numpy   (pip install pandas numpy)
Run:      python generate_data.py
Output:   ./data/raw/*.csv
"""
import os
import numpy as np
import pandas as pd

SEED = 42
rng = np.random.default_rng(SEED)

N_USERS = 5000
N_CONTENT = 300
N_WATCH = 100_000
START = pd.Timestamp("2023-01-01")
END = pd.Timestamp("2024-12-31")
OUT = os.path.join("data", "raw")
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- dimensions
genres = ["Action", "Drama", "Comedy", "Thriller", "Romance", "Sci-Fi",
          "Horror", "Family", "Crime", "Documentary", "Fantasy", "Sports"]
dim_genre = pd.DataFrame({"genre_id": range(1, len(genres) + 1), "genre_name": genres})

dim_plan = pd.DataFrame({
    "plan_id": [1, 2, 3],
    "plan_name": ["Mobile", "Basic", "Premium"],
    "price": [149, 299, 649],
    "screens": [1, 2, 4],
})

dim_device = pd.DataFrame({
    "device_id": [1, 2, 3, 4],
    "device_type": ["Mobile", "TV", "Laptop", "Tablet"],
})

dim_date = pd.DataFrame({"date": pd.date_range(START, END)})
dim_date["day"] = dim_date["date"].dt.day
dim_date["month"] = dim_date["date"].dt.month
dim_date["month_name"] = dim_date["date"].dt.month_name()
dim_date["quarter"] = dim_date["date"].dt.quarter
dim_date["year"] = dim_date["date"].dt.year
dim_date["weekday"] = dim_date["date"].dt.day_name()
dim_date["is_weekend"] = dim_date["date"].dt.weekday >= 5

# ---------------------------------------------------------------- users
cities = {  # city: (state, weight, dominant language)
    "Hyderabad": ("Telangana", 16, "Telugu"),
    "Bengaluru": ("Karnataka", 14, "Kannada"),
    "Chennai": ("Tamil Nadu", 13, "Tamil"),
    "Mumbai": ("Maharashtra", 15, "Hindi"),
    "Delhi": ("Delhi", 14, "Hindi"),
    "Kolkata": ("West Bengal", 6, "Hindi"),
    "Pune": ("Maharashtra", 7, "Hindi"),
    "Vijayawada": ("Andhra Pradesh", 5, "Telugu"),
    "Kochi": ("Kerala", 5, "Malayalam"),
    "Ahmedabad": ("Gujarat", 5, "Hindi"),
}
city_names = list(cities)
city_w = np.array([cities[c][1] for c in city_names], dtype=float)
city_w /= city_w.sum()

first_m = ["Aarav", "Vihaan", "Arjun", "Rohan", "Karthik", "Sai", "Rahul", "Aditya",
           "Manoj", "Suresh", "Naveen", "Ravi", "Kiran", "Varun", "Imran", "Harsha"]
first_f = ["Ananya", "Diya", "Priya", "Sneha", "Meera", "Lakshmi", "Pooja", "Kavya",
           "Nisha", "Divya", "Swathi", "Ritu", "Anjali", "Sana", "Isha", "Tanvi"]
last = ["Reddy", "Sharma", "Iyer", "Nair", "Patel", "Khan", "Das", "Rao", "Singh",
        "Gupta", "Naidu", "Menon", "Verma", "Joshi", "Kumar", "Pillai"]

gender = rng.choice(["Male", "Female"], N_USERS, p=[0.56, 0.44])
names = [f"{rng.choice(first_m if g == 'Male' else first_f)} {rng.choice(last)}" for g in gender]
user_city = rng.choice(city_names, N_USERS, p=city_w)
age = np.clip(rng.normal(30, 9, N_USERS).round(), 16, 65).astype(int)
# signups spread over the 2 years with growth (more recent signups)
span = (END - START).days
signup_offset = (span * rng.beta(1.4, 1.0, N_USERS)).astype(int)
signup_date = START + pd.to_timedelta(signup_offset, unit="D")

dim_users = pd.DataFrame({
    "user_id": range(1, N_USERS + 1),
    "name": names,
    "gender": gender,
    "age": age,
    "city": user_city,
    "state": [cities[c][0] for c in user_city],
    "signup_date": signup_date,
})
user_lang_pref = np.array([cities[c][2] for c in user_city])

# ---------------------------------------------------------------- content
languages = ["Telugu", "Hindi", "Tamil", "English", "Malayalam", "Kannada"]
lang_w = [0.20, 0.28, 0.16, 0.20, 0.08, 0.08]
adj = ["Silent", "Midnight", "Broken", "Crimson", "Lost", "Hidden", "Golden", "Wild",
       "Last", "Secret", "Burning", "Eternal", "Rising", "Shadow", "Electric",
       "Frozen", "Neon", "Royal", "Fallen", "Distant"]
noun = ["Empire", "Promise", "Horizon", "Streets", "Legacy", "Storm", "Journey", "Echo",
        "Kingdom", "Rivals", "Signal", "Harvest", "Frontier", "Verdict", "Mirage",
        "Diaries", "Code", "Tides", "Chronicles", "Gambit"]
titles = set()
while len(titles) < N_CONTENT:
    titles.add(f"{rng.choice(adj)} {rng.choice(noun)}")
titles = list(titles)

ctype = rng.choice(["Movie", "Series"], N_CONTENT, p=[0.6, 0.4])
duration = np.where(ctype == "Movie",
                    rng.normal(130, 20, N_CONTENT), rng.normal(45, 8, N_CONTENT)).round().astype(int)
dim_content = pd.DataFrame({
    "content_id": range(1, N_CONTENT + 1),
    "title": titles,
    "type": ctype,
    "genre_id": rng.integers(1, len(genres) + 1, N_CONTENT),
    "language": rng.choice(languages, N_CONTENT, p=lang_w),
    "release_year": rng.integers(2005, 2025, N_CONTENT),
    "duration_min": duration,   # movie length, or per-episode length for series
    "imdb_rating": np.clip(rng.normal(6.8, 1.0, N_CONTENT), 3.5, 9.5).round(1),
    "maturity_rating": rng.choice(["U", "U/A 13+", "U/A 16+", "A"], N_CONTENT, p=[0.2, 0.3, 0.3, 0.2]),
})

# popularity: heavy-tailed so a few blockbusters dominate
pop = rng.pareto(1.6, N_CONTENT) + 0.2
pop[rng.choice(N_CONTENT, 12, replace=False)] *= 6     # blockbusters
pop = pop * (1 + 0.04 * (dim_content["imdb_rating"].values - 6.8))
# a few high-rated but hidden gems
gems = dim_content.index[dim_content["imdb_rating"] > 8.3]
pop[gems] *= 0.15
dim_content["_pop"] = pop

# ---------------------------------------------------------------- subscriptions
plan_choice = rng.choice([1, 2, 3], N_USERS, p=[0.38, 0.34, 0.28])
plan_price = dim_plan.set_index("plan_id")["price"]

# lifetime in months: big churn spike at month 1 (free trial ending)
life = np.where(rng.random(N_USERS) < 0.30, 1, rng.geometric(0.10, N_USERS) + 1)
sub_start = signup_date
sub_end_raw = sub_start + pd.to_timedelta(life * 30, unit="D")
cancelled = (sub_end_raw <= END)
status = np.where(cancelled, np.where(rng.random(N_USERS) < 0.7, "Cancelled", "Expired"), "Active")
sub_end = pd.Series(sub_end_raw).where(cancelled)   # NaT for active subs
billed_months = np.where(cancelled, life, np.maximum(np.ceil(np.asarray((END - sub_start).days) / 30), 1))
fact_subscriptions = pd.DataFrame({
    "sub_id": range(1, N_USERS + 1),
    "user_id": dim_users["user_id"],
    "plan_id": plan_choice,
    "start_date": sub_start,
    "end_date": sub_end,
    "status": status,
    "amount_paid": (plan_price.loc[plan_choice].values * billed_months).astype(int),
})

# ---------------------------------------------------------------- watch history
user_active_end = pd.Series(sub_end_raw).clip(upper=END)
active_days = np.maximum(np.asarray((user_active_end.values - sub_start.values) / np.timedelta64(1, "D")).astype(int), 1)

# some users watch way more than others
activity = rng.gamma(1.2, 1.0, N_USERS) * np.sqrt(active_days / 30)
activity /= activity.sum()

n_gen = int(N_WATCH * 1.45)           # oversample, then thin for weekend pattern
uid_idx = rng.choice(N_USERS, n_gen, p=activity)
day_off = (rng.random(n_gen) * active_days[uid_idx]).astype(int)
watch_date = sub_start[uid_idx] + pd.to_timedelta(day_off, unit="D")
watch_date = pd.DatetimeIndex(watch_date)

# weekday thinning -> weekend spike
keep_p = np.where(watch_date.weekday >= 5, 1.0, 0.72)
keep = rng.random(n_gen) < keep_p
uid_idx, watch_date = uid_idx[keep][:N_WATCH], watch_date[keep][:N_WATCH]
n = len(uid_idx)

# peak hours 8-11 PM
hour_w = np.array([2, 1, 1, 1, 1, 1, 2, 3, 3, 3, 3, 4, 5, 4, 4, 4, 5, 6, 8, 11, 16, 18, 14, 6], float)
hour_w /= hour_w.sum()
watch_hour = rng.choice(24, n, p=hour_w)

# content choice: 60% from the user's regional language, 40% anywhere
content_idx = np.empty(n, dtype=int)
lang_arr = dim_content["language"].values
pref = user_lang_pref[uid_idx]
regional = rng.random(n) < 0.60
for lang in languages:
    pool = np.where(lang_arr == lang)[0]
    p = pop[pool] / pop[pool].sum()
    m = regional & (pref == lang)
    content_idx[m] = rng.choice(pool, m.sum(), p=p)
rest = ~(regional & np.isin(pref, languages))
content_idx[rest] = rng.choice(N_CONTENT, rest.sum(), p=pop / pop.sum())

# device depends on plan
plan_of_watch = plan_choice[uid_idx]
device = np.empty(n, dtype=int)
for pid, probs in {1: [0.88, 0.02, 0.07, 0.03],
                   2: [0.45, 0.30, 0.18, 0.07],
                   3: [0.25, 0.50, 0.17, 0.08]}.items():
    m = plan_of_watch == pid
    device[m] = rng.choice([1, 2, 3, 4], m.sum(), p=probs)

# minutes watched
dur = dim_content["duration_min"].values[content_idx]
frac = np.clip(rng.beta(2.2, 1.2, n), 0.05, 1.0)
minutes = (dur * frac).round().astype(int).clip(min=1)
completed = np.where(frac >= 0.90, "Y", "N")

fact_watch = pd.DataFrame({
    "watch_id": range(1, n + 1),
    "user_id": uid_idx + 1,
    "content_id": content_idx + 1,
    "device_id": device,
    "watch_date": watch_date.normalize(),
    "watch_hour": watch_hour,
    "minutes_watched": minutes,
    "completed": completed,
})

# ---------------------------------------------------------------- ratings
sample = fact_watch[fact_watch["completed"] == "Y"].sample(frac=0.45, random_state=SEED)
imdb = dim_content.set_index("content_id")["imdb_rating"]
base = imdb.loc[sample["content_id"]].values / 2
rating = np.clip(np.round(base + rng.normal(0, 0.8, len(sample))), 1, 5).astype(int)
fact_ratings = pd.DataFrame({
    "rating_id": range(1, len(sample) + 1),
    "user_id": sample["user_id"].values,
    "content_id": sample["content_id"].values,
    "rating": rating,
    "review_date": sample["watch_date"].values + pd.to_timedelta(rng.integers(0, 4, len(sample)), unit="D"),
})
fact_ratings = fact_ratings.drop_duplicates(["user_id", "content_id"]).reset_index(drop=True)
fact_ratings["rating_id"] = range(1, len(fact_ratings) + 1)

# ---------------------------------------------------------------- inject dirty data (~3-5%)
def messy_case(s):
    r = rng.random(len(s))
    out = s.copy()
    out[r < 0.02] = out[r < 0.02].str.lower()
    out[(r >= 0.02) & (r < 0.035)] = out[(r >= 0.02) & (r < 0.035)].str.upper()
    out[(r >= 0.035) & (r < 0.045)] = " " + out[(r >= 0.035) & (r < 0.045)] + " "
    return out

dim_users["city"] = messy_case(dim_users["city"])
dim_users.loc[rng.random(N_USERS) < 0.03, "age"] = np.nan
dim_users.loc[rng.random(N_USERS) < 0.02, "gender"] = np.nan
dim_users = pd.concat([dim_users, dim_users.sample(60, random_state=1)], ignore_index=True)  # duplicates

fact_watch.loc[rng.random(len(fact_watch)) < 0.01, "minutes_watched"] = np.nan
fact_watch = pd.concat([fact_watch, fact_watch.sample(400, random_state=2)], ignore_index=True)

dim_content.loc[rng.random(N_CONTENT) < 0.03, "imdb_rating"] = np.nan
dim_content = dim_content.drop(columns="_pop")

# ---------------------------------------------------------------- save
tables = {
    "dim_users": dim_users, "dim_content": dim_content, "dim_genre": dim_genre,
    "dim_plan": dim_plan, "dim_device": dim_device, "dim_date": dim_date,
    "fact_watch_history": fact_watch, "fact_subscriptions": fact_subscriptions,
    "fact_ratings": fact_ratings,
}
for name, df in tables.items():
    df.to_csv(os.path.join(OUT, f"{name}.csv"), index=False)
    print(f"{name:20s} {len(df):>8,} rows")
print(f"\nSaved to {OUT}/")
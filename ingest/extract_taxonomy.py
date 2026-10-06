import os, csv, requests

HERE = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(HERE, "token.txt")) as f:
    TOKEN = f.read().strip()

DATASETS = {"76ig-c548": range(2010, 2020), "erm2-nwe9": range(2020, 2027)}
SELECT = "date_trunc_ym(created_date) AS ym,complaint_type,agency,count(1) AS n"
GROUP = "date_trunc_ym(created_date),complaint_type,agency"

def month_bounds(y, m):
    ny, nm = (y + 1, 1) if m == 12 else (y, m + 1)
    return f"{y}-{m:02d}-01", f"{ny}-{nm:02d}-01"

out = os.path.join(HERE, "taxonomy_census.csv")
with open(out, "w", newline="", encoding="utf-8") as f:
    w, header_written = csv.writer(f), False
    for ds, years in DATASETS.items():
        for y in years:
            for m in range(1, 13):
                start, end = month_bounds(y, m)
                print(f"{ds} {start} ...", end=" ", flush=True)
                params = {
                    "$select": SELECT,
                    "$where": f"created_date >= '{start}' AND created_date < '{end}'",
                    "$group": GROUP,
                    "$limit": 50000,
                    "$$app_token": TOKEN,
                }
                try:
                    r = requests.get(
                        f"https://data.cityofnewyork.us/resource/{ds}.csv",
                        params=params, timeout=90)
                    r.raise_for_status()
                except Exception as e:
                    print(f"FAILED: {type(e).__name__}")
                    continue
                rows = list(csv.reader(r.text.splitlines()))
                if len(rows) <= 1:
                    print("empty")
                    continue
                w.writerows(rows if not header_written else rows[1:])
                header_written = True
                print(f"{len(rows)-1} rows", flush=True)
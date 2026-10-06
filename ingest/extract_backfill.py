import os, csv, requests

HERE = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(HERE, "token.txt")) as f:
    TOKEN = f.read().strip()

BASE = "https://data.cityofnewyork.us/resource/erm2-nwe9.csv"
COLS = ("unique_key,created_date,closed_date,agency,complaint_type,descriptor,"
        "status,incident_zip,incident_address,borough,latitude,longitude,bbl")

MONTHS = MONTHS = ([(2024, m) for m in range(6, 13)]
          + [(2025, m) for m in range(1, 13)]
          + [(2026, m) for m in range(1, 9)])

def bounds(y, m):
    ny, nm = (y + 1, 1) if m == 12 else (y, m + 1)
    return f"{y}-{m:02d}-01", f"{ny}-{nm:02d}-01"

out = os.path.join(HERE, "sr_backfill.csv")
with open(out, "w", newline="", encoding="utf-8") as f:
    w, header_written = csv.writer(f), False
    for y, m in MONTHS:
        start, end = bounds(y, m)
        offset, total = 0, 0
        while True:
            params = {"$select": COLS,
                      "$where": f"created_date >= '{start}' AND created_date < '{end}'",
                      "$order": "unique_key", "$limit": 50000,
                      "$offset": offset, "$$app_token": TOKEN}
            try:
                r = requests.get(BASE, params=params, timeout=120)
                r.raise_for_status()
            except Exception as e:
                print(f"{start} +{offset} FAILED: {type(e).__name__}", flush=True)
                break
            rows = list(csv.reader(r.text.splitlines()))
            if len(rows) <= 1:
                break
            w.writerows(rows if not header_written else rows[1:])
            header_written = True
            total += len(rows) - 1
            offset += 50000
        print(f"{start}: {total}", flush=True)
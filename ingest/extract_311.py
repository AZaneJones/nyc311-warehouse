import os, csv, requests

HERE = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(HERE, "token.txt")) as f:
    TOKEN = f.read().strip()

BASE = "https://data.cityofnewyork.us/resource/erm2-nwe9.csv"
COLS = ("unique_key,created_date,closed_date,agency,complaint_type,descriptor,"
        "status,incident_zip,incident_address,borough,latitude,longitude,bbl")
PARAMS = {"$select": COLS, "$where": "created_date >= '2022-01-01'",
          "$order": "unique_key", "$limit": 50000}
# PARAMS["$$app_token"] = "your_token_here"

with open("sr_2021_present.csv", "w", newline="", encoding="utf-8") as f:
    w, offset, header_written = csv.writer(f), 0, False
    while True:
        r = requests.get(BASE, params={**PARAMS, "$offset": offset})
        r.raise_for_status()
        rows = list(csv.reader(r.text.splitlines()))
        if len(rows) <= 1:
            break
        w.writerows(rows if not header_written else rows[1:])
        header_written = True
        offset += 50000
        print(offset, flush=True)
        
"""Build data.json for the PA mail ballot precinct map.

Runs sql/current.sql (2026 returns + registration by VTD) and sql/benchmark.sql
once per comparison year, then writes data.json in the shape index.html reads:

    {"at": ISO timestamp, "A": [[cut, county, rows], ...],
     "B": {"2022": [[cut, county, rows], ...], "2024": ..., "2025": ...}}

Needs Google credentials with BigQuery read access (the GitHub Action
provides them from the GCP_SA_KEY secret) and BQ_PROJECT in the environment.
"""
import datetime as dt
import json
import os
import pathlib
import sys
from concurrent.futures import ThreadPoolExecutor

from google.cloud import bigquery

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROJECT = os.environ["BQ_PROJECT"]
ELECTION_DAYS = {"2022": "2022-11-08", "2024": "2024-11-05", "2025": "2025-11-04"}


def sql(name, **params):
    text = (ROOT / "sql" / name).read_text()
    for key, value in {"project": PROJECT, **params}.items():
        text = text.replace("{" + key + "}", value)
    return text


def run(client, query):
    rows = client.query(query).result()
    return [[row["cut"], row["cty"], row["d"]] for row in rows]


def main():
    client = bigquery.Client(project=PROJECT)
    jobs = {"A": sql("current.sql")}
    for year, eday in ELECTION_DAYS.items():
        jobs[year] = sql("benchmark.sql", year=year, eday=eday)

    with ThreadPoolExecutor(max_workers=4) as pool:
        results = dict(zip(jobs, pool.map(lambda q: run(client, q), jobs.values())))

    # Refuse to publish a partial or empty result.
    for key, rows in results.items():
        ballots = sum(int(rec.split(",")[1]) + int(rec.split(",")[2]) + int(rec.split(",")[3])
                      for _, _, d in rows for rec in (d or "").split(";") if rec)
        print(f"{key}: {len(rows)} counties, cutoff {rows[0][0] if rows else '?'}, {ballots:,} ballots")
        if len(rows) < 60 or ballots == 0:
            sys.exit(f"{key} looks incomplete ({len(rows)} counties, {ballots} ballots); not writing data.json")

    out = {
        "at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "A": results["A"],
        "B": {year: results[year] for year in ELECTION_DAYS},
    }
    (ROOT / "data.json").write_text(json.dumps(out, separators=(",", ":")))
    print("wrote data.json")


if __name__ == "__main__":
    main()

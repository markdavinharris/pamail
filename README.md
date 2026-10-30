# PA Mail Ballot Returns by Precinct

Precinct map of Pennsylvania returned mail ballots by registered party, 2026 compared with 2022, 2024 or 2025 at the same number of days before Election Day. Served with GitHub Pages at <https://markdavinharris.github.io/pamail/>.

## What's here

| Path | What it is |
|---|---|
| `index.html` | The map. Reads `data.json` and `vtd.topo.json` from the same folder. |
| `vtd.topo.json` | 2020 Census voting districts for Pennsylvania (TIGER/Line), simplified. |
| `data.json` | Precinct counts, rebuilt by the GitHub Action. Not present until the first run. |
| `sql/` | The two BigQuery queries: 2026 returns plus registration, and one comparison year. |
| `scripts/build_data.py` | Runs the queries and writes `data.json`. |
| `.github/workflows/refresh-data.yml` | Runs the script every morning and on demand, then commits `data.json`. |

## One-time setup: let the Action read BigQuery

1. In Google Cloud, project `coldspark-voterdata`, create a service account (for example `pamail-refresh`).
2. Give it **BigQuery Job User** on the project and **BigQuery Data Viewer** on the `national_file` dataset.
3. Create a JSON key for it.
4. In this repo, go to Settings → Secrets and variables → Actions and add a secret named `GCP_SA_KEY` holding the whole JSON key.
5. Go to Actions → Refresh data → Run workflow. When it finishes, the site updates within a minute or two.

After that it refreshes every morning at about 7 am Eastern. Each run scans roughly 5 GB in BigQuery.

## Method

Accepted mail and absentee returns, one ballot per voter. Party is the registration party on the ballot record (Other includes unaffiliated). The 2026 cutoff is the latest return date with at least 1,000 ballots logged; each comparison year is cut at the same number of days before its own Election Day (Nov 8, 2022; Nov 5, 2024; Nov 4, 2025; vs Nov 3, 2026). Voters are placed on 2020 Census VTDs by census block; comparison-year voters no longer on the current file are placed through their precinct in that year's voter file snapshot.

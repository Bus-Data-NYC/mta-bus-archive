## Set up

To create a `positions` table in the Postgres database `dbname`:
```
make init DATABASE=dbname
```

A MySQL file is also included:
```
make mysql_init DATABASE=dbname
```

## Download an MTA Bus Time archive

Downloads a (UTC) day from `data.mytransit.nyc`, and imports into the Postgres database `dbname`:
```
make download DATE=20161231 DATABASE=dbname
```

The same, for MySQL:
```
make mysql_download DATE=20161231 DATABASE=dbname
```

## Scraping

### Install

```
pip install -r requirements.txt
```
This includes the Google Protobuf library, which is useful for GTFS-Realtime APIs (e.g. MBTA). You may omit it if not using a GTFS-Realtime API.

### Scrape

The scrapers depend on the environment variables `MTA_KEY` and `MBTA_KEY`.

Download the current positions from the MTA API and save in `mtadb.positions`:

```
export MTA_KEY=xyz123
python3 src/scrape_mta.py mtadb
```

Download the current positions from the MBTA API and save in `mbtadb.positions`:

```
export MBTA_KEY=xyz123
python3 src/scrape_mbta.py mbtadb
```

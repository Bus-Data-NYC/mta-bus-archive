# bus-archive

Download archived NYC MTA bus position data, and scrape data from the MTA or MBTA.

Bus position data is archived at [data.mytransit.nyc](http://data.mytransit.nyc).

## Set up

This set up assumes that you have a Postgres or MySQL database running.

Create a `positions` table in the Postgres database `dbname`:
```
make init DATABASE=dbname
```

A MySQL version is also included:
```
make mysql_init DATABASE=dbname
```

You can specify a remote table using the `PSQLFLAGS` or `MYQSLFLAGS` variables:
```
make init DATABASE=dbname PSQLFLAGS="-U psql_user"
make mysql_init DATABASE=dbname MYSQLFLAGS="-u mysql_user"
```

## Download an MTA Bus Time archive

Download a (UTC) day from [data.mytransit.nyc](http://data.mytransit.nyc), and import into the Postgres database `dbname`:
```
make download DATE=20161231 DATABASE=dbname
```

The same, for MySQL:
```
make mysql_download DATE=20161231 DATABASE=dbname
```

## Scraping

Scrapers have been tested with Python 3.4 and above. Earlier versions of Python (e.g. 2.7) will likely work, but no guarantees.

### Install

```
make install 
make init DATABASE=dbname
```
The first line install the Python requirements. This includes the [Google Protobuf](https://pypi.python.org/pypi/protobuf/3.3.0) library, which is useful for GTFS-Realtime APIs (e.g. MBTA). You may omit it this library if not using a GTFS-Realtime API.

The second line creates a `positions` table in the database `dbname`.

### Scrape

Both scrapers load results into a table named `positions`. The assumption is that you're not using them in the same database.

The scrapers depend on the environment variables `MTA_KEY` and `MBTA_KEY` to contain the API keys, which are available after signing up at each agency.

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

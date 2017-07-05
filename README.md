# mta bus archive

Download archived NYC MTA bus position data, and scrape gtfs-realtime data from the MTA.

Bus position data is archived at [data.mytransit.nyc](http://data.mytransit.nyc).

Requirements:
* Python 3.x
* PostgreSQL

## Set up

Create a set of tables in the Postgres database `dbname`:
```
make install PG_DATABASE=dbname
```

This command will create a number of whose tables that begin with `rt_`, notable `rt_vehicle_positions`, `rt_alerts` and `rt_trip_updates`. It will also install the Python requirements, including the [Google Protobuf](https://pypi.python.org/pypi/protobuf/3.3.0) library.

You can specify a remote table using the `PSQLFLAGS` or `MYQSLFLAGS` variables:
```
make install PG_DATABASE=dbname PSQLFLAGS="-U psql_user"
```

## Download an MTA Bus Time archive file

Download a (UTC) day from [data.mytransit.nyc](http://data.mytransit.nyc), and import into the Postgres database `dbname`:
```
make download DATE=20161231 PG_DATABASE=dbname
```

The same, for MySQL:
```
make mysql_download DATE=20161231 PG_DATABASE=dbname
```

## Scraping

Scrapers have been tested with Python 3.4 and above. Earlier versions of Python (e.g. 2.7) won't work.

### Scrape

The scraper depends assumes an environment variable, `BUSTIME_API_KEY`, contains an MTA BusTime API key. [Get a key from the MTA](http://bustime.mta.info/wiki/Developers/Index).

```
export BUSTIME_API_KEY=xyz123
```

Download the current positions from the MTA API and save a local PostgreSQL database named `mtadb`:
```
make positions PG_DATABASE=dbname
```

Download current trip updates:
```
make tripupdates PG_DATABASE=dbname
```

Download current alerts:
```
make alerts PG_DATABASE=dbname
```

## Scheduling

The included `crontab` shows an example setup for downloading data from the MTA API. It assumes that this repository is saved in `~/mta-bus-archive`. Fill-in the `DATABASE` and `BUSTIME_API_KEY` variables before using.

# Setting up Postgres in CentOS

Pick a user name and a database name. In this example they are `myusername` and `mydbname`.

```
sudo yum install -y git gcc python35 python35-devel postgresql postgresql-libs postgresql-server postgresql92-contrib postgresql-devel
curl https://bootstrap.pypa.io/get-pip.py | sudo python3.5
sudo su - postgres; createuser -s myusername; exit
sudo make install PYTHON=python35 PG_DATABASE=mydbname PG_HOST= PG_USER=myusername
```

# License

Available under the Apache License.

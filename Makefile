shell = bash

PYTHON = python

DATABASE =
PSQLFLAGS = 
PSQL = psql $(DATABASE) $(PSQLFLAGS)

SQLALCHEMY_URL = postgresql://localhost/$(DATABASE)

ARCHIVE = http://data.mytransit.nyc.s3.amazonaws.com/bus_time

DATE = 20161101

PB2 = src/gtfs_realtime_pb2.py

alerts 		= http://gtfsrt.prod.obanyc.com/alerts
positions 	= http://gtfsrt.prod.obanyc.com/vehiclePositions
tripupdates = http://gtfsrt.prod.obanyc.com/tripUpdates

GTFSRDB = $(PYTHON) src/gtfsrdb.py -d $(SQLALCHEMY_URL)

.PHONY: all mysql-% psql psql-% psql_init mysql_init download mysql_download \
	positions alerts tripupdates

.PRECIOUS: xz/bus_time_%.csv.xz

all:

# Scrape GTFS-rt data.

alerts:; $(GTFSRDB) -a $(alerts)?key=$(BUSTIME_API_KEY)

positions:; $(GTFSRDB) -p $(positions)?key=$(BUSTIME_API_KEY)

tripupdates:; $(GTFSRDB) -t $(tripupdates)?key=$(BUSTIME_API_KEY)

# Download past data

download: psql-$(DATE)

ARCHIVE_COLS = timestamp, \
	vehicle_id, \
	latitude, \
	longitude, \
	bearing, \
	progress, \
	trip_start_date, \
	trip_id, \
	block_assigned, \
	stop_id, \
	dist_along_route, \
	dist_from_stop

psql-%: csv/bus_time_%.csv
	$(PSQL) -c "COPY rt_vehicle_positions ($(ARCHIVE_COLS)) \
		FROM '$(abspath $<)' CSV HEADER DELIMITER AS ',' NULL AS '\N'"

csv/%.csv: xz/%.csv.xz | csv
	@rm -f $@
	xz -kd $<
	mv $(<D)/$(@F) $@

xz/bus_time_%.csv.xz: | xz
	$(eval YEAR=$(shell echo $* | sed 's/\(.\{4\}\).*/\1/'))
	$(eval MONTH=$(shell echo $* | sed 's/.\{4\}\(.\{2\}\).*/\1/'))
	curl -o $@ $(ARCHIVE)/$(YEAR)/$(YEAR)-$(MONTH)/$(@F)

install: sql/schema.sql
	$(PYTHON) -m pip install -r requirements.txt
	-createdb $(DATABASE)
	psql $(DATABASE) $(PSQLFLAGS) -f $<

$(PB2): src/%_realtime_pb2.py: src/%-realtime.proto
	protoc $< -I$(<D) --python_out=$(@D)

csv xz: ; mkdir -p $@

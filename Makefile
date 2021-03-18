shell = bash

PYTHON = python

PGUSER ?= $(USER)
PGDATABASE ?= $(PGUSER)
PSQLFLAGS = $(PGDATABASE)
PSQL = psql $(PSQLFLAGS)

export PGDATABASE PGUSER

DATE = 2001-01-01
YEAR = $(shell echo $(DATE) | sed 's/\(.\{4\}\)-.*/\1/')
MONTH =	$(shell echo $(DATE) | sed 's/.\{4\}-\(.\{2\}\)-.*/\1/')

alerts 		= http://gtfsrt.prod.obanyc.com/alerts
positions 	= http://gtfsrt.prod.obanyc.com/vehiclePositions
tripupdates = http://gtfsrt.prod.obanyc.com/tripUpdates

GTFSRDB = $(PYTHON) src/gtfsrdb.py

GOOGLE_BUCKET ?= $(PGDATABASE)

MODE ?= download
ARCHIVE ?= s3

.PHONY: all psql psql-% mysql mysql-% \
	init install clean-date \
	positions alerts tripupdates gcloud

all:

# Scrape GTFS-rt data.

alerts: src/gtfs_realtime_pb2.py
	$(GTFSRDB) --alerts $(alerts)?key=$(BUSTIME_API_KEY)

positions: src/gtfs_realtime_pb2.py
	$(GTFSRDB) --vehicle-positions $(positions)?key=$(BUSTIME_API_KEY)

tripupdates: src/gtfs_realtime_pb2.py
	$(GTFSRDB) --trip-updates $(tripupdates)?key=$(BUSTIME_API_KEY)

ifeq ($(MODE),upload)

# Archive real-time data

gcloud: $(YEAR)/$(MONTH)/$(DATE)-bus-positions.csv.xz
	gsutil cp -rna public-read $< gs://$(GOOGLE_BUCKET)/$<

s3: s3-positions s3-alerts s3-trip-updates s3-messages

s3-%: $(YEAR)/$(MONTH)/$(DATE)-bus-%.csv.xz
	aws s3 cp --quiet --acl public-read $< s3://$(S3BUCKET)/$<

$(YEAR)/$(MONTH)/$(DATE)-bus-positions.csv.xz: | $(YEAR)/$(MONTH)
	$(PSQL) -c "COPY (\
		SELECT * FROM rt.vehicle_positions WHERE timestamp::date = '$(DATE)'::date \
		) TO STDOUT WITH (FORMAT CSV, HEADER true)" | \
	xz -z - > $@

$(YEAR)/$(MONTH)/$(DATE)-bus-alerts.csv.xz: | $(YEAR)/$(MONTH)
	$(PSQL) -c "COPY (\
		SELECT * FROM rt.alerts a \
		  WHERE a.start::date = '$(DATE)'::date \
		) TO STDOUT WITH (FORMAT CSV, HEADER true)" | \
	xz -z - > $@

$(YEAR)/$(MONTH)/$(DATE)-bus-trip-updates.csv.xz: | $(YEAR)/$(MONTH)
	$(PSQL) -c "COPY (\
		SELECT * FROM rt.trip_updates WHERE timestamp::date = '$(DATE)'::date \
		) TO STDOUT WITH (FORMAT CSV, HEADER true)" | \
	xz -z - > $@

$(YEAR)/$(MONTH)/$(DATE)-bus-messages.csv.xz: | $(YEAR)/$(MONTH)
	$(PSQL) -c "COPY (\
		SELECT * FROM rt.messages WHERE timestamp::date = '$(DATE)'::date \
		) TO STDOUT WITH (FORMAT CSV, HEADER true)" | \
	xz -z - > $@

clean-date:
	$(PSQL) -c "DELETE FROM rt.vehicle_positions where timestamp::date = '$(DATE)'::date"
	$(PSQL) -c "DELETE FROM rt.alerts WHERE start::date = '$(DATE)'::date"
	$(PSQL) -c "DELETE FROM rt.trip_updates where timestamp::date = '$(DATE)'::date"
	$(PSQL) -c "DELETE FROM rt.messages where timestamp::date = '$(DATE)'::date"
	rm -f $(YEAR)/$(MONTH)/$(DATE)-bus-*.csv{.xz,}

else

# Download past data

ARCHIVE_COLS = timestamp,trip_id, \
	route_id,trip_start_time,trip_start_date, \
	vehicle_id,vehicle_label,vehicle_license_plate,	\
	latitude,longitude,bearing,speed,stop_id, \
	stop_status,occupancy_status,congestion_level, \
	progress,block_assigned,dist_along_route,dist_from_stop

ifeq ($(ARCHIVE),s3)

ARCHIVE_URL = https://s3.amazonaws.com/nycbuspositions/$(YEAR)/$(MONTH)/$*-bus-positions.csv.xz
download: $(YEAR)/$(MONTH)/$(DATE)-bus-positions.csv.xz

else ifeq ($(ARCHIVE),mytransit)

ARCHIVE_COLS = timestamp,vehicle_id, \
	latitude,longitude,bearing,progress, \
	trip_start_date,trip_id,block_assigned, \
	stop_id,dist_along_route,dist_from_stop

ARCHIVE_URL = http://data.mytransit.nyc.s3.amazonaws.com/bus_time/$(YEAR)/$(YEAR)-$(MONTH)/bus_time_$*.csv.xz
download: $(YEAR)/$(MONTH)/$(subst -,,$(DATE))-bus-positions.csv.xz

else ifeq ($(ARCHIVE),gcloud)

ARCHIVE_URL = https://storage.googleapis.com/mta-bus-archive/$(YEAR)/$(MONTH)/$*-bus-positions.csv.xz
download: $(YEAR)/$(MONTH)/$(DATE)-bus-positions.csv.xz

endif

psql: psql-$(DATE)

psql-%: $(YEAR)/$(MONTH)/%-bus-positions.csv.xz $(YEAR)/$(MONTH)/%-bus-stoptime-updates.csv.xz $(YEAR)/$(MONTH)/%-bus-trip-updates.csv.xz
	xz --decompress --stdout $< \
	| $(PSQL) -c "COPY rt.vehicle_positions ($(ARCHIVE_COLS)) \
		FROM STDIN (FORMAT CSV, HEADER true)"
	xz --decompress --stdout $(YEAR)/$(MONTH)/$*-bus-trip-updates.csv.xz \
	| $(PSQL) -c "COPY rt.trip_updates ($(TRIP_COLS)) \
		FROM STDIN (FORMAT CSV, HEADER true)"
	xz --decompress --stdout $(YEAR)/$(MONTH)/$*-bus-stoptime-updates.csv.xz \
	| $(PSQL) -c "COPY rt.stop_time_updates ($(STOPTIME_COLS)) \
		FROM STDIN (FORMAT CSV, HEADER true)"

mysql: mysql-$(DATE)

mysql-%: $(YEAR)/$(MONTH)/%-bus-positions.csv
	mysql --local-infile -e "LOAD DATA LOCAL INFILE '$<' \
		IGNORE INTO TABLE positions \
		FIELDS TERMINATED BY ',' \
		LINES TERMINATED BY '\r\n' \
		IGNORE 1 LINES"

%.csv: %.csv.xz
	xz -cd $< > $@

$(YEAR)/$(MONTH)/%-bus-positions.csv.xz: | $(YEAR)/$(MONTH)
	curl -L -o $@ $(ARCHIVE_URL)

endif

$(YEAR)/$(MONTH):
	mkdir -p $@

YUM_REQUIRES = git \
	gcc \
	python \
	python-devel \
	postgresql95.x86_64 \
	postgresql95-libs.x86_64 \
	postgresql95-server.x86_64 \
	postgresql95-contrib.x86_64 \
	postgresql95-devel.x86_64 \
	openssl-devel \
	libffi-devel

init: sql/schema.sql
	$(PSQL) -f $<

create:
	service postgresql95 initdb
	service postgresql95 start
	createuser -s $(PGUSER)
	-createdb $(PGDATABASE)

install: requirements.txt
	-which yum && sudo yum install -y $(YUM_REQUIRES)
	$(PYTHON) -m pip > /dev/null || curl https://bootstrap.pypa.io/get-pip.py | sudo $(PYTHON)
	$(PYTHON) -m pip install --upgrade --requirement $<

src/gtfs_realtime_pb2.py: src/gtfs-realtime.proto
	protoc $< -I$(<D) --python_out=$(@D)

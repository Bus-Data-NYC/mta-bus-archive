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

PB2 = src/gtfs_realtime_pb2.py

alerts 		= http://gtfsrt.prod.obanyc.com/alerts
positions 	= http://gtfsrt.prod.obanyc.com/vehiclePositions
tripupdates = http://gtfsrt.prod.obanyc.com/tripUpdates

GTFSRDB = $(PYTHON) src/gtfsrdb.py

GOOGLE_BUCKET ?= $(PGDATABASE)

PREFIX = .

MODE ?= download
ARCHIVE ?= gcloud

.PHONY: all psql psql-% init install clean-date \
	positions alerts tripupdates gcloud

all:

# Scrape GTFS-rt data.

alerts:; $(GTFSRDB) --alerts $(alerts)?key=$(BUSTIME_API_KEY)

positions:; $(GTFSRDB) --vehicle-positions $(positions)?key=$(BUSTIME_API_KEY)

tripupdates:; $(GTFSRDB) --trip-updates $(tripupdates)?key=$(BUSTIME_API_KEY)

ifeq ($(MODE),upload)

# Archive real-time data

gcloud: $(PREFIX)/$(YEAR)/$(MONTH)/$(DATE)-bus-positions.csv.xz
	gsutil cp -rna public-read $< gs://$(GOOGLE_BUCKET)/$<

$(PREFIX)/$(YEAR)/$(MONTH)/$(DATE)-bus-positions.csv.xz: | $(PREFIX)/$(YEAR)/$(MONTH)
	$(PSQL) -c "COPY (\
		SELECT * FROM rt_vehicle_positions WHERE timestamp::date = '$(DATE)'::date \
		) TO STDOUT WITH (FORMAT CSV, HEADER true)" | \
	xz -z - > $@

clean-date:
	$(PSQL) -c "DELETE FROM rt_vehicle_positions where timestamp::date = '$(DATE)'::date"
	rm -f $(PREFIX)/$(YEAR)/$(MONTH)/$(DATE)-bus-positions.csv{.xz,}

else

# Download past data

ifeq ($(ARCHIVE),mytransit)

ARCHIVE_COLS = timestamp,vehicle_id, \
	latitude,longitude,bearing,progress, \
	trip_start_date,trip_id,block_assigned, \
	stop_id,dist_along_route,dist_from_stop

ARCHIVE_URL = http://data.mytransit.nyc.s3.amazonaws.com/bus_time/$(YEAR)/$(YEAR)-$(MONTH)/bus_time_$*.csv.xz
download: psql-$(subst -,,$(DATE))

else

ARCHIVE_COLS = timestamp,trip_id, \
	route_id,trip_start_time,trip_start_date, \
	vehicle_id,vehicle_label,vehicle_license_plate,	\
	latitude,longitude,bearing,speed,stop_id, \
	stop_status,occupancy_status,congestion_level, \
	progress,block_assigned,dist_along_route,dist_from_stop

ARCHIVE_URL = https://storage.googleapis.com/mta-bus-archive/$(YEAR)/$(MONTH)/$*-bus-positions.csv.xz
download: psql-$(DATE)

endif

psql-%: $(PREFIX)/$(YEAR)/$(MONTH)/%-bus-positions.csv
	$(PSQL) -c "COPY rt_vehicle_positions ($(ARCHIVE_COLS)) \
		FROM STDIN (FORMAT CSV, HEADER true)" < $<

mysql-%: $(PREFIX)/$(YEAR)/$(MONTH)/%-bus-positions.csv
	mysql --local-infile -e "LOAD DATA LOCAL INFILE '$<' \
		IGNORE INTO TABLE positions \
		FIELDS TERMINATED BY ',' \
		LINES TERMINATED BY '\r\n' \
		IGNORE 1 LINES"

%.csv: %.csv.xz
	xz -cd $< > $@

$(PREFIX)/$(YEAR)/$(MONTH)/%-bus-positions.csv.xz: | $(PREFIX)/$(YEAR)/$(MONTH)
	curl -L -o $@ $(ARCHIVE_URL)

endif

$(PREFIX)/$(YEAR)/$(MONTH): | $(PREFIX)
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

$(PB2): src/%_realtime_pb2.py: src/%-realtime.proto
	protoc $< -I$(<D) --python_out=$(@D)

shell = bash

PYTHON = python

PG_HOST =
PG_PORT =
PG_USER =
PG_DATABASE =
PSQLFLAGS = $(PG_DATABASE)

CONNECTION = dbname=$(PG_DATABASE)

ifdef PG_HOST
CONNECTION += host=$(PG_HOST)
PSQLFLAGS += -h $(PG_HOST)
endif

ifdef PG_PORT
CONNECTION += port=$(PG_PORT)
PSQLFLAGS += -p $(PG_PORT)
endif

ifdef PG_USER
CONNECTION += user=$(PG_USER)
PSQLFLAGS += -U $(PG_USER)
endif

ifdef PG_PASSWORD
CONNECTION += password=$(PG_PASSWORD)
endif

PSQL = psql $(PSQLFLAGS)

ARCHIVE = http://data.mytransit.nyc.s3.amazonaws.com/bus_time

DATE = 2001-01-01
YEAR = $(shell echo $(DATE) | sed 's/\(.\{4\}\)-.*/\1/')
MONTH =	$(shell echo $(DATE) | sed 's/.\{4\}-\(.\{2\}\)-.*/\1/')

PB2 = src/gtfs_realtime_pb2.py

alerts 		= http://gtfsrt.prod.obanyc.com/alerts
positions 	= http://gtfsrt.prod.obanyc.com/vehiclePositions
tripupdates = http://gtfsrt.prod.obanyc.com/tripUpdates

GTFSRDB = $(PYTHON) src/gtfsrdb.py -d "$(CONNECTION)"

GOOGLE_BUCKET ?= $(PG_DATABASE)

PREFIX = .

.PHONY: all psql psql-% init install clean-date \
	positions alerts tripupdates gcloud

all:

# Scrape GTFS-rt data.

alerts:; $(GTFSRDB) --alerts $(alerts)?key=$(BUSTIME_API_KEY)

positions:; $(GTFSRDB) --vehicle-positions $(positions)?key=$(BUSTIME_API_KEY)

tripupdates:; $(GTFSRDB) --trip-updates $(tripupdates)?key=$(BUSTIME_API_KEY)

# Archive real-time data

gcloud: $(PREFIX)/$(YEAR)/$(MONTH)/$(DATE)-bus-positions.csv.xz
	gsutil cp -rna public-read $< gs://$(GOOGLE_BUCKET)/$<

%.xz: %
	xz -c $< > $@

$(PREFIX)/$(YEAR)/$(MONTH)/$(DATE)-bus-positions.csv: | $(PREFIX)/$(YEAR)/$(MONTH)
	$(PSQL) -c "COPY (\
	SELECT * FROM rt_vehicle_positions WHERE timestamp::date = '$(DATE)'::date \
	) TO STDOUT DELIMITER ',' CSV HEADER" > $@

$(PREFIX)/$(YEAR)/$(MONTH): | $(PREFIX)
	mkdir -p $@

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
		FROM STDIN CSV HEADER DELIMITER AS ',' NULL AS '\N'" < $(abspath $<)

mysql-%: csv/bus_time_%.csv
	mysql --local-infile -e "LOAD DATA LOCAL INFILE '$<' \
		IGNORE INTO TABLE positions \
		FIELDS TERMINATED BY ',' \
		LINES TERMINATED BY '\r\n' \
		IGNORE 1 LINES"
 
csv/%.csv: xz/%.csv.xz | csv
	@rm -f $@
	xz -kd $<
	mv $(<D)/$(@F) $@

xz/bus_time_%.csv.xz: | xz
	$(eval YEAR=$(shell echo $* | sed 's/\(.\{4\}\).*/\1/'))
	$(eval MONTH=$(shell echo $* | sed 's/.\{4\}\(.\{2\}\).*/\1/'))
	curl -o $@ $(ARCHIVE)/$(YEAR)/$(YEAR)-$(MONTH)/$(@F)

clean-date:
	$(PSQL) -c "DELETE FROM rt_vehicle_positions where timestamp::date = '$(DATE)'::date"

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
	createuser -s $(PG_USER)
	-createdb $(PG_DATABASE)

install: requirements.txt
	which yum && sudo yum install -y $(YUM_REQUIRES)
	$(PYTHON) -m pip > /dev/null || curl https://bootstrap.pypa.io/get-pip.py | sudo $(PYTHON)
	$(PYTHON) -m pip install --upgrade --requirement $<

$(PB2): src/%_realtime_pb2.py: src/%-realtime.proto
	protoc $< -I$(<D) --python_out=$(@D)

csv xz: ; mkdir -p $@

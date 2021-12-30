shell := /bin/bash

PYTHON = python

psql = psql

DATE = 2001-01-01
YEAR = $(shell echo $(DATE) | sed 's/\(.\{4\}\)-.*/\1/')
MONTH =	$(shell echo $(DATE) | sed 's/.\{4\}-\(.\{2\}\)-.*/\1/')

alerts 		= http://gtfsrt.prod.obanyc.com/alerts
positions 	= http://gtfsrt.prod.obanyc.com/vehiclePositions
tripupdates = http://gtfsrt.prod.obanyc.com/tripUpdates

gtfsrdb = ./src/gtfsrdb.py

GOOGLE_BUCKET ?= $(PGDATABASE)

MODE ?= download
ARCHIVE ?= s3

.PHONY: all psql psql-% mysql mysql-% \
	init install clean-date \
	positions alerts tripupdates gcloud \
	psql psql-$(DATE) psql-bus-positions psql-stoptime-updates psql-trip-updates

all:

# Scrape GTFS-rt data.

alerts: src/gtfs_realtime_pb2.py
	$(gtfsrdb) --alerts $(alerts)?key=$(BUSTIME_API_KEY)

positions: src/gtfs_realtime_pb2.py
	$(gtfsrdb) --vehicle-positions $(positions)?key=$(BUSTIME_API_KEY)

tripupdates: src/gtfs_realtime_pb2.py
	$(gtfsrdb) --trip-updates $(tripupdates)?key=$(BUSTIME_API_KEY)

# Archive real-time data

gcloud: $(YEAR)/$(MONTH)/$(DATE)-bus-positions.csv.xz
	gsutil cp -rna public-read $< gs://$(GOOGLE_BUCKET)/$<

s3: s3-positions s3-alerts s3-trip-updates s3-messages

s3-%: $(YEAR)/$(MONTH)/$(DATE)-bus-%.csv.xz
	aws s3 mv --quiet --acl public-read $< s3://$(S3BUCKET)/$<

xz: $(foreach x,positions alerts trip-updates messages entity-selectors,$(YEAR)/$(MONTH)/$(DATE)-bus-$(x).csv.xz) ## Save csv.xz files for all tables

$(YEAR)/$(MONTH)/$(DATE)-bus-positions.csv.xz: | $(YEAR)/$(MONTH)
	$(psql) -c "COPY (\
		SELECT * FROM rt.vehicle_positions WHERE timestamp::date = '$(DATE)'::date \
		) TO STDOUT WITH (FORMAT CSV, HEADER true)" | \
	xz -z - > $@

$(YEAR)/$(MONTH)/$(DATE)-bus-alerts.csv.xz: | $(YEAR)/$(MONTH)
	$(psql) -c "COPY (\
		SELECT * FROM rt.alerts a WHERE a.start::date = '$(DATE)'::date \
		) TO STDOUT WITH (FORMAT CSV, HEADER true)" | \
	xz -z - > $@

$(YEAR)/$(MONTH)/$(DATE)-bus-trip-updates.csv.xz: | $(YEAR)/$(MONTH)
	$(psql) -c "COPY (\
		SELECT * FROM rt.trip_updates WHERE timestamp::date = '$(DATE)'::date \
		) TO STDOUT WITH (FORMAT CSV, HEADER true)" | \
	xz -z - > $@

$(YEAR)/$(MONTH)/$(DATE)-bus-messages.csv.xz: | $(YEAR)/$(MONTH)
	$(psql) -c "COPY (\
		SELECT * FROM rt.messages WHERE timestamp::date = '$(DATE)'::date \
		) TO STDOUT WITH (FORMAT CSV, HEADER true)" | \
	xz -z - > $@

$(YEAR)/$(MONTH)/$(DATE)-bus-entity-selectors.csv.xz: | $(YEAR)/$(MONTH)
	$(psql) -c "COPY (\
		SELECT * FROM rt.entity_selectors e JOIN rt.alerts AS a ON (e.alert_id = a.oid) \
		WHERE a.start::date = '$(DATE)'::date \
		) TO STDOUT WITH (FORMAT CSV, HEADER true)" | \
	xz -z - > $@

clean-date:
	$(psql) -c "DELETE FROM rt.vehicle_positions where timestamp::date = '$(DATE)'::date"
	$(psql) -c "DELETE FROM rt.alerts WHERE start::date = '$(DATE)'::date"
	$(psql) -c "DELETE FROM rt.trip_updates where timestamp::date = '$(DATE)'::date"
	$(psql) -c "DELETE FROM rt.messages where timestamp::date = '$(DATE)'::date"
	$(psql) -c "DELETE FROM ONLY rt.entity_selectors e USING rt.alerts a WHERE e.alert_id = a.oid AND a.start::date = '$(DATE)'::date"
	rm -f $(YEAR)/$(MONTH)/$(DATE)-bus-*.csv{.xz,}

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
	$(psql) -f $<

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

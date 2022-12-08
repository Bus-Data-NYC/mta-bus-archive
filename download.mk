shell := /bin/bash

# Download past data

YEAR ?= 2001
MONTH ?= 01
DAY ?= 01

date := $(YEAR)-$(MONTH)-$(DAY)

psql = psql $(psqlflags)
xz = xz --decompress --stdout

archives = $(YEAR)/$(MONTH)/$(date)-bus-positions.csv.xz \
	$(YEAR)/$(MONTH)/$(date)-bus-trip-updates.csv.xz \
	$(YEAR)/$(MONTH)/$(date)-bus-messages.csv.xz \
	$(YEAR)/$(MONTH)/$(date)-bus-alerts.csv.xz

POSITION_COLS ?= timestamp,trip_id,route_id,trip_start_time,trip_start_date,\
	vehicle_id,vehicle_label,vehicle_license_plate,latitude,longitude,bearing,\
	speed,stop_id,stop_status,occupancy_status,congestion_level,progress,\
	block_assigned,dist_along_route,dist_from_stop,mid,stop_sequence

MESSAGE_COLS = oid,timestamp

TRIP_UPDATE_COLS = oid,trip_id,route_id,trip_start_time,trip_start_date,\
	schedule_relationship,vehicle_id,vehicle_label,vehicle_license_plate,timestamp,mid

ALERT_COLS = oid,"start","end",cause,effect,url,header_text,description_text,mid

ARCHIVE ?= s3

ifeq ($(ARCHIVE),s3)
ARCHIVE_URL = https://s3.amazonaws.com/nycbuspositions/$(YEAR)/$(MONTH)
else ifeq ($(ARCHIVE),gcloud)
ARCHIVE_URL = https://storage.googleapis.com/mta-bus-archive/$(YEAR)/$(MONTH)
endif

.PHONY: download load load-bus-positions load-trip-updates load-messages

download: $(archives)

load: load-bus-positions load-trip-updates load-messages

load-bus-positions: $(YEAR)/$(MONTH)/$(date)-bus-positions.csv.xz
	$(xz) $< \
	| $(psql) -c "COPY rt.vehicle_positions ($(POSITION_COLS)) FROM STDIN (FORMAT CSV, HEADER true)"

load-messages: $(YEAR)/$(MONTH)/$(date)-bus-messages.csv.xz
	$(xz) $< \
	| $(psql) -c "COPY rt.messages ($(MESSAGE_COLS)) FROM STDIN (FORMAT CSV, HEADER true)"

load-trip-updates: $(YEAR)/$(MONTH)/$(date)-bus-trip-updates.csv.xz
	$(xz) $< \
	| $(psql) -c "COPY rt.trip_updates ($(TRIP_UPDATE_COLS)) FROM STDIN (FORMAT CSV, HEADER true)"

load-alerts: $(YEAR)/$(MONTH)/$(date)-bus-alerts.csv.xz
	$(xz) $< \
	| $(psql) -c 'COPY rt.alerts ($(ALERT_COLS)) FROM STDIN (FORMAT CSV, HEADER true)'

%.csv: %.csv.xz
	xz -cd $< > $@

$(archives): %.csv.xz: | $(YEAR)/$(MONTH)
	curl -L -o $@ $(ARCHIVE_URL)/$(@F)

$(YEAR)/$(MONTH):
	mkdir -p $@

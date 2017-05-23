shell = bash

PYTHON=python

MYSQLFLAGS =
DATABASE =
MYSQL = mysql $(DATABASE) $(MYSQLFLAGS)

PSQLFLAGS = 
PSQL = psql $(DATABASE) $(PSQLFLAGS)

ARCHIVE = http://data.mytransit.nyc.s3.amazonaws.com/bus_time

DATE = 20161101

.PHONY: mysql-% psql psql-% psql_init mysql_init download mysql_download \
	scrape_mbta scrape_mt

.PRECIOUS: csv/bus_time_%.csv.xz

scrape_mbta scrape_mta: %: 
	$(PYTHON) src/$*.py $(DATABASE)

download: psql-$(DATE)

mysql_download: mysql-$(DATE)

psql-%: csv/bus_time_%.csv
	$(PSQL) -c "COPY positions FROM '$(abspath $<)' DELIMITER ',' HEADER NULL '\N' CSV"

mysql-%: csv/bus_time_%.csv
	$(MYSQL) --local-infile -e "LOAD DATA LOCAL INFILE '$<' \
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

mysql_init: sql/archive_schema.mysql
	$(MYSQL) < $<

init: sql/archive_schema.sql
	$(PSQL) -f $<

src/gtfs_realtime_pb2.py: src/gtfs-realtime.proto
	protoc $< --python_out=.

csv xz: ; mkdir -p $@

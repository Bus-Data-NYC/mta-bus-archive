shell = bash

MYSQLFLAGS =
DATABASE = nycbus
MYSQL = mysql $(DATABASE) $(MYSQLFLAGS)

PSQLFLAGS = 
PSQL = psql $(DATABASE) $(PSQLFLAGS)

ARCHIVE = http://data.mytransit.nyc.s3.amazonaws.com/bus_time

DATE = 20161101

.PHONY: mysql mysql-% psql psql-% psql_init mysql_init

psql: psql-$(DATE)

psql-%: csv/bus_time_%.csv
	$(PSQL) -c "\copy positions FROM '$<' DELIMITER ',' HEADER NULL '\N' CSV"

mysql: mysql-$(DATE)

mysql-%: csv/bus_time_%.csv
	$(MYSQL) --local-infile -e "LOAD DATA LOCAL INFILE '$<' \
		IGNORE INTO TABLE positions \
		FIELDS TERMINATED BY ',' \
		LINES TERMINATED BY '\r\n' \
		IGNORE 1 LINES"

.PRECIOUS: csv/bus_time_%.csv.csv

csv/%.csv: xz/%.csv.xz | csv
	@rm -f $@
	xz -d $<
	mv $(<D)/$(@F) $@

xz/bus_time_%.csv.xz: | xz
	$(eval YEAR=$(shell echo $* | sed 's/\(.\{4\}\).*/\1/'))
	$(eval MONTH=$(shell echo $* | sed 's/.\{4\}\(.\{2\}\).*/\1/'))
	curl -o $@ $(ARCHIVE)/$(YEAR)/$(YEAR)-$(MONTH)/$(@F)

mysql_init: sql/archive_schema.mysql
	$(MYSQL) < $<

psql_init: sql/archive_schema.sql
	$(PSQL) -f $<

clean:
	rm -rf xz csv
	$(MYSQL) -e "DROP TABLE IF EXISTS positions"

csv xz: ; mkdir -p $@

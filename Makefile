shell = bash

MYSQLFLAGS =
DATABASE = nycbus
MYSQL = mysql $(DATABASE) $(MYSQLFLAGS)

ARCHIVE = http://data.mytransit.nyc.s3.amazonaws.com/bus_time

DATE = 20161101

.PHONY: mysql mysql-%

mysql: mysql-$(DATE)

mysql-%: csv/bus_time_%.csv
	$(MYSQL) --local-infile -e "LOAD DATA LOCAL INFILE '$<' \
		IGNORE INTO TABLE positions \
		FIELDS TERMINATED BY ',' \
		LINES TERMINATED BY '\r\n' \
		IGNORE 1 LINES"

csv/%.csv: xz/%.csv.xz | csv
	@rm -f $@
	xz -d $<
	mv $(<D)/$(@F) $@

xz/bus_time_%.csv.xz: | xz
	$(eval YEAR=$(shell echo $* | sed 's/\(.\{4\}\).*/\1/'))
	$(eval MONTH=$(shell echo $* | sed 's/.\{4\}\(.\{2\}\).*/\1/'))
	curl -o $@ $(ARCHIVE)/$(YEAR)/$(YEAR)-$(MONTH)/$(@F)

init: sql/archive_schema.sql
	$(MYSQL) < $<

clean:
	rm -rf xz csv
	$(MYSQL) -e "DROP TABLE IF EXISTS positions"

csv xz: ; mkdir -p $@

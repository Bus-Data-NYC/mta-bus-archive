shell = bash

MYSQLFLAGS =
DATABASE = nycbus
MYSQL = mysql $(DATABASE) $(MYSQLFLAGS)

ARCHIVE = http://data.mytransit.nyc.s3.amazonaws.com/bus_time

csv/%.csv: xz/%.csv.xz | csv
	@rm -f $@
	xz -d $<
	mv $(<D)/$(@F) $@

xz/bus_time_%.csv.xz: | xz
	$(eval YEAR=$(shell echo $* | sed 's/\(.\{4\}\).*/\1/'))
	$(eval MONTH=$(shell echo $* | sed 's/.\{4\}\(.\{2\}\).*/\1/'))
	curl -o $@ $(ARCHIVE)/$(YEAR)/$(YEAR)-$(MONTH)/$(@F)

init: sql/archive_schema.sql
	$(MYSQL) < $@

csv xz: ; mkdir -p $@
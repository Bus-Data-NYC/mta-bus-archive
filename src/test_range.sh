#!/bin/bash
DB_NAME=nycbus
start_date=2016-01-02
num_days=99
for i in `seq 0 $num_days`
do
    date=`date +%Y%m%d -d "${start_date}+${i} days"`
    year=$(date -d "$date" '+%Y')
    yearmonth=$(date -d "$date" '+%Y-%m')
    echo ---
    echo ---
    echo $(date) $date
    wget -q 'http://data.mytransit.nyc.s3.amazonaws.com/bus_time/'$year'/'$yearmonth'/bus_time_'$date'.csv.xz'
    #s3cmd get 's3://nycbusarchive/positions/2015/2015-05/positions_'$date'.csv.xz'
    ./import_archive.sh $DB_NAME 'bus_time_'$date'.csv.xz'
    rm 'bus_time_'$date'.csv.xz'
done


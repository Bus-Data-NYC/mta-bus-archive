#!/bin/bash 

set -e

if [ $# -lt 3 ]; then
    echo Usage: `basename $0` db_name start_date end_date
    exit 1
fi

db_name=$1
date=`date +%Y%m%d -d ${2}`
end_date=`date +%Y%m%d -d ${3}`

while [ $date -le $end_date ]; do
    echo ---
    echo $(date) $date
    year=`date +%Y -d $date`
    year_month=`date +%Y-%m -d $date`
    wget -q http://data.mytransit.nyc.s3.amazonaws.com/bus_time/$year/$year_month/bus_time_$date.csv.xz
    ./import_archive.sh $db_name bus_time_$date.csv.xz
    rm bus_time_$date.csv.xz
    date=`date +%Y%m%d -d "${date}+1 days"`
done


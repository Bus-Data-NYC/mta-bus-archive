# import_archive.sh db_name archive_path
# takes about two minutes

set -e	# exit upon any command error
if [ $# -lt 2 ]; then
        echo Usage: `basename $0` db_name archive_path
        exit 1
fi

DB_NAME=$1
ARCHIVE_PATH=$2

cp $ARCHIVE_PATH tmp_test_bus_time.csv.xz
xz -d tmp_test_bus_time.csv.xz
mysql $DB_NAME < tmp_archive_schema.sql
# Import positions data.  Should get as many warnings as there are lines -- MySQL doesn't recognize the 'Z' character at the end of the ISO 8601 timestamp (it indicates that the timestamp is in UTC time).  Nevertheless, timestamps will be imported correctly.
echo $(date) Importing positions data
mysqlimport --local --fields-terminated-by=, --lines-terminated-by='\r\n' --ignore-lines=1 $DB_NAME tmp_test_bus_time.csv
echo $(date) Done
mysql $DB_NAME -e "SELECT 'all', COUNT(1) FROM tmp_test_bus_time"
rm tmp_test_bus_time.csv
mysql $DB_NAME -e "ALTER TABLE tmp_test_bus_time ADD COLUMN route varchar(255) not null; UPDATE tmp_test_bus_time SET route = SUBSTRING_INDEX(SUBSTRING_INDEX(trip_id, '_', 3), '_', -1)"
# Add positions data to permanent table, using integer trip_index in place of string trip_id.
echo $(date) Importing into permanent table with integer trip id
mysql $DB_NAME -e "DELETE FROM test_positions"
mysql $DB_NAME -e "INSERT IGNORE test_positions SELECT timestamp_utc, vehicle_id, latitude, longitude, bearing, progress, service_date, trip_index, block_assigned, next_stop_id, dist_along_route, dist_from_stop, feed_index FROM tmp_test_bus_time, trips WHERE trips.trip_id = tmp_test_bus_time.trip_id"
#mysql $DB_NAME -e "INSERT bus_time SELECT timestamp_utc, vehicle_id, latitude, longitude, bearing, progress, service_date, trip_index, block_assigned, next_stop_id, dist_along_route, dist_from_stop FROM tmp_positions, feeds, trips WHERE (service_date BETWEEN feed_start_date AND feed_end_date) AND feeds.feed_index = trips.feed_index AND trips.trip_id = tmp_positions.trip_id"
echo $(date) Done
#mysql $DB_NAME -e "DROP TABLE tmp_positions"

mysql $DB_NAME -e "SELECT 'matched', COUNT(1) FROM test_positions"
#mysql $DB_NAME -e "select feed_index, count(1) from test_positions group by feed_index"
mysql $DB_NAME -e "select distinct trip_id from tmp_test_bus_time where trip_id not in (select trip_id from trips)"
#mysql $DB_NAME -e "select distinct route from tmp_positions where trip_id not in (select trip_id from test_trips) and left(route,2)!='BX' order by route"

# select count(1) from bus_time where timestamp_utc between '2015-01-01 00:00:00' and '2015-01-01 23:59:59'
echo $(date) Done


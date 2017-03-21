# import_archive.sh db_name archive_path

set -e	# exit upon any command error
if [ $# -lt 2 ]; then
        echo Usage: `basename $0` db_name archive_path
        exit 1
fi

DB_NAME=$1
ARCHIVE_PATH=$2

cp $ARCHIVE_PATH tmp_bus_time.csv.xz
xz -d tmp_bus_time.csv.xz
mysql $DB_NAME < tmp_archive_schema.sql
# Import positions data.  Should get as many warnings as there are lines -- MySQL doesn't recognize the 'Z' character at the end of the ISO 8601 timestamp (it indicates that the timestamp is in UTC time).  Nevertheless, timestamps will be imported correctly.
echo $(date) $ARCHIVE_PATH
mysqlimport -s --local --fields-terminated-by=, --lines-terminated-by='\r\n' --ignore-lines=1 $DB_NAME tmp_bus_time.csv
mysql $DB_NAME -e "SELECT COUNT(1) AS records FROM tmp_bus_time"
rm tmp_bus_time.csv

# Add positions data to permanent table, using integer trip_index in place of string trip_id.
mysql $DB_NAME -e "INSERT tmp_positions SELECT timestamp_utc, vehicle_id, latitude, longitude, bearing, progress, service_date, trip_index, block_assigned, next_stop_id, dist_along_route, dist_from_stop FROM tmp_bus_time, ref_trips WHERE ref_trips.trip_id = tmp_bus_time.trip_id"
mysql $DB_NAME -e "SELECT COUNT(1) AS records_with_valid_trip FROM tmp_positions"
mysql $DB_NAME -e "INSERT IGNORE bus_time SELECT * FROM tmp_positions"
mysql $DB_NAME -e "DROP TABLE tmp_bus_time"
mysql $DB_NAME -e "DROP TABLE tmp_positions"
#mysql $DB_NAME < find_blackouts.sql	-- make this not yesterday-specific

echo $(date) Completed


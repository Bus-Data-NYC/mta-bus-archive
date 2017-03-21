# import_archive_mta.sh db_name archive_path

set -e	# exit upon any command error
if [ $# -lt 2 ]; then
        echo Usage: `basename $0` db_name archive_path
        exit 1
fi

DB_NAME=$1
ARCHIVE_PATH=$2

cp $ARCHIVE_PATH tmp_positions.csv.xz
xz -d tmp_positions.csv.xz
mysql $DB_NAME < tmp_archive_mta_schema.sql
# Import positions data.  Should get as many warnings as there are lines -- MySQL doesn't understand the 'Z' character at the end of the ISO 8601 timestamp (it indicates that the timestamp is in UTC time).  Nevertheless, timestamps will be imported correctly.
echo $(date) Importing positions data
mysqlimport --local --fields-terminated-by='\t' --lines-terminated-by='\n' --ignore-lines=1 $DB_NAME tmp_positions.csv
echo $(date) Done
mysql $DB_NAME -e "SELECT COUNT(1) FROM tmp_positions"
rm tmp_positions.csv

# Add positions data to permanent table, using integer trip_index in place of string trip_id.
echo $(date) Importing into permanent table with integer trip id
#mysql $DB_NAME -e "INSERT bus_time SELECT timestamp_utc, vehicle_id, latitude, longitude, bearing, progress, service_date, trip_index, block_assigned, next_stop_id, dist_along_route, dist_from_stop FROM tmp_positions, trip_lookup WHERE trip_lookup.trip_id = tmp_positions.trip_id"

# TODO The MTA's Bus Archive includes buses not assigned to a trip/route, which isn't possible through the live API.  Capture.
mysql $DB_NAME -e "INSERT IGNORE bus_time SELECT timestamp_utc, vehicle_id, latitude, longitude, -1.00 bearing, IF(phase='IN_PROGRESS', 0, IF(phase='LAYOVER_DURING', 2, 3)) progress, '0000-00-00' service_date, trip_index, -1 block_assigned, IF(next_stop_id='NULL', NULL, RIGHT(next_stop_id, 6)), IF(dist_along_route='NULL', NULL, ROUND(dist_along_route, 2)), IF(dist_from_stop='NULL', NULL, ROUND(dist_from_stop, 2)) FROM tmp_positions p, trip_lookup WHERE p.trip_id != 'NULL' AND trip_lookup.trip_id = IF(LEFT(p.trip_id,5)='MTABC', MID(p.trip_id,7), MID(p.trip_id,10))"
#mysql $DB_NAME -e "INSERT bus_time SELECT timestamp_utc, vehicle_id, latitude, longitude, bearing, progress, service_date, trip_index, block_assigned, next_stop_id, dist_along_route, dist_from_stop FROM tmp_positions, feeds, trips WHERE (service_date BETWEEN feed_start_date AND feed_end_date) AND feeds.feed_index = trips.feed_index AND trips.trip_id = tmp_positions.trip_id"
echo $(date) Done
mysql $DB_NAME -e "DROP TABLE tmp_positions"

# Assign service dates.
# UPDATE bus_time p, stop_times st SET service_date = IF(TIME_TO_SEC(TIMEDIFF(TIME(CONVERT_TZ(timestamp_utc,'UTC','America/New_York')),departure_time)) < -12*60*60, DATE_SUB(DATE(CONVERT_TZ(timestamp_utc,'UTC','America/New_York')), INTERVAL 1 DAY), IF(TIME_TO_SEC(TIMEDIFF(TIME(CONVERT_TZ(timestamp_utc,'UTC','America/New_York')),departure_time)) > 12*60*60, DATE_ADD(DATE(CONVERT_TZ(timestamp_utc,'UTC','America/New_York')), INTERVAL 1 DAY), DATE(CONVERT_TZ(timestamp_utc,'UTC','America/New_York')))) WHERE bearing < 0 AND (st.trip_index = p.trip_index AND st.stop_id = p.next_stop_id);


#echo $(date) Showing result
#mysql $DB_NAME -e "SELECT DATE(timestamp_utc) date, COUNT(1) FROM bus_time GROUP BY date ORDER BY date DESC LIMIT 1"
#echo $(date) Done


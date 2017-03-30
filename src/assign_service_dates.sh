# assign_service_dates.sh

mysql ts -e "UPDATE bus_time p, stop_times st SET service_date = IF(TIME_TO_SEC(TIMEDIFF(TIME(CONVERT_TZ(timestamp_utc,'UTC','America/New_York')),departure_time)) < -12*60*60, DATE_SUB(DATE(CONVERT_TZ(timestamp_utc,'UTC','America/New_York')), INTERVAL 1 DAY), IF(TIME_TO_SEC(TIMEDIFF(TIME(CONVERT_TZ(timestamp_utc,'UTC','America/New_York')),departure_time)) > 12*60*60, DATE_ADD(DATE(CONVERT_TZ(timestamp_utc,'UTC','America/New_York')), INTERVAL 1 DAY), DATE(CONVERT_TZ(timestamp_utc,'UTC','America/New_York')))) WHERE bearing < 0 AND (st.trip_index = p.trip_index AND st.stop_id = p.next_stop_id)"

echo Done


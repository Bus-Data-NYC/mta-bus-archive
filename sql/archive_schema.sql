-- archive_schema.sql
DROP TABLE IF EXISTS positions;
CREATE TABLE positions (
    timestamp_utc TIMESTAMP NOT NULL,
    vehicle_id TEXT NOT NULL,
    latitude NUMERIC(8, 6) NOT NULL,
    longitude NUMERIC(9, 6) NOT NULL,
    bearing NUMERIC(5, 2),
    progress INTEGER,
    service_date DATE NOT NULL,
    trip_id TEXT NOT NULL,
    block TEXT,
    stop_id TEXT,
    dist_along_route NUMERIC(8, 2),
    dist_from_stop NUMERIC(8, 2),
    CONSTRAINT position_time_bus PRIMARY KEY (timestamp_utc, vehicle_id)
);
CREATE INDEX pos_vid ON positions (vehicle_id);
CREATE INDEX pos_sdate ON positions (service_date);
CREATE INDEX pos_trip_id ON positions (trip_id);
CREATE INDEX pos_time ON positions (timestamp_utc);

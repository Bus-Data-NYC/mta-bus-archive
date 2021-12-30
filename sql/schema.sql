BEGIN;
CREATE SCHEMA rt;

CREATE TYPE rt.alertcause AS ENUM (
    'UNKNOWN_CAUSE',
    'TECHNICAL_PROBLEM',
    'ACCIDENT',
    'HOLIDAY',
    'WEATHER',
    'MAINTENANCE',
    'CONSTRUCTION',
    'POLICE_ACTIVITY',
    'MEDICAL_EMERGENCY'
);
CREATE TYPE rt.alerteffect AS ENUM (
    'NO_SERVICE',
    'REDUCED_SERVICE',
    'SIGNIFICANT_DELAYS',
    'DETOUR',
    'ADDITIONAL_SERVICE',
    'MODIFIED_SERVICE',
    'OTHER_EFFECT',
    'UNKNOWN_EFFECT',
    'STOP_MOVED'
);
CREATE TYPE rt.congestionlevel AS ENUM (
    'UNKNOWN_CONGESTION_LEVEL',
    'RUNNING_SMOOTHLY',
    'STOP_AND_GO',
    'CONGESTION'
);
CREATE TYPE rt.occupancystatus AS ENUM (
    'EMPTY',
    'MANY_SEATS_AVAILABLE',
    'FEW_SEATS_AVAILABLE',
    'STANDING_ROOM_ONLY',
    'CRUSHED_STANDING_ROOM_ONLY',
    'FULL',
    'NOT_ACCEPTING_PASSENGERS'
);
CREATE TYPE rt.stopstatus AS ENUM (
    'INCOMING_AT',
    'STOPPED_AT',
    'IN_TRANSIT_TO'
);
CREATE TYPE rt.stoptimeschedule AS ENUM (
    'SCHEDULED',
    'SKIPPED',
    'NO_DATA'
);
CREATE TYPE rt.tripschedule AS ENUM (
    'SCHEDULED',
    'ADDED',
    'UNSCHEDULED',
    'CANCELED'
);
CREATE TABLE rt.messages (
    oid serial PRIMARY KEY,
    timestamp timestamp with time zone NOT NULL
);
CREATE TABLE rt.alerts (
    oid serial PRIMARY KEY,
    mid bigint,
    start timestamp with time zone,
    "end" timestamp with time zone,
    cause rt.alertcause,
    effect rt.alerteffect,
    url text,
    header_text text,
    description_text text
);
CREATE TABLE rt.entity_selectors (
    oid serial PRIMARY KEY,
    agency_id text,
    route_id text,
    route_type integer,
    stop_id text,
    trip_id text,
    trip_route_id text,
    trip_start_time interval,
    trip_start_date date,
    alert_id integer REFERENCES rt.alerts(oid) ON DELETE CASCADE
);
CREATE TABLE rt.trip_updates (
    oid serial PRIMARY KEY,
    mid bigint,
    trip_id text,
    route_id text,
    trip_start_time interval,
    trip_start_date date,
    schedule_relationship rt.tripschedule,
    vehicle_id text,
    vehicle_label text,
    vehicle_license_plate text,
    "timestamp" timestamp with time zone
);
CREATE TABLE rt.stop_time_updates (
    oid serial PRIMARY KEY,
    stop_sequence integer,
    stop_id text,
    arrival_delay integer,
    arrival_time timestamp with time zone,
    arrival_uncertainty integer,
    departure_delay integer,
    departure_time timestamp with time zone,
    departure_uncertainty integer,
    schedule_relationship rt.stoptimeschedule,
    trip_id text
);
CREATE TABLE rt.vehicle_positions (
    "timestamp" timestamp with time zone NOT NULL,
    trip_id text,
    route_id text,
    mid bigint,
    trip_start_time interval,
    trip_start_date date,
    vehicle_id text NOT NULL,
    vehicle_label text,
    vehicle_license_plate text,
    latitude numeric(9,6),
    longitude numeric(9,6),
    bearing numeric(5,2),
    speed numeric(4,2),
    stop_id text,
    stop_sequence int,
    stop_status rt.stopstatus,
    occupancy_status rt.occupancystatus,
    congestion_level rt.congestionlevel,
    progress int,
    block_assigned text,
    dist_along_route numeric,
    dist_from_stop numeric,
    CONSTRAINT vehicle_positions_pkey PRIMARY KEY ("timestamp", vehicle_id)
);
COMMIT;

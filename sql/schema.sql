CREATE TABLE rt_stoptime_schedule_rel (
    id integer PRIMARY KEY,
    description text
);
CREATE TABLE rt_trip_schedule_rel (
    id integer PRIMARY KEY,
    description text
);
CREATE TABLE rt_alert_cause (
    id integer PRIMARY KEY,
    description text
);
CREATE TABLE rt_alert_effect (
    id integer PRIMARY KEY,
    description text
);
CREATE TABLE rt_congestion_level (
    id integer PRIMARY KEY,
    description text
);
CREATE TABLE rt_occupancy_status (
    id integer PRIMARY KEY,
    description text
);
CREATE TABLE rt_stop_status (
    id integer PRIMARY KEY,
    description text
);
CREATE TABLE rt_alerts (
    oid serial PRIMARY KEY,
    start timestamp with time zone,
    "end" timestamp with time zone,
    cause integer REFERENCES rt_alert_cause(id),
    effect integer REFERENCES rt_alert_effect(id),
    url text,
    header_text text,
    description_text text
);
CREATE TABLE rt_entity_selectors (
    oid serial PRIMARY KEY,
    agency_id text,
    route_id text,
    route_type integer,
    stop_id text,
    trip_id text,
    trip_route_id text,
    trip_start_time interval,
    trip_start_date date,
    alert_id integer REFERENCES rt_alerts(oid)
);
CREATE TABLE rt_stop_time_updates (
    oid serial PRIMARY KEY,
    stop_sequence integer,
    stop_id text,
    arrival_delay integer,
    arrival_time timestamp with time zone,
    arrival_uncertainty integer,
    departure_delay integer,
    departure_time timestamp with time zone,
    departure_uncertainty integer,
    schedule_relationship integer REFERENCES rt_stoptime_schedule_rel(id),
    trip_update_id integer REFERENCES rt_trip_updates(oid)
);

CREATE TABLE rt_trip_updates (
    oid serial PRIMARY KEY,
    trip_id text,
    route_id text,
    trip_start_time interval,
    trip_start_date date,
    schedule_relationship integer,
    vehicle_id text,
    vehicle_label text,
    vehicle_license_plate text,
    "timestamp" timestamp with time zone
);
CREATE TABLE rt_vehicle_positions (
    "timestamp" timestamp with time zone NOT NULL,
    trip_id text,
    route_id text,
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
    stop_status integer,
    occupancy_status integer,
    congestion_level integer,
    progress int,
    block_assigned text,
    dist_along_route numeric,
    dist_from_stop numeric,
    CONSTRAINT rt_vehicle_positions_pkey PRIMARY KEY ("timestamp", vehicle_id)
);

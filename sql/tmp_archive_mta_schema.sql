# tmp_archive_schema.sql

DROP TABLE IF EXISTS tmp_positions;
CREATE TABLE tmp_positions (
	latitude decimal(8,6) not null,
	longitude decimal(9,6) not null,
	timestamp_utc datetime not null,
	vehicle_id smallint(4) unsigned zerofill not null,
	dist_along_route varchar(255) not null,
	direction_id varchar(255) not null,
	phase varchar(255) not null,
	route_id varchar(255) not null,
	trip_id varchar(255) not null,
	dist_from_stop varchar(255) not null,
	next_stop_id varchar(255) not null,
	PRIMARY KEY (timestamp_utc, vehicle_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


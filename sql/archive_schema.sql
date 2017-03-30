# archive_schema.sql

DROP TABLE IF EXISTS bus_time;
CREATE TABLE bus_time (
	timestamp_utc datetime NOT NULL,
	vehicle_id smallint(4) ZEROFILL NOT NULL,
	latitude decimal(8, 6) NOT NULL,
	longitude decimal(9, 6) NOT NULL,
	bearing decimal(5, 2) NOT NULL,
	progress tinyint(1) NOT NULL,
	service_date date NOT NULL,
	trip_index int NOT NULL,
	block_assigned tinyint(1) NOT NULL,
	next_stop_id int(6),
	dist_along_route decimal(8, 2),
	dist_from_stop decimal(8, 2),
	PRIMARY KEY (timestamp_utc, vehicle_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


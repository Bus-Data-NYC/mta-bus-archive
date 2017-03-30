# tmp_archive_schema.sql

DROP TABLE IF EXISTS tmp_bus_time;
CREATE TABLE tmp_bus_time (
	timestamp_utc datetime NOT NULL,
	vehicle_id smallint(4) ZEROFILL NOT NULL,
	latitude decimal(8, 6) NOT NULL,
	longitude decimal(9, 6) NOT NULL,
	bearing decimal(5, 2) NOT NULL,
	progress tinyint(1) NOT NULL,
	service_date date NOT NULL,
	trip_id varchar(255) NOT NULL,
	block_assigned tinyint(1) NOT NULL,
	next_stop_id int(6),
	dist_along_route decimal(8, 2),
	dist_from_stop decimal(8, 2)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS tmp_positions;
CREATE TABLE tmp_positions (
        timestamp_utc datetime NOT NULL,
        vehicle_id smallint(4) ZEROFILL NOT NULL,
        latitude decimal(8, 6) NOT NULL,
        longitude decimal(9, 6) NOT NULL,
        bearing decimal(5, 2) NOT NULL,
        progress tinyint(1) NOT NULL,
        service_date date NOT NULL,
        trip_index int NOT NULL,	-- was trip_index
        block_assigned tinyint(1) NOT NULL,
        next_stop_id int(6),
        dist_along_route decimal(8, 2),
        dist_from_stop decimal(8, 2)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS tmp_test_bus_time;
CREATE TABLE tmp_test_bus_time (
        timestamp_utc datetime NOT NULL,
        vehicle_id smallint(4) ZEROFILL NOT NULL,
        latitude decimal(8, 6) NOT NULL,
        longitude decimal(9, 6) NOT NULL,
        bearing decimal(5, 2) NOT NULL,
        progress tinyint(1) NOT NULL,
        service_date date NOT NULL,
        trip_id varchar(255) NOT NULL,
        block_assigned tinyint(1) NOT NULL,
        next_stop_id int(6),
        dist_along_route decimal(8, 2),
        dist_from_stop decimal(8, 2)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


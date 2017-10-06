#!/usr/bin/env python3

# gtfsrdb.py: load gtfs-realtime data to a database
# recommended to have the (static) GTFS data for the agency you are connecting
# to already loaded.

# Copyright 2017 Transit Center

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#   http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Authors:
# Neil Freeman


import sys
from datetime import datetime
from argparse import ArgumentParser
import logging
import pytz
import gtfs_realtime_pb2
import psycopg2
import requests
from psycopg2.extras import execute_values
import model


INSERT = "INSERT INTO {table} ({columns}) VALUES %s ON CONFLICT DO NOTHING"


def insert_stmt(table, columns):
    return INSERT.format(table=table, columns=', '.join(columns))


def fromtimestamp(timestamp):
    try:
        if timestamp == 0:
            raise TypeError('Ignoring timestamp at epoch')
        return datetime.utcfromtimestamp(timestamp).replace(tzinfo=pytz.UTC)

    except TypeError:
        return None


def get_translated(translation, lang=None):
    '''Get a specific translation from a TranslatedString.'''
    # If we don't find the requested language, return this
    lang = lang or 'EN'

    if len(translation) == 0:
        # If empty, return.
        return None

    for t in translation:
        if t.language == lang:
            return t.text

    # If lang not found, return arbitrary text.
    return translation[0].text


def start_logger(level):
    logger = logging.getLogger()
    logger.setLevel(level)
    loghandler = logging.StreamHandler(sys.stdout)
    logformatter = logging.Formatter(fmt='%(message)s')
    loghandler.setFormatter(logformatter)
    logger.addHandler(loghandler)


def getenum(cls, value, default=None):
    try:
        return cls(value).name
    except ValueError:
        if default:
            return cls(default).name
        else:
            return None


def load_entity(url):
    fm = gtfs_realtime_pb2.FeedMessage()

    with requests.get(url) as r:
        fm.ParseFromString(r.content)

    # Check the feed version
    if fm.header.gtfs_realtime_version != '1.0':
        logging.warning('Warning: feed version has changed. Expected 1.0, found %s', fm.header.gtfs_realtime_version)

    return fm.entity


def parse_vehicle(entity):
    vp = entity.vehicle
    return (
        vp.trip.trip_id,  # trip_id
        vp.trip.route_id,  # route_id
        vp.trip.start_time or None,  # trip_start_time
        vp.trip.start_date,  # trip_start_date
        vp.stop_id,  # stop_id
        getenum(model.StopStatus, vp.current_status),  # stop_status
        vp.vehicle.id,  # vehicle_id
        vp.vehicle.label or None,  # vehicle_label
        vp.vehicle.license_plate or None,  # vehicle_license_plate
        vp.position.latitude,  # latitude
        vp.position.longitude,  # longitude
        vp.position.bearing,  # bearing
        vp.position.speed,  # speed
        getenum(model.OccupancyStatus, vp.occupancy_status),  # occupancy_status
        getenum(model.CongestionLevel, vp.congestion_level, 0),  # congestion_level
        fromtimestamp(vp.timestamp),  # timestamp
    )


def insert_vehicles(cursor, entities):
    cols = (
        'trip_id',
        'route_id',
        'trip_start_time',
        'trip_start_date',
        'stop_id',
        'stop_status',
        'vehicle_id',
        'vehicle_label',
        'vehicle_license_plate',
        'latitude',
        'longitude',
        'bearing',
        'speed',
        'occupancy_status',
        'congestion_level',
        'timestamp',
    )

    sql = insert_stmt('rt_vehicle_positions', cols)
    execute_values(cursor, sql, [parse_vehicle(e) for e in entities])


def parse_alert(entity):
    return (
        fromtimestamp(entity.alert.active_period[0].start),  # start
        fromtimestamp(entity.alert.active_period[0].end),  # end
        getenum(model.AlertCause, entity.alert.cause),  # cause
        getenum(model.AlertEffect, entity.alert.effect),  # effect
        get_translated(entity.alert.url.translation),  # url
        get_translated(entity.alert.header_text.translation),  # header_text
        get_translated(entity.alert.description_text.translation),  # description_text
    )


def parse_informed_entity(entity):
    return (
        entity.agency_id,  # agency_id
        entity.route_id,  # route_id
        entity.route_type,  # route_type
        entity.stop_id,  # stop_id
        entity.trip.trip_id,  # trip_id
        entity.trip.route_id,  # trip_route_id
        entity.trip.start_time or None,  # trip_start_time
        entity.trip.start_date or None  # trip_start_date
    )


def insert_alerts(cursor, entities):
    alert_cols = (
        'start',
        '"end"',
        'cause',
        'effect',
        'url',
        'header_text',
        'description_text'
    )
    entity_cols = (
        'agency_id',
        'route_id',
        'route_type',
        'stop_id',
        'trip_id',
        'trip_route_id',
        'trip_start_time',
        'trip_start_date',
    )
    sql = insert_stmt('rt_alerts', alert_cols)
    execute_values(cursor, sql, [parse_alert(e) for e in entities])

    sql = insert_stmt('rt_entity_selectors', entity_cols)
    for entity in entities:
        execute_values(cursor, sql, [parse_informed_entity(ie) for ie in entity.alert.informed_entity])


def parse_trip(entity):
    return (
        entity.trip_update.trip.trip_id,  # trip_id
        entity.trip_update.trip.route_id,  # route_id
        entity.trip_update.trip.start_time or None,  # trip_start_time
        entity.trip_update.trip.start_date or None,  # trip_start_date
        getenum(model.TripSchedule, entity.trip_update.trip.schedule_relationship),  # schedule_relationship
        entity.trip_update.vehicle.id,  # vehicle_id
        entity.trip_update.vehicle.label,  # vehicle_label
        entity.trip_update.vehicle.license_plate,  # vehicle_license_plate
        fromtimestamp(entity.trip_update.timestamp)  # timestamp
    )


def parse_stoptimeupdate(entity):
    return (
        entity.stop_sequence,  # stop_sequence
        entity.stop_id,  # stop_id
        entity.arrival.delay or None,  # arrival_delay
        fromtimestamp(entity.arrival.time),  # arrival_time
        entity.arrival.uncertainty or None,  # arrival_uncertainty
        entity.departure.delay or None,  # departure_delay
        fromtimestamp(entity.departure.time),  # departure_time
        entity.departure.uncertainty or None,  # departure_uncertainty
        getenum(model.StopTimeSchedule, entity.schedule_relationship, 2),  # schedule_relationship
    )


def insert_trips(cursor, entities):
    cols = (
        'trip_id',
        'route_id',
        'trip_start_time',
        'trip_start_date',
        'schedule_relationship',
        'vehicle_id',
        'vehicle_label',
        'vehicle_license_plate',
        'timestamp',
    )
    stu_cols = (
        'stop_sequence',
        'stop_id',
        'arrival_delay',
        'arrival_time',
        'arrival_uncertainty',
        'departure_delay',
        'departure_time',
        'departure_uncertainty',
        'schedule_relationship',
    )
    sql = insert_stmt('rt_trip_updates', cols)
    execute_values(cursor, sql, [parse_trip(e) for e in entities])

    sql = insert_stmt('rt_stop_time_updates', stu_cols)
    for entity in entities:
        execute_values(cursor, sql, [parse_stoptimeupdate(e) for e in entity.trip_update.stop_time_update])


def main():
    parser = ArgumentParser()
    parser.add_argument('-t', '--trip-updates', dest='trips',
                        help='The trip updates URL', metavar='URL')
    parser.add_argument('-a', '--alerts', default=None, metavar='URL',
                        help='The alerts URL')
    parser.add_argument('-p', '--vehicle-positions', dest='vehicles',
                        help='The vehicle positions URL', metavar='URL')
    parser.add_argument('-d', '--database', default=None,
                        help='Database connection string')

    args = parser.parse_args()

    level = logging.WARNING
    # Start logging.
    start_logger(level)

    if args.database is None:
        logging.error('No database specified!')
        return

    try:
        with psycopg2.connect(args.database) as conn:
            urls = (args.alerts, args.trips, args.vehicles)
            inserters = (insert_alerts, insert_trips, insert_vehicles)

            if urls == (None, None, None):
                logging.error('No trip updates, alerts, or vehicle positions URLs were specified')
                return

        with conn.cursor() as cursor:
            for url, insert in zip(urls, inserters):
                if url is not None:
                    logging.debug('Getting %s', url)
                    entities = load_entity(url)
                    insert(cursor, entities)
                    conn.commit()

    except psycopg2.ProgrammingError as e:
        logging.error("database error:")
        logging.error(str(e).strip())
        sys.exit(1)


if __name__ == '__main__':
    main()

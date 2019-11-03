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

import os
import sys
import getpass
from datetime import datetime
from argparse import ArgumentParser
import logging
import pytz
import psycopg2
from psycopg2.extras import execute_values
import google.protobuf
import nyct_subway_pb2
import gtfs_realtime_pb2
import model


INSERT = "INSERT INTO {table} ({columns}) VALUES %s ON CONFLICT DO NOTHING"


def insert_stmt(table, columns):
    return INSERT.format(table=table, columns=', '.join(columns)).strip()


def insert_stmt_returning(table, columns, returning):
    placeholders = '(' + ('%s, ' * len(columns)).strip(' ,') + ')'
    return (
        INSERT.format(table=table, columns=', '.join(columns)) % placeholders
    ) + ' RETURNING ' + returning


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

    if not translation:
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
        return None


def load_message(filename):
    fm = gtfs_realtime_pb2.FeedMessage()

    with open(filename, 'rb') as f:
        try:
            fm.ParseFromString(f.read())
        except (RuntimeWarning, google.protobuf.message.DecodeError) as e:
            logging.error('ERROR: %s in %s', e, filename)
            return fm, e

    # Check the feed version
    if fm.entity and fm.header.gtfs_realtime_version != '1.0':
        logging.warning('WARNING: feed version has changed. Expected 1.0, found %s',
                        fm.header.gtfs_realtime_version)
        logging.warning('file: %s', filename)

    return fm, None


def parse_vehicle(entity):
    vp = entity.vehicle
    nyct_trip_descriptor = vp.trip.Extensions[nyct_subway_pb2.nyct_trip_descriptor]
    return [
        vp.trip.trip_id or None,  # trip_id
        vp.trip.route_id or None,  # route_id
        vp.trip.start_time or None,  # trip_start_time
        vp.trip.start_date or None,  # trip_start_date
        vp.stop_id or None,  # stop_id
        vp.current_stop_sequence or None,  # stop_sequence
        getenum(model.StopStatus, vp.current_status) or None,  # stop_status
        vp.vehicle.id or nyct_trip_descriptor.train_id or None,  # vehicle_id
        vp.vehicle.label or None,  # vehicle_label
        vp.vehicle.license_plate or None,  # vehicle_license_plate
        vp.position.latitude or None,  # latitude
        vp.position.longitude or None,  # longitude
        vp.position.bearing or None,  # bearing
        vp.position.speed or None,  # speed
        getenum(model.OccupancyStatus, vp.occupancy_status),  # occupancy_status
        getenum(model.CongestionLevel, vp.congestion_level, 0),  # congestion_level
        fromtimestamp(vp.timestamp),  # timestamp
    ]


def insert_vehicles(cursor, messageid, entities):
    cols = [
        'mid',
        'trip_id',
        'route_id',
        'trip_start_time',
        'trip_start_date',
        'stop_id',
        'stop_sequence',
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
    ]

    sql = insert_stmt('rt.vehicle_positions', cols)
    parsed = ([messageid] + parse_vehicle(e) for e in entities if e.vehicle.ByteSize())
    execute_values(cursor, sql, list(parsed))


def parse_alert(alert):
    try:
        return [
            fromtimestamp(alert.active_period[0].start),  # start
            fromtimestamp(alert.active_period[0].end),  # end
            getenum(model.AlertCause, alert.cause),  # cause
            getenum(model.AlertEffect, alert.effect),  # effect
            get_translated(alert.url.translation),  # url
            get_translated(alert.header_text.translation),  # header_text
            get_translated(alert.description_text.translation),  # description_text
        ]
    except IndexError:
        return []


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


def insert_alerts(cursor, messageid, entities):
    alert_cols = (
        'mid',
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
        'alert_id'
    )

    alerts = [e.alert for e in entities if e.alert.ByteSize()]
    if not alerts:
        return

    alertsql = insert_stmt_returning('rt.alerts', alert_cols, 'oid')
    selectorsql = insert_stmt('rt.entity_selectors', entity_cols)

    for alert in alerts:
        parsed = parse_alert(alert)
        if not parsed:
            continue
        cursor.execute(alertsql, [messageid] + parsed)
        oid = cursor.fetchone()[0]

        selectors = [parse_informed_entity(e) + [oid] for e in alert.informed_entity]
        if selectors:
            execute_values(cursor, selectorsql, selectors)


def parse_trip(trip_update):
    return [
        trip_update.trip.trip_id,  # trip_id
        trip_update.trip.route_id,  # route_id
        trip_update.trip.start_time or None,  # trip_start_time
        trip_update.trip.start_date or None,  # trip_start_date
        getenum(model.TripSchedule, trip_update.trip.schedule_relationship),  # schedule_relationship
        trip_update.vehicle.id,  # vehicle_id
        trip_update.vehicle.label,  # vehicle_label
        trip_update.vehicle.license_plate,  # vehicle_license_plate
        fromtimestamp(trip_update.timestamp)  # timestamp
    ]


def parse_stoptimeupdate(entity):
    return [
        entity.stop_sequence,  # stop_sequence
        entity.stop_id,  # stop_id
        entity.arrival.delay or None,  # arrival_delay
        fromtimestamp(entity.arrival.time),  # arrival_time
        entity.arrival.uncertainty or None,  # arrival_uncertainty
        entity.departure.delay or None,  # departure_delay
        fromtimestamp(entity.departure.time),  # departure_time
        entity.departure.uncertainty or None,  # departure_uncertainty
        getenum(model.StopTimeSchedule, entity.schedule_relationship, 2),  # schedule_relationship
    ]


def insert_trips(cursor, messageid, entities):
    cols = (
        'mid',
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
        'trip_update_id'
    )
    trips = [e.trip_update for e in entities if e.trip_update.ByteSize()]
    if not trips:
        return

    tripsql = insert_stmt_returning('rt.trip_updates', cols, 'oid')
    sql = insert_stmt('rt.stop_time_updates', stu_cols)

    for trip in trips:
        cursor.execute(tripsql, [messageid] + parse_trip(trip))
        oid = cursor.fetchone()[0]

        stus = [parse_stoptimeupdate(stu) + [oid] for stu in trip.stop_time_update]
        if stus:
            execute_values(cursor, sql, stus)


def parse_replacement_period(entity):
    return [entity.route_id, fromtimestamp(entity.replacement_period.end)]


def insert_header(cursor, message):
    sql = insert_stmt_returning('rt.messages', ['"timestamp"'], 'oid')
    execute_values(cursor, sql, [(fromtimestamp(message.header.timestamp),)])
    messageid = cursor.fetchone()[0]
    nyct_feed_header = message.header.Extensions[nyct_subway_pb2.nyct_feed_header]
    replacement_periods = [parse_replacement_period(e) + [messageid]
                           for e in nyct_feed_header.trip_replacement_period]
    sql = insert_stmt('rt.replacement_periods', ['route_id', '"end"', 'mid'])
    execute_values(cursor, sql, replacement_periods)

    return messageid

def insert_error(cursor, filename, error):
    sql = insert_stmt("rt.failures", ('filename', 'error'))
    execute_values(cursor, sql, [[filename, error]])

def connection_params():
    pg = {
        'PGUSER': 'user',
        'PGHOST': 'host',
        'PGPORT': 'port',
        'PGPASSWORD': 'password',
        'PGPASSFILE': 'passfile',
    }
    params = {'dbname': os.environ.get('PGDATABASE', getpass.getuser())}
    params.update({v: os.environ[k] for k, v in pg.items() if k in os.environ})
    return params


def main():
    desc = """
        Insert GTFS-rt data into a PostgreSQL database.
        By default, a local connection to your user's database will be created.
        To specify other connection parameters, use the standard PG* environment variables.
    """
    parser = ArgumentParser(description=desc)
    parser.add_argument('file', help='GTFS-RT file', metavar='gtfs-rt-file')
    args = parser.parse_args()

    level = logging.WARNING
    # Start logging.
    start_logger(level)

    inserters = (
        insert_alerts,
        insert_trips,
        insert_vehicles,
    )
    try:
        with psycopg2.connect(**connection_params()) as conn:
            with conn.cursor() as cursor:
                logging.debug('Opening %s', args.file)
                message, error = load_message(args.file)

                if error or not message.ByteSize():
                    errormessage = getattr(error, 'message', 'ByteSize is 0')
                    insert_error(cursor, args.file, errormessage)
                    return

                # first insert the header
                messageid = insert_header(cursor, message)

                for insert in inserters:
                    insert(cursor, messageid, message.entity)
                    conn.commit()

    except psycopg2.ProgrammingError as e:
        logging.error("database error: %s", str(e).strip())
        sys.exit(1)


if __name__ == '__main__':
    main()

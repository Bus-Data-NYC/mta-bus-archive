#!/usr/bin/env python3

# gtfsrdb.py: load gtfs-realtime data to a database
# recommended to have the (static) GTFS data for the agency you are connecting
# to already loaded.

# Copyright 2011, 2013 Matt Conway

# Copyright 2011, 2013 Neil Freeman

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
# Based on code by:
# Matt Conway
# Jorge Adorno

import sys
from datetime import datetime
from argparse import ArgumentParser
import logging
from urllib.request import urlopen
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import pytz
import gtfs_realtime_pb2
import model


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
        return cls(value)
    except ValueError:
        if default:
            return cls(default)
        else:
            return None


def load_entity(url):
    fm = gtfs_realtime_pb2.FeedMessage()

    with urlopen(url) as r:
        fm.ParseFromString(r.read())

    # Check the feed version
    if fm.header.gtfs_realtime_version != '1.0':
        logging.warning('Warning: feed version has changed. Expected 1.0, found %s', fm.header.gtfs_realtime_version)

    return fm.entity


def parse_vehicle(entity):
    vp = entity.vehicle
    return (model.VehiclePosition(
        trip_id=vp.trip.trip_id,
        route_id=vp.trip.route_id,
        trip_start_time=vp.trip.start_time or None,
        trip_start_date=vp.trip.start_date,
        stop_id=vp.stop_id,
        stop_status=getenum(model.StopStatus, vp.current_status),
        vehicle_id=vp.vehicle.id,
        vehicle_label=vp.vehicle.label or None,
        vehicle_license_plate=vp.vehicle.license_plate or None,
        latitude=vp.position.latitude,
        longitude=vp.position.longitude,
        bearing=vp.position.bearing,
        speed=vp.position.speed,
        occupancy_status=getenum(model.OccupancyStatus, vp.occupancy_status),
        congestion_level=getenum(model.CongestionLevel, vp.congestion_level, 0),
        timestamp=fromtimestamp(vp.timestamp),
    ),)


def parse_alert(entity):
    alert = model.Alert(
        start=fromtimestamp(entity.alert.active_period[0].start),
        end=fromtimestamp(entity.alert.active_period[0].end),
        cause=getenum(model.AlertCause, entity.alert.cause),
        effect=getenum(model.AlertEffect, entity.alert.effect),
        url=get_translated(entity.alert.url.translation),
        header_text=get_translated(entity.alert.header_text.translation),
        description_text=get_translated(entity.alert.description_text.translation),
    )
    rows = [alert]
    for informed_entity in entity.alert.informed_entity:
        ie = model.EntitySelector(
            agency_id=informed_entity.agency_id,
            route_id=informed_entity.route_id,
            route_type=informed_entity.route_type,
            stop_id=informed_entity.stop_id,
            trip_id=informed_entity.trip.trip_id,
            trip_route_id=informed_entity.trip.route_id,
            trip_start_time=informed_entity.trip.start_time or None,
            trip_start_date=informed_entity.trip.start_date or None
        )

        rows.append(ie)
        alert.InformedEntities.append(ie)

    return rows


def parse_trip(entity):
    trip = model.TripUpdate(
        trip_id=entity.trip_update.trip.trip_id,
        route_id=entity.trip_update.trip.route_id,
        trip_start_time=entity.trip_update.trip.start_time or None,
        trip_start_date=entity.trip_update.trip.start_date or None,
        schedule_relationship=getenum(model.TripSchedule, entity.trip_update.trip.schedule_relationship),
        vehicle_id=entity.trip_update.vehicle.id,
        vehicle_label=entity.trip_update.vehicle.label,
        vehicle_license_plate=entity.trip_update.vehicle.license_plate,
        timestamp=fromtimestamp(entity.trip_update.timestamp))

    rows = [trip]

    for stu in entity.trip_update.stop_time_update:
        dbstu = model.StopTimeUpdate(
            stop_sequence=stu.stop_sequence,
            stop_id=stu.stop_id,
            arrival_delay=stu.arrival.delay or None,
            arrival_time=fromtimestamp(stu.arrival.time),
            arrival_uncertainty=stu.arrival.uncertainty or None,
            departure_delay=stu.departure.delay or None,
            departure_time=fromtimestamp(stu.departure.time),
            departure_uncertainty=stu.departure.uncertainty or None,
            schedule_relationship=getenum(model.StopTimeSchedule, stu.schedule_relationship, 2),
        )
        trip.StopTimeUpdates.append(dbstu)
        rows.append(dbstu)

    return rows


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
    parser.add_argument('-c', '--create-tables', default=False, dest='create',
                        action='store_true', help="Create tables if they aren't found")

    args = parser.parse_args()

    level = logging.WARNING
    # Start logging.
    start_logger(level)

    if args.database is None:
        logging.error('No database specified!')
        return

    try:
        engine = create_engine(args.database)
        db_session = sessionmaker(bind=engine)()

    except Exception as e:
        logging.error('Unable to connect to database (%s)', args.database)
        logging.debug(e)
        return

    if args.create:
        # Create database tables and exit.
        model.Base.metadata.bind = engine
        model.Base.metadata.create_all()
        return

    urls = (args.alerts, args.trips, args.vehicles)
    parsers = (parse_alert, parse_trip, parse_vehicle)

    if urls == (None, None, None):
        logging.error('No trip updates, alerts, or vehicle positions URLs were specified')
        return

    for url, parse in zip(urls, parsers):
        if url is not None:
            logging.debug('Getting %s', url)
            entities = load_entity(url)

            for entity in entities:
                rows = parse(entity)
                db_session.add_all(rows)

            db_session.commit()


if __name__ == '__main__':
    main()

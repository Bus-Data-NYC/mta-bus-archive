#!/usr/bin/env python3
import sys
import os
from datetime import datetime
import requests
import psycopg2
import gtfs_realtime_pb2


ENDPOINT = 'http://developer.mbta.com/lib/GTRTFS/Alerts/VehiclePositions.pb'
INSERT = """INSERT INTO positions (
        timestamp_utc, service_date, vehicle_id, trip_id,
        progress, bearing, longitude, latitude, stop_id)
    VALUES (
        %(timestamp)s, %(service_date)s, %(vehicle)s, %(trip)s,
        %(progress)s, %(bearing)s, %(lon)s, %(lat)s, %(stop)s
    )"""

def extract(vehicle):
    return {
        'timestamp': datetime.utcfromtimestamp(vehicle.timestamp),
        'vehicle': vehicle.vehicle.id,
        'lat': vehicle.position.latitude,
        'lon': vehicle.position.longitude,
        'bearing': vehicle.position.bearing,
        'service_date': vehicle.trip.start_date,
        'trip': vehicle.trip.trip_id,
        'stop': vehicle.stop_id,
        'progress': vehicle.current_status
    }

def chunks(lis, n):
    n = max(1, n)
    return (lis[i:i+n] for i in range(0, len(lis), n))

def run(db, key):
    request = requests.get(ENDPOINT, params={'key': key})
    feed = gtfs_realtime_pb2.FeedMessage()
    feed.ParseFromString(request.raw.read())

    with psycopg2.connect('dbname=' + db) as conn:
        with conn.cursor() as c:
            for chunk in chunks(feed.entity, 5000):
                c.executemany(INSERT, [extract(x.vehicle) for x in chunk])
        conn.commit()


def main():
    try:
        key = os.environ['MBTA_KEY']
        db = sys.argv[1]
    except (IndexError, KeyError):
        print('usage: python', sys.argv[0], 'DATABASE')
        print('   scrapes bus positions into a Postgres database')
        print('   set MTA_KEY environment variable with MTA api key')

    run(db, key)


if __name__ == '__main__':
    main()

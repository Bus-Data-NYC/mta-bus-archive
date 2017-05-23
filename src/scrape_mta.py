#!/usr/bin/env python3
import sys
import os
from datetime import datetime
from pytz import utc
import requests
import psycopg2

'''
simplified version of api response
{
    'MonitoredVehicleJourney': {
        'VehicleLocation': {
            'Latitude': 40.783089,
            'Longitude': -73.845863
        },
        'FramedVehicleJourneyRef': {
            'DatedVehicleJourneyRef': 'MTA NYCT_CS_B7-Weekday-SDon-098400_Q20_14',
            'DataFrameRef': '2017-05-04'
        },
        'VehicleRef': 'MTA NYCT_7424',
        'PublishedLineName': 'Q20A',
    },
    'RecordedAtTime': '2017-05-04T17:41:52.319-04:00'
}
'''
SIRI = 'http://api.prod.obanyc.com/api/siri/vehicle-monitoring.json'
STRPTIME = "%Y-%m-%dT%H:%M:%S.%f%z"
INSERT = """INSERT INTO positions
    (timestamp_utc, service_date, vehicle_id, trip_id,
        progress, bearing, longitude, latitude,
        next_stop_id, dist_along_route, dist_from_stop)
    VALUES
    (
        %(timestamp)s, %(service_date)s, %(vehicle)s, %(trip)s,
        %(progress)s, %(bearing)s, %(lon)s, %(lat)s,
        %(stop)s, %(dist_along)s, %(dist_from)s)"""

PROGRESS_LUT = {
    'normalProgress': 0,
    'noProgress': 1,
    'layover': 2,
    'prevTrip': 3,
}

def chunks(lis, n):
    n = max(1, n)
    return (lis[i:i+n] for i in range(0, len(lis), n))


def extract(position):
    row = {}
    journey = position['MonitoredVehicleJourney']

    # "2017-05-04T17:41:52.319-04:00"
    timestamp = position["RecordedAtTime"].replace('-04:00', '-0400').replace('-05:00', '-0500')
    row['timestamp'] = datetime.strptime(timestamp, STRPTIME).astimezone(utc)

    # "2017-05-04"
    row['service_date'] = journey["FramedVehicleJourneyRef"]["DataFrameRef"]
    # "MTA NYCT_7424"
    row['vehicle'] = journey["VehicleRef"].replace('MTABC_', '').replace('MTA NYCT_', '')
    # "MTA NYCT_CS_B7-Weekday-SDon-098400_Q20_14"
    row['trip'] = journey["FramedVehicleJourneyRef"]["DatedVehicleJourneyRef"]

    try:
        # "MTA_101327"
        row['stop'] = journey["MonitoredCall"]["StopPointRef"].replace('MTA_', '')
    except KeyError:
        row['stop'] = None

    try:
        # "Bearing": 89.60564
        row['bearing'] = journey["Bearing"]
    except KeyError:
        row['bearing'] = None

    try:
        # "ProgressRate": "normalProgress"
        row['progress'] = PROGRESS_LUT.get(journey["ProgressRate"])

    except KeyError:
        row['progress'] = None

    try:
        # -73.845863
        row['lon'] = journey["VehicleLocation"]["Longitude"]
        # 40.783089
        row['lat'] = journey["VehicleLocation"]["Latitude"]
    except KeyError:
        row['lat'], row['lon'] = None, None

    try:
        distances = journey["MonitoredCall"]["Extensions"]["Distances"]
        row['dist_along'] = distances["CallDistanceAlongRoute"]
        row['dist_from'] = distances["DistanceFromCall"]
    except KeyError:
        row['dist_from'], row['dist_along'] = None, None

    # try:
    #     row['block'] = journey["BlockRef"]
    # except KeyError:
    #     row['block'] = None

    return row


def run(db, key):
    r = requests.get(SIRI, params={'key': key})
    result = r.json()
    activity = result['Siri']['ServiceDelivery']['VehicleMonitoringDelivery'][0]['VehicleActivity']

    with psycopg2.connect('dbname=' + db) as conn:
        with conn.cursor() as c:
            for chunk in chunks(activity, 5000):
                c.executemany(INSERT, [extract(position) for position in chunk])
        conn.commit()


def main():
    try:
        key = os.environ['MTA_KEY']
        db = sys.argv[1]
    except (IndexError, KeyError):
        print('usage: python', sys.argv[0], 'DATABASE')
        print('   scrapes bus positions into a Postgres database')
        print('   set MTA_KEY environment variable with MTA api key')

    run(db, key)

if __name__ == '__main__':
    main()

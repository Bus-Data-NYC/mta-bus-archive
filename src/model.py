# gtfsrdb.py: load gtfs-realtime data to a database
# recommended to have the (static) GTFS data for the agency you are connecting
# to already loaded.

# Copyright 2011 Matt Conway

# Licensed under the Apache License, Version 2.0 (the "License")
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at


# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Authors:
# Matt Conway: main code

import enum
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, ForeignKey, Enum, Integer, TEXT, Date, TIMESTAMP, NUMERIC, Interval
from sqlalchemy.orm import relationship

Base = declarative_base()


class OccupancyStatus(enum.Enum):
    EMPTY = 0
    MANY_SEATS_AVAILABLE = 1
    FEW_SEATS_AVAILABLE = 2
    STANDING_ROOM_ONLY = 3
    CRUSHED_STANDING_ROOM_ONLY = 4
    FULL = 5
    NOT_ACCEPTING_PASSENGERS = 6


class CongestionLevel(enum.Enum):
    UNKNOWN_CONGESTION_LEVEL = 0
    RUNNING_SMOOTHLY = 1
    STOP_AND_GO = 2
    CONGESTION = 3


class StopTimeSchedule(enum.Enum):
    SCHEDULED = 0
    SKIPPED = 1
    NO_DATA = 2


class TripSchedule(enum.Enum):
    SCHEDULED = 0
    ADDED = 1
    UNSCHEDULED = 2
    CANCELED = 3


class AlertCause(enum.Enum):
    UNKNOWN_CAUSE = 1
    TECHNICAL_PROBLEM = 3
    ACCIDENT = 6
    HOLIDAY = 7
    WEATHER = 8
    MAINTENANCE = 9
    CONSTRUCTION = 10
    POLICE_ACTIVITY = 11
    MEDICAL_EMERGENCY = 12


class AlertEffect(enum.Enum):
    NO_SERVICE = 1
    REDUCED_SERVICE = 2
    SIGNIFICANT_DELAYS = 3
    DETOUR = 4
    ADDITIONAL_SERVICE = 5
    MODIFIED_SERVICE = 6
    OTHER_EFFECT = 7
    UNKNOWN_EFFECT = 8
    STOP_MOVED = 9


class StopStatus(enum.Enum):
    INCOMING_AT = 0
    STOPPED_AT = 1
    IN_TRANSIT_TO = 2


class TripUpdate(Base):
    __tablename__ = 'rt_trip_updates'

    oid = Column(Integer, primary_key=True)

    # This replaces the TripDescriptor message
    trip_id = Column(TEXT)
    route_id = Column(TEXT)
    trip_start_time = Column(Interval(native=True), default=None)
    trip_start_date = Column(Date)

    # Put in the string value not the enum
    schedule_relationship = Column(Enum(TripSchedule))

    # Collapsed VehicleDescriptor
    vehicle_id = Column(TEXT)
    vehicle_label = Column(TEXT)
    vehicle_license_plate = Column(TEXT)

    # moved from the header, and reformatted as datetime
    timestamp = Column(TIMESTAMP(True))

    StopTimeUpdates = relationship('StopTimeUpdate', backref='TripUpdate')


class StopTimeUpdate(Base):
    __tablename__ = 'rt_stop_time_updates'

    oid = Column(Integer, primary_key=True)

    stop_sequence = Column(Integer)
    stop_id = Column(TEXT)

    # Collapsed StopTimeEvent
    arrival_delay = Column(Integer)
    arrival_time = Column(TIMESTAMP(True))
    arrival_uncertainty = Column(Integer)

    # Collapsed StopTimeEvent
    departure_delay = Column(Integer)
    departure_time = Column(TIMESTAMP(True))
    departure_uncertainty = Column(Integer)

    schedule_relationship = Column(Enum(StopTimeSchedule), default='NO_DATA')

    # Link it to the TripUpdate
    # The .TripUpdate is done by the backref in TripUpdate
    trip_update_id = Column(Integer, ForeignKey('rt_trip_updates.oid'))


class Alert(Base):
    __tablename__ = 'rt_alerts'

    oid = Column(Integer, primary_key=True)

    start = Column(TIMESTAMP(True))
    end = Column(TIMESTAMP(True))

    cause = Column(Enum(AlertCause), default='UNKNOWN_CAUSE')
    effect = Column(Enum(AlertEffect), default='UNKNOWN_EFFECT')

    url = Column(TEXT)
    header_text = Column(TEXT)
    description_text = Column(TEXT)

    InformedEntities = relationship('EntitySelector', backref='Alert')


class EntitySelector(Base):
    __tablename__ = 'rt_entity_selectors'

    oid = Column(Integer, primary_key=True)

    agency_id = Column(TEXT)
    route_id = Column(TEXT)
    route_type = Column(Integer)
    stop_id = Column(TEXT)

    # Collapsed TripDescriptor
    trip_id = Column(TEXT)
    trip_route_id = Column(TEXT)
    trip_start_time = Column(Interval(native=True))
    trip_start_date = Column(Date)

    alert_id = Column(Integer, ForeignKey('rt_alerts.oid'))


class VehiclePosition(Base):
    __tablename__ = 'rt_vehicle_positions'

    timestamp = Column(TIMESTAMP(True), primary_key=True)

    # This replaces the TripDescriptor message
    trip_id = Column(TEXT)
    route_id = Column(TEXT)
    trip_start_time = Column(Interval(native=True))
    trip_start_date = Column(Date)

    # Collapsed VehicleDescriptor
    vehicle_id = Column(TEXT, primary_key=True)
    vehicle_label = Column(TEXT)
    vehicle_license_plate = Column(TEXT)

    # Collapsed Position
    latitude = Column(NUMERIC(9, 6))
    longitude = Column(NUMERIC(9, 6))
    bearing = Column(NUMERIC(5, 2))
    speed = Column(NUMERIC(4, 2))

    stop_id = Column(TEXT)
    stop_status = Column(Enum(StopStatus))

    occupancy_status = Column(Enum(OccupancyStatus))
    congestion_level = Column(Enum(CongestionLevel), default='UNKNOWN_CONGESTION_LEVEL')

    # Non-standard columns, included for SIRI data
    progress = Column(Integer)
    block_assigned = Column(TEXT)
    dist_along_route = Column(NUMERIC)
    dist_from_stop = Column(NUMERIC)

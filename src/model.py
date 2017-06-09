# gtfsrdb.py: load gtfs-realtime data to a database
# recommended to have the (static) GTFS data for the agency you are connecting
# to already loaded.

# Copyright 2011 Matt Conway

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
# Matt Conway: main code

from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, ForeignKey, Integer, TEXT, DATE, TIMESTAMP, Float, Interval
from sqlalchemy.orm import relationship

Base = declarative_base()

LUT_DATA = {
    'rt_occupancy_status': (
        (0, 'empty'),
        (1, 'many seats available'),
        (2, 'few seats available'),
        (3, 'standing room only'),
        (4, 'crushed standing room only'),
        (5, 'full'),
        (6, 'not accepting passengers')
    ),
    'rt_congestion_level': (
        (0, 'unknown congestion level'),
        (1, 'running smoothly'),
        (2, 'stop and go'),
        (3, 'congestion'),
        (4, 'severe congestion')
    ),
    'rt_stoptime_schedule_rel': (
        (0, 'scheduled'),
        (1, 'skipped'),
        (2, 'no data'),
    ),
    'rt_trip_schedule_rel': (
        (0, 'scheduled'),
        (1, 'added'),
        (2, 'unscheduled'),
        (3, 'canceled'),
    ),
    'rt_alert_cause': (
        (1, 'unknown cause'),
        (2, 'other cause'),  # Not machine-representable.
        (3, 'technical problem'),
        (4, 'strike'),  # Public transit agency employees stopped working.
        (5, 'demonstration'),  # People are blocking the streets.
        (6, 'accident'),
        (7, 'holiday'),
        (8, 'weather'),
        (9, 'maintenance'),
        (10, 'construction'),
        (11, 'police activity'),
        (12, 'medical emergency'),
    ),
    'rt_alert_effect': (
        (1, 'no service'),
        (2, 'reduced service'),
        (3, 'significant delays'),
        (4, 'detour'),
        (5, 'additional service'),
        (6, 'modified service'),
        (7, 'other effect'),
        (8, 'unknown effect'),
        (9, 'stop moved'),
    ),
    'rt_stop_status': (
        (0, 'incoming at'),
        (1, 'stopped at'),
        (2, 'in transit to'),
    ),
}


class AlertCause(Base):
    __tablename__ = 'rt_alert_cause'

    id = Column(Integer, primary_key=True)
    description = Column(TEXT())


class AlertEffect(Base):
    __tablename__ = 'rt_alert_effect'

    id = Column(Integer, primary_key=True)
    description = Column(TEXT())


class CongestionLevel(Base):
    __tablename__ = 'rt_congestion_level'

    id = Column(Integer, primary_key=True)
    description = Column(TEXT())


class OccupancyStatus(Base):
    __tablename__ = 'rt_occupancy_status'

    id = Column(Integer, primary_key=True)
    description = Column(TEXT())


class StopTimeScheduleRelationship(Base):
    __tablename__ = 'rt_stoptime_schedule_rel'

    id = Column(Integer, primary_key=True)
    description = Column(TEXT())

    reference = relationship('StopTimeUpdate', backref='StopTimeScheduleRelationship')


class TripScheduleRelationship(Base):
    __tablename__ = 'rt_trip_schedule_rel'

    id = Column(Integer, primary_key=True)
    description = Column(TEXT())

    reference = relationship('TripUpdate', backref='TripScheduleRelationship')


class StopStatus(Base):
    __tablename__ = 'rt_stop_status'

    id = Column(Integer, primary_key=True)
    description = Column(TEXT())


class TripUpdate(Base):
    __tablename__ = 'rt_trip_updates'

    oid = Column(Integer, primary_key=True)

    # This replaces the TripDescriptor message
    trip_id = Column(TEXT())
    route_id = Column(TEXT())
    trip_start_time = Column(Interval, default=None)
    trip_start_date = Column(DATE())

    # Put in the string value not the enum
    schedule_relationship = Column(Integer, ForeignKey('rt_trip_schedule_rel.id'))

    # Collapsed VehicleDescriptor
    vehicle_id = Column(TEXT())
    vehicle_label = Column(TEXT())
    vehicle_license_plate = Column(TEXT())

    # moved from the header, and reformatted as datetime
    timestamp = Column(TIMESTAMP(True))

    StopTimeUpdates = relationship('StopTimeUpdate', backref='TripUpdate')


class StopTimeUpdate(Base):
    __tablename__ = 'rt_stop_time_updates'

    oid = Column(Integer, primary_key=True)

    stop_sequence = Column(Integer)
    stop_id = Column(TEXT())

    # Collapsed StopTimeEvent
    arrival_delay = Column(Integer)
    arrival_time = Column(TIMESTAMP(True))
    arrival_uncertainty = Column(Integer)

    # Collapsed StopTimeEvent
    departure_delay = Column(Integer)
    departure_time = Column(TIMESTAMP(True))
    departure_uncertainty = Column(Integer)

    schedule_relationship = Column(Integer, ForeignKey('rt_stoptime_schedule_rel.id'))

    # Link it to the TripUpdate
    # The .TripUpdate is done by the backref in TripUpdate
    trip_update_id = Column(Integer, ForeignKey('rt_trip_updates.oid'))


class Alert(Base):
    __tablename__ = 'rt_alerts'

    oid = Column(Integer, primary_key=True)

    # Collapsed TimeRange
    start = Column(Integer)
    end = Column(Integer)

    # Add domain
    cause = Column(Integer, ForeignKey('rt_alert_cause.id'))
    effect = Column(Integer, ForeignKey('rt_alert_effect.id'))

    url = Column(TEXT())
    header_text = Column(TEXT())
    description_text = Column(TEXT())

    InformedEntities = relationship('EntitySelector', backref='Alert')


class EntitySelector(Base):
    __tablename__ = 'rt_entity_selectors'

    oid = Column(Integer, primary_key=True)

    agency_id = Column(TEXT())
    route_id = Column(TEXT())
    route_type = Column(Integer)
    stop_id = Column(TEXT())

    # Collapsed TripDescriptor
    trip_id = Column(TEXT())
    trip_route_id = Column(TEXT())
    trip_start_time = Column(Interval)
    trip_start_date = Column(DATE())

    alert_id = Column(Integer, ForeignKey('rt_alerts.oid'))


class VehiclePosition(Base):
    __tablename__ = 'rt_vehicle_positions'

    timestamp = Column(TIMESTAMP(True), primary_key=True)

    # This replaces the TripDescriptor message
    trip_id = Column(TEXT())
    route_id = Column(TEXT())
    trip_start_time = Column(Integer)
    trip_start_date = Column(TEXT())

    # Collapsed VehicleDescriptor
    vehicle_id = Column(TEXT(), primary_key=True)
    vehicle_label = Column(TEXT())
    vehicle_license_plate = Column(TEXT())

    # Collapsed Position
    latitude = Column(Float)
    longitude = Column(Float)
    bearing = Column(Float)
    speed = Column(Float)

    stop_id = Column(TEXT)
    stop_status = Column(Integer, ForeignKey('rt_stop_status.id'))

    occupancy_status = Column(Integer, ForeignKey('rt_occupancy_status.id'))
    congestion_level = Column(Integer, ForeignKey('rt_congestion_level.id'))

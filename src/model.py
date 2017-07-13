# gtfsrdb.py: load gtfs-realtime data to a database
# recommended to have the (static) GTFS data for the agency you are connecting
# to already loaded.

# Copyright 2017 Transit Center

# Licensed under the Apache License, Version 2.0 (the "License")
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Authors:
# Neil Freeman

from enum import Enum


class OccupancyStatus(Enum):
    EMPTY = 0
    MANY_SEATS_AVAILABLE = 1
    FEW_SEATS_AVAILABLE = 2
    STANDING_ROOM_ONLY = 3
    CRUSHED_STANDING_ROOM_ONLY = 4
    FULL = 5
    NOT_ACCEPTING_PASSENGERS = 6


class CongestionLevel(Enum):
    UNKNOWN_CONGESTION_LEVEL = 0
    RUNNING_SMOOTHLY = 1
    STOP_AND_GO = 2
    CONGESTION = 3


class StopTimeSchedule(Enum):
    SCHEDULED = 0
    SKIPPED = 1
    NO_DATA = 2


class TripSchedule(Enum):
    SCHEDULED = 0
    ADDED = 1
    UNSCHEDULED = 2
    CANCELED = 3


class AlertCause(Enum):
    UNKNOWN_CAUSE = 1
    TECHNICAL_PROBLEM = 3
    ACCIDENT = 6
    HOLIDAY = 7
    WEATHER = 8
    MAINTENANCE = 9
    CONSTRUCTION = 10
    POLICE_ACTIVITY = 11
    MEDICAL_EMERGENCY = 12


class AlertEffect(Enum):
    NO_SERVICE = 1
    REDUCED_SERVICE = 2
    SIGNIFICANT_DELAYS = 3
    DETOUR = 4
    ADDITIONAL_SERVICE = 5
    MODIFIED_SERVICE = 6
    OTHER_EFFECT = 7
    UNKNOWN_EFFECT = 8
    STOP_MOVED = 9


class StopStatus(Enum):
    INCOMING_AT = 0
    STOPPED_AT = 1
    IN_TRANSIT_TO = 2

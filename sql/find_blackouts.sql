-- Daily: Find blackout periods
-- TODO pass date

-- SET @start_date_utc = '2014-07-31', @end_date_utc = '2015-08-01';   -- will be the same date for daily process
SET @start_date_utc = DATE_SUB(DATE(NOW()), INTERVAL 1 DAY), @end_date_utc = DATE_SUB(DATE(NOW()), INTERVAL 1 DAY);
REPLACE positions_count SELECT DATE(@ts:=CONVERT_TZ(timestamp_utc,'UTC','America/New_York')) AS date, HOUR(@ts) AS hour, COUNT(1) AS records FROM bus_time WHERE timestamp_utc BETWEEN CAST(@start_date_utc AS DATETIME) AND ADDTIME(CAST(@end_date_utc AS DATETIME),'23:59:59') GROUP BY date, hour;    -- make REPLACE
UPDATE date_hours SET records = 0 WHERE ADDTIME(date, MAKETIME(hour,0,0)) BETWEEN CONVERT_TZ(CAST(@start_date_utc AS DATETIME),'UTC','America/New_York') AND CONVERT_TZ(ADDTIME(CAST(@end_date_utc AS DATETIME),'23:00:00'),'UTC','America/New_York');
UPDATE date_hours AS dh, positions_count AS pc SET dh.records = pc.records WHERE dh.date = pc.date AND dh.hour = pc.hour;
SELECT * FROM date_hours WHERE date BETWEEN DATE_SUB(@start_date_utc, INTERVAL 1 DAY) AND @end_date_utc AND hour BETWEEN 8 AND 21 AND records < 80000;       -- originally 60,000
SELECT * FROM date_hours WHERE date BETWEEN DATE_SUB(@start_date_utc, INTERVAL 1 DAY) AND @end_date_utc AND (hour <= 7 OR hour >= 22) AND records < 15000;   -- originally 15,000


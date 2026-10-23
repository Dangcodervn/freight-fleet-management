USE freight_fleet_management;
GO

-- Count rows
SELECT
    (SELECT COUNT(*) FROM raw.shipments) AS raw_rows,
    (SELECT COUNT(*) FROM logistics.shipments) AS clean_rows,
    (SELECT COUNT(DISTINCT booking_id) FROM logistics.shipments) AS distinct_bookings;

-- Check fake null
SELECT COUNT(*) AS fake_null_left
FROM logistics.shipments
WHERE vehicle_type IN ('NULL','NA')
   OR driver_name  IN ('NULL','NA')
   OR driver_mobile_no IN ('NULL','NA');

-- Date after (no more 1899)
SELECT
    MIN(trip_start_date) AS min_trip_start, MAX(trip_start_date) AS max_trip_start,
    MIN(planned_eta)     AS min_planned_eta, MAX(planned_eta)   AS max_planned_eta
FROM logistics.shipments;
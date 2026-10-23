USE freight_fleet_management;
GO

-- Count row
SELECT COUNT(*) AS total_row
FROM raw.shipments;

-- Count dup_keys
SELECT
	COUNT(*) AS total_rows,
	COUNT(DISTINCT [Booking ID]) AS distinct_bookings,
	COUNT(*) - COUNT(DISTINCT [Booking ID]) AS extra_rows
FROM raw.shipments;

-- Which keys are duplicated ?
SELECT
	[Booking ID],
	COUNT(*) AS row_count
FROM raw.shipments
GROUP BY [Booking ID]
HAVING COUNT(*) > 1
ORDER BY row_count DESC;

-- Detail of dup_keys's rows
WITH dup_keys AS (
	SELECT [Booking ID]
	FROM raw.shipments
	GROUP BY [Booking ID]
	HAVING COUNT(*) > 1
)
SELECT r.*
FROM raw.shipments AS r
JOIN dup_keys AS d ON r.[Booking ID] = d.[Booking ID]
ORDER BY r.[Booking ID];

-- Row is fully duplicated or just key
WITH distinct_rows AS (
    SELECT DISTINCT *
    FROM raw.shipments
)
SELECT
    (SELECT COUNT(*) FROM raw.shipments)                     AS total_rows,
    (SELECT COUNT(*) FROM distinct_rows)                     AS distinct_full_rows,
    (SELECT COUNT(DISTINCT [Booking ID]) FROM raw.shipments) AS distinct_bookings;

-- Distinct values: Vehicle Type, Gps Provider, Vehicle Registration
SELECT
    TRIM([Vehicle Type]) AS value,
    COUNT(*) AS row_count
FROM raw.shipments
GROUP BY TRIM([Vehicle Type])
ORDER BY row_count DESC;

SELECT
    TRIM([Gps Provider]) AS gps_provider,
    COUNT(*) AS row_count
FROM raw.shipments
GROUP BY TRIM([Gps Provider])
ORDER BY row_count DESC;

SELECT
    TRIM([Vehicle Registration]) AS value,
    COUNT(*) AS row_count
FROM raw.shipments
GROUP BY TRIM([Vehicle Registration])
ORDER BY row_count DESC;

-- Check null all rows
WITH long_format AS (
    SELECT v.col_name, v.val
    FROM raw.shipments AS r
    CROSS APPLY (VALUES
        ('gps_provider', r.[Gps Provider]),
        ('booking_id', r.[Booking ID]),
        ('shipment_type', r.[Shipment Type]),
        ('booking_date', r.[Booking Date]),
        ('vehicle_registration', r.[Vehicle Registration]),
        ('origin_location', r.[Origin Location]),
        ('destination_location', r.[Destination Location]),
        ('origin_lat', r.[Origin Location Latitude]),
        ('origin_long', r.[Origin Location Longitude]),
        ('dest_lat', r.[Destination Location Latitude]),
        ('dest_long', r.[Destination Location Longitude]),
        ('data_ping_time', r.[Data Ping time]),
        ('planned_eta', r.[Planned ETA]),
        ('current_location', r.[Current Location]),
        ('actual_eta', r.[Actual ETA]),
        ('current_lat', r.[Current Location Latitude]),
        ('current_long', r.[Curren Location Longitude]),
        ('ontime', r.[Ontime]),
        ('trip_start_date', r.[Trip Start Date]),
        ('trip_end_date', r.[Trip End Date]),
        ('transportation_distance_km', r.[Transportation Distance (KM)]),
        ('vehicle_type', r.[Vehicle Type]),
        ('min_kms_per_day', r.[Minimum Kms To Be Covered In A Day]),
        ('driver_name', r.[Driver Name]),
        ('driver_mobile_no', r.[Driver Mobile No]),
        ('customer_name', r.[Customer Name]),
        ('supplier_name', r.[Supplier Name]),
        ('material_shipped', r.[Material Shipped])
    ) AS v(col_name, val)
)
SELECT
    col_name,
    COUNT(*)                                                                AS total_rows,
    SUM(CASE WHEN val IS NULL THEN 1 ELSE 0 END)                            AS real_null,
    SUM(CASE WHEN TRIM(val) IN ('NULL', 'NA', 'N/A', '') THEN 1 ELSE 0 END) AS fake_null,
    SUM(CASE WHEN val IS NULL
              OR TRIM(val) IN ('NULL', 'NA', 'N/A', '') THEN 1 ELSE 0 END)  AS total_null,
    CAST(100.0 * SUM(CASE WHEN val IS NULL
                           OR TRIM(val) IN ('NULL', 'NA', 'N/A', '') THEN 1 ELSE 0 END)
         / COUNT(*) AS DECIMAL(5,1))                                        AS null_pct
FROM long_format
GROUP BY col_name
ORDER BY null_pct DESC;
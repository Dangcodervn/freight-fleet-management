-- Builds the star schema in schema [mart] from logistics.shipments.
-- Order: dimensions first, fact last. Safe to re-run.
-- Scope: only shipments booked from 2019-12-01 to 2020-08-31 are loaded (view mart.v_shipments_in_scope).
-- logistics.shipments stays complete (3,585 rows) for the ad-hoc queries; the mart holds 3,574 rows.
-- The 11 excluded shipments: 6 with contradictory timestamps (booked Sep-Dec 2020 but pinged and
-- delivered in Jul-Aug 2020), 2 with placeholder dates (1899-12-30) and 3 booked in Nov 2019.

USE freight_fleet_management;
GO

-- 0. Schema
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'mart')
    EXEC ('CREATE SCHEMA mart');
GO

-- 0b. Analysis scope (single place for the booking-date window; every table below reads from this view)
CREATE OR ALTER VIEW mart.v_shipments_in_scope AS
SELECT *
FROM freight_fleet_management.logistics.shipments
WHERE booking_date >= '2019-12-01'
  AND booking_date <  '2020-09-01';
GO

-- 1. mart.dim_date
DROP TABLE IF EXISTS mart.dim_date;

CREATE TABLE mart.dim_date (
    date_key INT NOT NULL PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    year_num INT NOT NULL,
    quarter_num INT NOT NULL,
    month_num INT NOT NULL,
    month_name VARCHAR(9) NOT NULL,
    year_month CHAR(7) NOT NULL,
    iso_year INT NOT NULL,
    iso_week_num INT NOT NULL,
    iso_week_start DATE NOT NULL,
    iso_day_of_week INT NOT NULL,
    day_name VARCHAR(9) NOT NULL
);

WITH d as (
    SELECT
        DATEADD(DAY, g.value, CAST('2019-12-01' AS DATE)) AS full_date
    FROM generate_series(0, DATEDIFF(DAY, '2019-12-01', '2020-08-31')) AS g
)
INSERT INTO mart.dim_date (
    date_key, full_date, year_num, quarter_num, month_num, month_name, year_month, iso_year, iso_week_num, iso_week_start, iso_day_of_week, day_name
)
SELECT
    CONVERT(INT, FORMAT(full_date, 'yyyyMMdd')),
    full_date,
    YEAR(full_date),
    DATEPART(QUARTER, full_date),
    MONTH(full_date),
    FORMAT(full_date, 'MMM', 'en-US'),
    FORMAT(full_date, 'yyyy-MM'),
    YEAR(DATEADD(DAY, 26 - DATEPART(ISO_WEEK, full_date), full_date)),
    DATEPART(ISO_WEEK, full_date),
    DATETRUNC(ISO_WEEK, full_date),
    (DATEDIFF(DAY, '19000101', full_date) % 7) + 1,
    FORMAT(full_date, 'dddd', 'en-US')
FROM d;

GO

-- 2. mart.dim_customer
DROP TABLE IF EXISTS mart.dim_customer;

CREATE TABLE mart.dim_customer (
    customer_key  INT IDENTITY(1,1) PRIMARY KEY,
    customer_name NVARCHAR(255) NOT NULL UNIQUE
);

INSERT INTO mart.dim_customer (customer_name)
SELECT DISTINCT customer_name
FROM mart.v_shipments_in_scope
ORDER BY customer_name;
GO

-- 3. mart.dim_material
DROP TABLE IF EXISTS mart.dim_material;

CREATE TABLE mart.dim_material(
    material_key INT IDENTITY(1,1) PRIMARY KEY,
    material_name NVARCHAR(255) NOT NULL UNIQUE
);

INSERT INTO mart.dim_material (material_name)
SELECT DISTINCT material_shipped
FROM mart.v_shipments_in_scope
ORDER BY material_shipped;
GO

-- 4. mart.dim_route
DROP TABLE IF EXISTS mart.dim_route

CREATE TABLE mart.dim_route (
    route_key INT IDENTITY(1,1) PRIMARY KEY,
    origin_location NVARCHAR(255) NOT NULL,
    destination_location NVARCHAR(255) NOT NULL,
    route_label NVARCHAR(255) NOT NULL,
    UNIQUE (origin_location, destination_location)
);

INSERT INTO mart.dim_route (origin_location, destination_location, route_label)
SELECT DISTINCT
    origin_location,
    destination_location,
    origin_location + N' -> ' + destination_location
FROM mart.v_shipments_in_scope
ORDER BY origin_location, destination_location;
GO

-- 5. mart.dim_driver
DROP TABLE IF EXISTS mart.dim_driver;

CREATE TABLE mart.dim_driver (
    driver_key  INT IDENTITY(1,1) PRIMARY KEY,
    driver_name NVARCHAR(255) NOT NULL UNIQUE
);
GO

SET IDENTITY_INSERT mart.dim_driver ON;
INSERT INTO mart.dim_driver (driver_key, driver_name) VALUES (0, N'Unknown');
SET IDENTITY_INSERT mart.dim_driver OFF;

INSERT INTO mart.dim_driver (driver_name)
SELECT DISTINCT driver_name
FROM mart.v_shipments_in_scope
WHERE driver_name IS NOT NULL
ORDER BY driver_name;
GO

-- 6. mart.dim_vehicle
-- 6a. mart.map_vehicle_type (helper, not imported into Power BI)
DROP TABLE IF EXISTS mart.map_vehicle_type;

CREATE TABLE mart.map_vehicle_type (
    vehicle_type_raw  NVARCHAR(255) NOT NULL PRIMARY KEY,
    vehicle_type_std  NVARCHAR(100) NOT NULL,
    payload_mt        DECIMAL(5,1)  NULL
);
GO

INSERT INTO mart.map_vehicle_type (vehicle_type_raw, vehicle_type_std, payload_mt) VALUES
(N'32 FT Multi-Axle 14MT - HCV', N'32 FT Multi-Axle', 14),
(N'40 FT 3XL Trailer 35MT', N'40 FT Trailer', 35),
(N'32 FT Single-Axle 7MT - HCV', N'32 FT Single-Axle', 7),
(N'40 FT Flat Bed Multi-Axle 27MT - Trailer', N'40 FT Trailer', 27),
(N'32 FT Multi-Axle MXL 18MT', N'32 FT Multi-Axle', 18),
(N'19 FT Open 7MT - MCV', N'19 FT Open', 7),
(N'20 FT SXL Container', N'20 FT Container', NULL),
(N'40 FT Flat Bed Double-Axle 21MT - Trailer', N'40 FT Trailer', 21),
(N'24 FT SXL Container', N'24 FT Container', NULL),
(N'20 FT CLOSE 7MT-MCV', N'20 FT Closed', 7),
(N'22 FT Taurus Open 16MT - HCV', N'22 FT Open', 16),
(N'Tata 407 Open 2MT - Mini-LCV', N'Light truck (Open)', 2),
(N'19 FT OPEN BODY 8 MT', N'19 FT Open', 8),
(N'1.5 MT Pickup (Open Body)', N'Mini truck (Open)', 1.5),
(N'15 FT Single-Axle 7.2MT (8.5 H) Container - HCV', N'15 FT Container', 7.2),
(N'20 FT Open 9MT - MCV', N'20 FT Open', 9),
(N'22 FT Closed Container', N'22 FT Closed', NULL),
(N'24 / 26 FT Taurus Open 21MT - HCV', N'24-26 FT Open', 21),
(N'26 FT Taurus Open 27MT - HCV', N'26 FT Open', 27),
(N'1.5 MT Vehicle (Closed Body)', N'Mini truck (Closed)', 1.5),
(N'17 FT Open 5MT - MCV', N'17 FT Open', 5),
(N'1 MT Tata Ace (Closed Body)', N'Mini truck (Closed)', 1),
(N'30 FT Open SXL 30MT', N'30 FT Open', 30),
(N'25 FT Open Body 21MT', N'25 FT Open', 21),
(N'32 FT Closed Container 15 MT', N'32 FT Closed', 15),
(N'1 MT Tata Ace (Open Body)', N'Mini truck (Open)', 1),
(N'17 FT Container', N'17 FT Container', NULL),
(N'20 FT Closed Container 8MT', N'20 FT Closed', 8),
(N'22 FT Open Body 16MT', N'22 FT Open', 16),
(N'30 FT Open MXL 30MT', N'30 FT Open', 30),
(N'32 FT Open Tarus', N'32 FT Open', NULL),
(N'40 FT Flat Bed Single-Axle 20MT - Trailer', N'40 FT Trailer', 20),
(N'Tata 407 / 14 FT Open 3MT LCV', N'Light truck (Open)', 3),
(N'Mahindra LCV 1MT', N'Mini truck', 1),
(N'28 FT Open Body 25MT', N'28 FT Open', 25),
(N'24 / 26 FT Closed Container 20MT - HCV', N'24-26 FT Closed', 20),
(N'19 FT SXL Container', N'19 FT Container', NULL),
(N'14 FT Open - 3 MT', N'14 FT Open', 3);
GO

-- 6b. mart.dim_vehicle
DROP TABLE IF EXISTS mart.dim_vehicle;

CREATE TABLE mart.dim_vehicle (
    vehicle_key           INT IDENTITY(1,1) PRIMARY KEY,
    vehicle_registration  NVARCHAR(50)  NOT NULL UNIQUE,
    vehicle_type_std      NVARCHAR(100) NOT NULL
);
GO

WITH t AS (
    SELECT s.vehicle_registration, m.vehicle_type_std,
           COUNT(*) AS n, MAX(s.booking_date) AS last_booking
    FROM mart.v_shipments_in_scope AS s
    JOIN mart.map_vehicle_type AS m ON m.vehicle_type_raw = s.vehicle_type
    GROUP BY s.vehicle_registration, m.vehicle_type_std
),
r AS (
    SELECT *, ROW_NUMBER() OVER (
                  PARTITION BY vehicle_registration
                  ORDER BY n DESC, last_booking DESC) AS rn
    FROM t
)
INSERT INTO mart.dim_vehicle (vehicle_registration, vehicle_type_std)
SELECT v.vehicle_registration, ISNULL(r.vehicle_type_std, N'Unknown')
FROM (SELECT DISTINCT vehicle_registration
      FROM mart.v_shipments_in_scope) AS v
LEFT JOIN r ON r.vehicle_registration = v.vehicle_registration AND r.rn = 1
ORDER BY v.vehicle_registration;
GO

-- 7. mart.fact_shipment
DROP TABLE IF EXISTS mart.fact_shipment;

CREATE TABLE mart.fact_shipment (
    shipment_key                INT IDENTITY(1,1) PRIMARY KEY,
    booking_id                  NVARCHAR(50)  NOT NULL,
    booking_date_key            INT           NOT NULL,
    trip_start_date_key         INT           NULL,
    actual_eta_date_key         INT           NULL,
    vehicle_key                 INT           NOT NULL,
    customer_key                INT           NOT NULL,
    material_key                INT           NOT NULL,
    route_key                   INT           NOT NULL,
    driver_key                  INT           NOT NULL,
    shipment_type               NVARCHAR(50)  NULL,
    transportation_distance_km  DECIMAL(10,2) NULL,
    planned_eta                 DATETIME      NULL,
    actual_eta                  DATETIME      NULL,
    trip_start_date             DATETIME      NULL,
    origin_lat                  DECIMAL(9,6)  NULL,
    origin_long                 DECIMAL(9,6)  NULL,
    dest_lat                    DECIMAL(9,6)  NULL,
    dest_long                   DECIMAL(9,6)  NULL,
    is_ontime                   TINYINT       NOT NULL,
    eta_variance_hours          DECIMAL(10,2) NULL,
    trip_duration_hours         DECIMAL(10,2) NULL,
    hours_per_km                DECIMAL(10,4) NULL,
    distance_band               NVARCHAR(20)  NOT NULL,
    distance_band_order         TINYINT       NOT NULL,
    trip_start_hour             TINYINT       NULL,
    payload_mt                  DECIMAL(5,1)  NULL,
    payload_group               NVARCHAR(20)  NOT NULL,
    payload_group_order         TINYINT       NOT NULL,
    eta_variance_band           NVARCHAR(20)  NOT NULL,
    eta_variance_band_order     TINYINT       NOT NULL
);
GO

INSERT INTO mart.fact_shipment (
    booking_id, booking_date_key, trip_start_date_key, actual_eta_date_key,
    vehicle_key, customer_key, material_key, route_key, driver_key,
    shipment_type, transportation_distance_km, planned_eta, actual_eta, trip_start_date,
    origin_lat, origin_long, dest_lat, dest_long,
    is_ontime, eta_variance_hours, trip_duration_hours, hours_per_km,
    distance_band, distance_band_order, trip_start_hour,
    payload_mt, payload_group, payload_group_order,
    eta_variance_band, eta_variance_band_order
)
SELECT
    s.booking_id,
    YEAR(s.booking_date) * 10000 + MONTH(s.booking_date) * 100 + DAY(s.booking_date),
    CASE WHEN s.trip_start_date IS NULL THEN NULL
         ELSE YEAR(s.trip_start_date) * 10000 + MONTH(s.trip_start_date) * 100 + DAY(s.trip_start_date) END,
    CASE WHEN s.actual_eta IS NULL THEN NULL
         ELSE YEAR(s.actual_eta) * 10000 + MONTH(s.actual_eta) * 100 + DAY(s.actual_eta) END,
    v.vehicle_key,
    c.customer_key,
    m.material_key,
    r.route_key,
    ISNULL(d.driver_key, 0),
    s.shipment_type,
    s.transportation_distance_km,
    s.planned_eta,
    s.actual_eta,
    s.trip_start_date,
    s.origin_lat, s.origin_long, s.dest_lat, s.dest_long,
    CASE WHEN s.ontime = 'Yes' THEN 1 ELSE 0 END,
    x.eta_variance_hours,
    x.trip_duration_hours,
    CASE WHEN x.trip_duration_hours > 0 AND s.transportation_distance_km > 0
         THEN CAST(x.trip_duration_hours / s.transportation_distance_km AS DECIMAL(10,4)) END,
    CASE WHEN s.transportation_distance_km IS NULL THEN N'Unknown'
         WHEN s.transportation_distance_km < 100  THEN N'Under 100 km'
         WHEN s.transportation_distance_km < 500  THEN N'100 - 500 km'
         WHEN s.transportation_distance_km < 1000 THEN N'500 - 1000 km'
         ELSE N'Over 1000 km' END,
    CASE WHEN s.transportation_distance_km IS NULL THEN 5
         WHEN s.transportation_distance_km < 100  THEN 1
         WHEN s.transportation_distance_km < 500  THEN 2
         WHEN s.transportation_distance_km < 1000 THEN 3
         ELSE 4 END,
    DATEPART(HOUR, s.trip_start_date),
    p.payload_mt,
    CASE WHEN p.payload_mt IS NULL THEN N'Unknown'
         WHEN p.payload_mt < 3  THEN N'Light'
         WHEN p.payload_mt < 10 THEN N'Medium'
         WHEN p.payload_mt < 20 THEN N'Heavy'
         ELSE N'Extra heavy' END,
    CASE WHEN p.payload_mt IS NULL THEN 5
         WHEN p.payload_mt < 3  THEN 1
         WHEN p.payload_mt < 10 THEN 2
         WHEN p.payload_mt < 20 THEN 3
         ELSE 4 END,
    CASE WHEN x.eta_variance_hours IS NULL THEN N'No actual ETA'
         WHEN x.eta_variance_hours <= -24  THEN N'Early over 1 day'
         WHEN x.eta_variance_hours <= 0    THEN N'Early or on time'
         WHEN x.eta_variance_hours <= 24   THEN N'Late up to 1 day'
         WHEN x.eta_variance_hours <= 72   THEN N'Late 1-3 days'
         WHEN x.eta_variance_hours <= 168  THEN N'Late 3-7 days'
         ELSE N'Late over 7 days' END,
    CASE WHEN x.eta_variance_hours IS NULL THEN 7
         WHEN x.eta_variance_hours <= -24  THEN 1
         WHEN x.eta_variance_hours <= 0    THEN 2
         WHEN x.eta_variance_hours <= 24   THEN 3
         WHEN x.eta_variance_hours <= 72   THEN 4
         WHEN x.eta_variance_hours <= 168  THEN 5
         ELSE 6 END
FROM mart.v_shipments_in_scope AS s
LEFT JOIN mart.dim_vehicle   AS v ON v.vehicle_registration = s.vehicle_registration
LEFT JOIN mart.dim_customer  AS c ON c.customer_name        = s.customer_name
LEFT JOIN mart.dim_material  AS m ON m.material_name        = s.material_shipped
LEFT JOIN mart.dim_route     AS r ON r.origin_location      = s.origin_location
                                 AND r.destination_location = s.destination_location
LEFT JOIN mart.dim_driver    AS d ON d.driver_name          = s.driver_name
LEFT JOIN mart.map_vehicle_type AS p ON p.vehicle_type_raw  = s.vehicle_type
CROSS APPLY (
    SELECT CAST(DATEDIFF(MINUTE, s.planned_eta, s.actual_eta) / 60.0 AS DECIMAL(10,2)) AS eta_variance_hours,
           CASE WHEN s.actual_eta > s.trip_start_date
                THEN CAST(DATEDIFF(MINUTE, s.trip_start_date, s.actual_eta) / 60.0 AS DECIMAL(10,2))
           END AS trip_duration_hours
) AS x
ORDER BY s.booking_id, s.customer_name, s.material_shipped;
GO

-- 8. Validation queries
-- Check dim_date
SELECT COUNT(*) AS total_days,
       COUNT(DISTINCT date_key) AS distinct_keys,
       MIN(full_date) AS first_day,
       MAX(full_date) AS last_day
FROM mart.dim_date;

-- Check dim_customer
SELECT COUNT(*) AS total_days
FROM mart.dim_customer

-- Check dim_route
SELECT COUNT(*) AS routes FROM mart.dim_route; 

SELECT COUNT(*) AS joined_rows
FROM mart.v_shipments_in_scope s
JOIN mart.dim_route r
  ON r.origin_location = s.origin_location
 AND r.destination_location = s.destination_location;

-- Check dim_vehicle
SELECT DISTINCT s.vehicle_type
FROM freight_fleet_management.logistics.shipments s
LEFT JOIN mart.map_vehicle_type m ON m.vehicle_type_raw = s.vehicle_type
WHERE s.vehicle_type IS NOT NULL AND m.vehicle_type_raw IS NULL;

SELECT COUNT(*) AS vehicles,
       SUM(CASE WHEN vehicle_type_std = N'Unknown' THEN 1 ELSE 0 END) AS unknown_type
FROM mart.dim_vehicle;

-- Check fact_shipments (expected: 3574 rows, equal to the rows of mart.v_shipments_in_scope)
SELECT COUNT(*) AS fact_rows,
       SUM(is_ontime) AS ontime_total,
       SUM(CASE WHEN driver_key = 0 THEN 1 ELSE 0 END) AS unknown_driver
FROM mart.fact_shipment;

-- Check eta_variance_band (expected: 1016, 349, 292, 534, 577, 781, 25 = 3574 rows)
SELECT eta_variance_band_order, eta_variance_band, COUNT(*) AS shipments
FROM mart.fact_shipment
GROUP BY eta_variance_band_order, eta_variance_band
ORDER BY eta_variance_band_order;
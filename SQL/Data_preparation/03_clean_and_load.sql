USE freight_fleet_management;
GO

-- Create clean table
DROP TABLE IF EXISTS logistics.shipments;

CREATE TABLE logistics.shipments (
    gps_provider NVARCHAR(100),
    booking_id NVARCHAR(50)  NOT NULL,
    shipment_type NVARCHAR(50),
    booking_date DATETIME,
    vehicle_registration NVARCHAR(50),
    origin_location NVARCHAR(255),
    destination_location NVARCHAR(255),
    origin_lat DECIMAL(9,6),
    origin_long DECIMAL(9,6),
    dest_lat DECIMAL(9,6),
    dest_long DECIMAL(9,6),
    data_ping_time DATETIME,
    planned_eta DATETIME,
    current_location NVARCHAR(500),
    actual_eta DATETIME,
    current_lat DECIMAL(9,6),
    current_long DECIMAL(9,6),
    ontime NVARCHAR(10),
    trip_start_date DATETIME,
    trip_end_date DATETIME,
    transportation_distance_km DECIMAL(10,2),
    vehicle_type NVARCHAR(255),
    min_kms_per_day NVARCHAR(20),
    driver_name NVARCHAR(255),
    driver_mobile_no NVARCHAR(20),
    customer_name NVARCHAR(255),
    supplier_name NVARCHAR(255),
    material_shipped NVARCHAR(255)
);
GO

-- One shipment = (booking_id, customer_name, material_shipped).
WITH cleaned AS (
    /* Step A: TRIM + change fake NULL ('NULL','NA','N/A','') into real NULL + change column's name into snake_case.
       vehicle_type, driver_name, supplier_name, material_shipped: also collapse runs of inner spaces into one
       (space -> '<>', drop '><' pairs, '<>' -> space; the data has no '<' or '>'). */
    SELECT
        CASE WHEN TRIM([Gps Provider]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Gps Provider]) END AS gps_provider,
        CASE WHEN TRIM([Booking ID]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Booking ID]) END AS booking_id,
        CASE WHEN TRIM([Shipment Type]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Shipment Type]) END AS shipment_type,
        CASE WHEN TRIM([Booking Date]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Booking Date]) END AS booking_date,
        CASE WHEN TRIM([Vehicle Registration]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Vehicle Registration]) END AS vehicle_registration,
        CASE WHEN TRIM([Origin Location]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Origin Location]) END AS origin_location,
        CASE WHEN TRIM([Destination Location]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Destination Location]) END AS destination_location,
        CASE WHEN TRIM([Origin Location Latitude]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Origin Location Latitude]) END AS origin_lat,
        CASE WHEN TRIM([Origin Location Longitude]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Origin Location Longitude]) END AS origin_long,
        CASE WHEN TRIM([Destination Location Latitude]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Destination Location Latitude]) END AS dest_lat,
        CASE WHEN TRIM([Destination Location Longitude]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Destination Location Longitude]) END AS dest_long,
        CASE WHEN TRIM([Data Ping time]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Data Ping time]) END AS data_ping_time,
        CASE WHEN TRIM([Planned ETA]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Planned ETA]) END AS planned_eta,
        CASE WHEN TRIM([Current Location]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Current Location]) END AS current_location,
        CASE WHEN TRIM([Actual ETA]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Actual ETA]) END AS actual_eta,
        CASE WHEN TRIM([Current Location Latitude]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Current Location Latitude]) END AS current_lat,
        CASE WHEN TRIM([Curren Location Longitude]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Curren Location Longitude]) END AS current_long,
        CASE WHEN TRIM([Ontime]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Ontime]) END AS ontime,
        CASE WHEN TRIM([Trip Start Date]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Trip Start Date]) END AS trip_start_date,
        CASE WHEN TRIM([Trip End Date]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Trip End Date]) END AS trip_end_date,
        CASE WHEN TRIM([Transportation Distance (KM)]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Transportation Distance (KM)]) END AS transportation_distance_km,
        CASE WHEN TRIM([Vehicle Type]) IN ('NULL','NA','N/A','') THEN NULL
             ELSE REPLACE(REPLACE(REPLACE(TRIM([Vehicle Type]), ' ', '<>'), '><', ''), '<>', ' ') END AS vehicle_type,
        CASE WHEN TRIM([Minimum Kms To Be Covered In A Day]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Minimum Kms To Be Covered In A Day]) END AS min_kms_per_day,
        CASE WHEN TRIM([Driver Name]) IN ('NULL','NA','N/A','') THEN NULL
             ELSE REPLACE(REPLACE(REPLACE(TRIM([Driver Name]), ' ', '<>'), '><', ''), '<>', ' ') END AS driver_name,
        CASE WHEN TRIM([Driver Mobile No]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Driver Mobile No]) END AS driver_mobile_no,
        CASE WHEN TRIM([Customer Name]) IN ('NULL','NA','N/A','') THEN NULL ELSE TRIM([Customer Name]) END AS customer_name,
        CASE WHEN TRIM([Supplier Name]) IN ('NULL','NA','N/A','') THEN NULL
             ELSE REPLACE(REPLACE(REPLACE(TRIM([Supplier Name]), ' ', '<>'), '><', ''), '<>', ' ') END AS supplier_name,
        CASE WHEN TRIM([Material Shipped]) IN ('NULL','NA','N/A','') THEN NULL
             ELSE REPLACE(REPLACE(REPLACE(TRIM([Material Shipped]), ' ', '<>'), '><', ''), '<>', ' ') END AS material_shipped
    FROM raw.shipments
),
typed AS (
    /* Step B: CAST data type.
       Date before 2000 (ex: 1899-12-30) -> NULL. */
    SELECT
        gps_provider,
        booking_id,
        shipment_type,
        CASE WHEN TRY_CAST(booking_date AS DATETIME) >= '2000-01-01' THEN TRY_CAST(booking_date AS DATETIME) END AS booking_date,
        UPPER(vehicle_registration) AS vehicle_registration,
        origin_location,
        destination_location,
        TRY_CAST(origin_lat AS DECIMAL(9,6)) AS origin_lat,
        TRY_CAST(origin_long AS DECIMAL(9,6)) AS origin_long,
        TRY_CAST(dest_lat AS DECIMAL(9,6)) AS dest_lat,
        TRY_CAST(dest_long AS DECIMAL(9,6)) AS dest_long,
        CASE WHEN TRY_CAST(data_ping_time AS DATETIME) >= '2000-01-01' THEN TRY_CAST(data_ping_time AS DATETIME) END AS data_ping_time,
        CASE WHEN TRY_CAST(planned_eta AS DATETIME) >= '2000-01-01' THEN TRY_CAST(planned_eta AS DATETIME) END AS planned_eta,
        current_location,
        CASE WHEN TRY_CAST(actual_eta AS DATETIME) >= '2000-01-01' THEN TRY_CAST(actual_eta AS DATETIME) END AS actual_eta,
        TRY_CAST(current_lat AS DECIMAL(9,6)) AS current_lat,
        TRY_CAST(current_long AS DECIMAL(9,6)) AS current_long,
        ontime,
        CASE WHEN TRY_CAST(trip_start_date AS DATETIME) >= '2000-01-01' THEN TRY_CAST(trip_start_date AS DATETIME) END AS trip_start_date,
        CASE WHEN TRY_CAST(trip_end_date AS DATETIME) >= '2000-01-01' THEN TRY_CAST(trip_end_date AS DATETIME) END AS trip_end_date,
        TRY_CAST(transportation_distance_km AS DECIMAL(10,2)) AS transportation_distance_km,
        vehicle_type,
        min_kms_per_day,
        driver_name,
        driver_mobile_no,
        customer_name,
        supplier_name,
        material_shipped
    FROM cleaned
    WHERE booking_id IS NOT NULL
)
INSERT INTO logistics.shipments (
    gps_provider, booking_id, shipment_type, booking_date, vehicle_registration,
    origin_location, destination_location, origin_lat, origin_long, dest_lat, dest_long,
    data_ping_time, planned_eta, current_location, actual_eta, current_lat, current_long,
    ontime, trip_start_date, trip_end_date, transportation_distance_km, vehicle_type,
    min_kms_per_day, driver_name, driver_mobile_no, customer_name, supplier_name, material_shipped
)
SELECT
    gps_provider, booking_id, shipment_type, booking_date, vehicle_registration,
    origin_location, destination_location, origin_lat, origin_long, dest_lat, dest_long,
    data_ping_time, planned_eta, current_location, actual_eta, current_lat, current_long,
    ontime, trip_start_date, trip_end_date, transportation_distance_km, vehicle_type,
    min_kms_per_day, driver_name, driver_mobile_no, customer_name, supplier_name, material_shipped
FROM typed;
GO
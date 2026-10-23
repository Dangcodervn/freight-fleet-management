-- Q1: On-time rate tổng
-- Em cho anh % shipment giao đúng hẹn (on-time rate) trên toàn chain. 1 con số cho daily KPI
SELECT
	SUM(CASE WHEN ontime  = 'Yes' THEN 1 ELSE 0 END) AS on_time_count,
	COUNT(*) row_count,
	CAST(100 * SUM(CASE WHEN ontime  = 'Yes' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS on_time_rate_pct
FROM freight_fleet_management.logistics.shipments

-- Q2: Shipment theo vehicle type
-- Chị cần số shipment theo từng loại xe – xe nào đang hoạt động nhiều nhất ?
SELECT
	vehicle_type,
	COUNT(*) AS shipment_count
FROM freight_fleet_management.logistics.shipments
GROUP BY vehicle_type
ORDER BY shipment_count DESC

-- Q3: Top 10 customer theo volume
-- Anh cần top 10 khách hàng có nhiều shipment nhất – để sales team ưu tiên account management.
SELECT
	customer_name,
	COUNT(*) AS shipment_count
FROM freight_fleet_management.logistics.shipments
GROUP BY customer_name
ORDER BY shipment_count DESC;

-- Q4: Phân phối khoảng cách
-- Em cho chị phân phối shipment theo khoảng cách: dưới 100 km, 100–500, 500–1000, trên 1000 km. Để đánh giá chiến lược long-haul vs short-haul.
WITH grouped AS (
	SELECT
		CASE
            WHEN transportation_distance_km IS NULL THEN 5
            WHEN transportation_distance_km < 100   THEN 1
            WHEN transportation_distance_km < 500   THEN 2
            WHEN transportation_distance_km < 1000  THEN 3
            ELSE 4
        END AS group_order,
		CASE
			WHEN transportation_distance_km IS NULL THEN 'Unknown'
			WHEN transportation_distance_km < 100 THEN 'under 100 km'
			WHEN transportation_distance_km >= 100 AND transportation_distance_km < 500 THEN '100 - 500'
			WHEN transportation_distance_km >= 500 AND transportation_distance_km < 1000 THEN '500 - 1000'
			ELSE 'over 1000 km'
		END AS distance_group
	FROM freight_fleet_management.logistics.shipments
)
SELECT
	distance_group,
	COUNT(*) AS shipment_count,
	CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct
FROM grouped
GROUP BY group_order, distance_group
ORDER BY group_order ASC;

-- Q5: Shipment theo tháng
-- Anh cần số shipment theo tháng 24 tháng gần nhất để thấy trend growth.
WITH bounds AS (
	SELECT
		DATETRUNC(MONTH, DATEADD(MONTH, -23, MAX(booking_date))) AS start_month,
		DATETRUNC(MONTH, MAX(booking_date)) AS end_month
	FROM freight_fleet_management.logistics.shipments
),
months AS (
	SELECT DATEADD(MONTH, g.value, b.start_month) AS year_month_group
	FROM bounds AS b
	CROSS JOIN GENERATE_SERIES(0, 23) AS g
	WHERE DATEADD(MONTH, g.value, b.start_month) <= b.end_month
),
monthly AS (
	SELECT
		DATETRUNC(MONTH, s.booking_date) AS year_month_group,
		COUNT(*) AS shipment_count
	FROM freight_fleet_management.logistics.shipments AS s
	CROSS JOIN bounds AS b
	WHERE s.booking_date >= b.start_month
	GROUP BY DATETRUNC(MONTH, s.booking_date)
)
SELECT
	FORMAT(m.year_month_group, 'yyyy-MM') AS year_month,
	ISNULL(t.shipment_count, 0) AS shipment_count
FROM months AS m
LEFT JOIN monthly AS t
	ON m.year_month_group = t.year_month_group
ORDER BY m.year_month_group;

-- Q6:ETA variance trung bình
-- Chị cần số giờ chênh giữa ETA dự kiến và thực tế, trung bình theo loại xe. Loại nào hay trễ?
SELECT
	COALESCE(vehicle_type, 'Unknown') AS vehicle_type,
	AVG(DATEDIFF(MINUTE, planned_eta, actual_eta) / 60.0) AS avg_delay_hours
FROM freight_fleet_management.logistics.shipments
GROUP BY vehicle_type
ORDER BY avg_delay_hours DESC

-- Q7: On-time rate theo route
-- Anh cần on-time rate theo từng cặp (origin, destination): top 10 route về volume, bottom 5 route về on-time rate.
SELECT
	origin_location,
	destination_location,
	COUNT(*) AS shipment_count,
	CAST(100 * SUM(CASE WHEN ontime = 'Yes' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS on_time_rate_pct
FROM freight_fleet_management.logistics.shipments
GROUP BY origin_location, destination_location
ORDER BY on_time_rate_pct ASC

-- Q8: Driver performance
-- Chị cần rank driver: số shipment, on-time rate, khoảng cách trung bình/chuyến. Để thưởng + coaching.
SELECT
	driver_name,
	COUNT(*) AS shipment_count,
	CAST(100.0 * SUM(CASE WHEN ontime = 'Yes' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS on_time_rate_pct,
	CAST(AVG(transportation_distance_km) AS DECIMAL(10, 2)) AS avg_distance_km
FROM freight_fleet_management.logistics.shipments
WHERE driver_name IS NOT NULL
GROUP BY driver_name, driver_mobile_no
HAVING COUNT(*) >= 10
ORDER BY on_time_rate_pct DESC, shipment_count DESC, driver_name;

-- Q9: Chuyến có tốc độ chậm bất thường
-- Em flag giúp anh chuyến có tỷ lệ thời gian / khoảng cách cao gấp đôi trung bình – có thể tài xế tham nhũng thời gian, hoặc tắc đường.
WITH trips AS (
	SELECT
		booking_id,
		origin_location,
		destination_location,
		driver_name,
		transportation_distance_km,
		DATEDIFF(MINUTE, trip_start_date, trip_end_date) / 60.0 AS trip_hour,
		DATEDIFF(MINUTE, trip_start_date, trip_end_date) / 60.0 / transportation_distance_km AS hour_per_km
	FROM freight_fleet_management.logistics.shipments
	WHERE transportation_distance_km > 0 AND trip_start_date > '2000-01-01' AND trip_end_date > trip_start_date
),
tmp AS (
	SELECT AVG(hour_per_km) AS avg_hour_per_km FROM trips
)
SELECT
	booking_id,
	origin_location,
	destination_location,
	driver_name,
	transportation_distance_km,
	CAST(trip_hour AS DECIMAL(10, 2)) AS trip_hour,
	CAST(hour_per_km AS DECIMAL(10, 4)) AS hour_per_km,
	CAST(avg_hour_per_km AS DECIMAL(10, 4)) AS avg_hour_per_km
FROM trips
CROSS JOIN tmp
WHERE hour_per_km > 2 * avg_hour_per_km
ORDER BY hour_per_km DESC

-- Q10: Top material shipped
-- Chị cần top 10 loại hàng shipped + khoảng cách trung bình + thời gian trung bình cho từng loại.
SELECT TOP 10
	material_shipped,
	COUNT(*) AS shipment_count,
	CAST(AVG(transportation_distance_km) AS DECIMAL(10, 2)) AS avg_distance_km,
	CAST(AVG(DATEDIFF(MINUTE, trip_start_date, trip_end_date) / 60.0) AS DECIMAL(10, 2)) AS avg_shipped_time
FROM freight_fleet_management.logistics.shipments
WHERE trip_end_date > trip_start_date
GROUP BY material_shipped
ORDER BY shipment_count DESC;

-- Q11: On-time rate rolling theo tuần
-- Anh cần on-time rate theo từng tuần ISO + rolling 7 tuần để thấy trend smooth.
WITH weekly AS (
	SELECT
		DATETRUNC(ISO_WEEK, booking_date) AS iso_week_date,
		COUNT(*) AS shipment_count,
		SUM(CASE WHEN ontime = 'Yes' THEN 1 ELSE 0 END) AS ontime_shipment_count
	FROM freight_fleet_management.logistics.shipments
	GROUP BY DATETRUNC(ISO_WEEK, booking_date)
),
bounds AS (
	SELECT
		MIN(iso_week_date) AS min_iso_week,
		MAX(iso_week_date) AS max_iso_week
	FROM weekly
),
weeks AS (
	SELECT
		DATEADD(WEEK, g.value, min_iso_week) AS week_start
	FROM bounds
	CROSS APPLY generate_series(0, DATEDIFF(WEEK, min_iso_week, max_iso_week)) g
)
SELECT
	week_start,
	ISNULL(shipment_count, 0) AS shipment_count,
	ISNULL(ontime_shipment_count, 0) AS ontime_shipment_count,
	CAST(100.0 * ontime_shipment_count / NULLIF(shipment_count, 0) AS DECIMAL(5,2)) AS ontime_rate_pct,
	CAST(100.0 * SUM (ontime_shipment_count) OVER (ORDER BY week_start ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) / NULLIF(SUM(shipment_count) OVER( ORDER BY week_start ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 0) AS DECIMAL(5,2)) AS rolling_7w_ontime_pct
FROM weeks
LEFT JOIN weekly ON week_start = iso_week_date
ORDER BY week_start;

-- Q12: Top 3 driver mỗi vehicle type
-- Chị cần top 3 driver on-time rate cao nhất trong mỗi loại xe.

-- Q13: Route volume YoY
-- Em cho anh volume mỗi route theo năm + % tăng trưởng YoY. Route nào đang growing, route nào declining?

-- Q14: Vehicle utilization theo tháng
-- Chị cần số chuyến mỗi xe mỗi tháng – tính utilization. Xác định xe under-utilized để re-allocate.

-- Q15: Delay hotspot – route × giờ
-- Anh cần matrix giờ × route với cell = ETA variance trung bình. Top 10 combo delay tệ nhất để team routing biết tránh.
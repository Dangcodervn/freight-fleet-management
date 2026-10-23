-- Create raw
USE freight_fleet_management;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'raw')
	EXEC ('CREATE SCHEMA raw');
GO

DROP TABLE IF EXISTS raw.shipments;

CREATE TABLE raw.shipments (
	[Gps Provider] NVARCHAR(255),
	[Booking ID] NVARCHAR(255),
	[Shipment Type] NVARCHAR(255),
	[Booking Date] NVARCHAR(255),
	[Vehicle Registration] NVARCHAR(255),
	[Origin Location] NVARCHAR(255),
	[Destination Location] NVARCHAR(255),
	[Origin Location Latitude] NVARCHAR(255),
	[Origin Location Longitude] NVARCHAR(255),
	[Destination Location Latitude] NVARCHAR(255),
	[Destination Location Longitude] NVARCHAR(255),
	[Data Ping time] NVARCHAR(255),
	[Planned ETA] NVARCHAR(255),
	[Current Location] NVARCHAR(255),
	[Actual ETA] NVARCHAR(255),
	[Current Location Latitude] NVARCHAR(255),
	[Curren Location Longitude] NVARCHAR(255),
	[Ontime] NVARCHAR(255),
	[Trip Start Date] NVARCHAR(255),
	[Trip End Date] NVARCHAR(255),
	[Transportation Distance (KM)] NVARCHAR(255),
	[Vehicle Type] NVARCHAR(255),
	[Minimum Kms To Be Covered In A Day] NVARCHAR(255),
	[Driver Name] NVARCHAR(255),
	[Driver Mobile No] NVARCHAR(255),
	[Customer Name] NVARCHAR(255),
	[Supplier Name] NVARCHAR(255),
	[Material Shipped] NVARCHAR(255)
);

BULK INSERT raw.shipments
FROM 'D:\Data Self Learning\Extra Projects\Freight Fleet Management\Data\logistics.shipments.csv'
WITH (
	FORMAT = 'CSV',
	FIRSTROW = 2,
	FIELDQUOTE = '"',
	CODEPAGE = '65001'
);
GO
-- =====================================================================
-- RetailDW - Database and table creation script
-- Run this in SSMS against your SQL Server instance (DEV first)
-- =====================================================================

BEGIN
    CREATE DATABASE RetailDW;
END
GO

USE RetailDW;
GO

-- =====================================================================
-- Staging tables
-- Loose typing (VARCHAR) so a file with bad dates/numbers/duplicates
-- can still land here without failing on insert. Validation and type
-- conversion happen in the Data Flow, moving clean rows on to the
-- Dim/Fact tables below and bad rows to RejectedRecords.
-- =====================================================================

IF OBJECT_ID('dbo.StgCustomer', 'U') IS NOT NULL DROP TABLE dbo.StgCustomer;
CREATE TABLE dbo.StgCustomer (
    CustomerID      VARCHAR(50)  NULL,
    CustomerName    VARCHAR(200) NULL,
    Email           VARCHAR(200) NULL,
    City            VARCHAR(100) NULL,
    State           VARCHAR(100) NULL,
    SourceFileName      VARCHAR(255) NULL,
    LoadDate        DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

IF OBJECT_ID('dbo.StgProduct', 'U') IS NOT NULL DROP TABLE dbo.StgProduct;
CREATE TABLE dbo.StgProduct (
    ProductID       VARCHAR(50)  NULL,
    ProductName     VARCHAR(200) NULL,
    Category        VARCHAR(100) NULL,
    Price           VARCHAR(50)  NULL,   -- kept as text: source may contain "N/A", negatives, blanks
    SourceFileName      VARCHAR(255) NULL,
    LoadDate        DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

IF OBJECT_ID('dbo.StgStore', 'U') IS NOT NULL DROP TABLE dbo.StgStore;
CREATE TABLE dbo.StgStore (
    StoreID         VARCHAR(50)  NULL,
    StoreName       VARCHAR(200) NULL,
    City            VARCHAR(100) NULL,
    State           VARCHAR(100) NULL,
    SourceFileName      VARCHAR(255) NULL,
    LoadDate        DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

IF OBJECT_ID('dbo.StgSales', 'U') IS NOT NULL DROP TABLE dbo.StgSales;
CREATE TABLE dbo.StgSales (
    SaleID          VARCHAR(50)  NULL,
    SaleDate        VARCHAR(50)  NULL,   -- kept as text: source may contain unparsable dates
    CustomerID      VARCHAR(50)  NULL,
    ProductID       VARCHAR(50)  NULL,
    StoreID         VARCHAR(50)  NULL,
    Quantity        VARCHAR(50)  NULL,   -- kept as text: source may contain non-numeric junk
    UnitPrice       VARCHAR(50)  NULL,
    SourceFileName      VARCHAR(255) NULL,
    LoadDate        DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

-- =====================================================================
-- Dimension tables
-- =====================================================================

IF OBJECT_ID('dbo.DimCustomer', 'U') IS NOT NULL DROP TABLE dbo.DimCustomer;
CREATE TABLE dbo.DimCustomer (
    CustomerKey     INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID      VARCHAR(20)   NOT NULL,
    CustomerName    VARCHAR(200)  NOT NULL,
    Email           VARCHAR(200)  NULL,
    City            VARCHAR(100)  NULL,
    State           VARCHAR(100)  NULL,
    CreatedDate     DATETIME      NOT NULL DEFAULT GETDATE(),
    ModifiedDate    DATETIME      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UQ_DimCustomer_CustomerID UNIQUE (CustomerID)
);
GO

IF OBJECT_ID('dbo.DimProduct', 'U') IS NOT NULL DROP TABLE dbo.DimProduct;
CREATE TABLE dbo.DimProduct (
    ProductKey      INT IDENTITY(1,1) PRIMARY KEY,
    ProductID       VARCHAR(20)   NOT NULL,
    ProductName     VARCHAR(200)  NOT NULL,
    Category        VARCHAR(100)  NULL,
    Price           DECIMAL(18,2) NOT NULL,
    CreatedDate     DATETIME      NOT NULL DEFAULT GETDATE(),
    ModifiedDate    DATETIME      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UQ_DimProduct_ProductID UNIQUE (ProductID)
);
GO

IF OBJECT_ID('dbo.DimStore', 'U') IS NOT NULL DROP TABLE dbo.DimStore;
CREATE TABLE dbo.DimStore (
    StoreKey        INT IDENTITY(1,1) PRIMARY KEY,
    StoreID         VARCHAR(20)   NOT NULL,
    StoreName       VARCHAR(200)  NOT NULL,
    City            VARCHAR(100)  NULL,
    State           VARCHAR(100)  NULL,
    CONSTRAINT UQ_DimStore_StoreID UNIQUE (StoreID)
);
GO

-- =====================================================================
-- Fact table
-- =====================================================================

IF OBJECT_ID('dbo.FactSales', 'U') IS NOT NULL DROP TABLE dbo.FactSales;
CREATE TABLE dbo.FactSales (
    SalesKey        BIGINT IDENTITY(1,1) PRIMARY KEY,
    SaleID          VARCHAR(20)   NOT NULL,
    SaleDate        DATE          NOT NULL,
    CustomerKey     INT           NOT NULL,
    ProductKey      INT           NOT NULL,
    StoreKey        INT           NOT NULL,
    Quantity        INT           NOT NULL,
    UnitPrice       DECIMAL(18,2) NOT NULL,
    TotalAmount     AS (Quantity * UnitPrice) PERSISTED,
    
    LoadDate        DATETIME      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UQ_FactSales_SaleID UNIQUE (SaleID),
    CONSTRAINT FK_FactSales_Customer FOREIGN KEY (CustomerKey) REFERENCES dbo.DimCustomer(CustomerKey),
    CONSTRAINT FK_FactSales_Product FOREIGN KEY (ProductKey) REFERENCES dbo.DimProduct(ProductKey),
    CONSTRAINT FK_FactSales_Store FOREIGN KEY (StoreKey) REFERENCES dbo.DimStore(StoreKey)
);
GO

-- =====================================================================
-- Supporting tables: file tracking, rejected records, audit
-- =====================================================================

IF OBJECT_ID('dbo.FileImports', 'U') IS NOT NULL DROP TABLE dbo.FileImports;
CREATE TABLE dbo.FileImports (
    FileImportID      INT IDENTITY(1,1) PRIMARY KEY,
    FileName          VARCHAR(255) NOT NULL,
    ArchivePath       VARCHAR(500) NULL,
    FileImportStatus  VARCHAR(50)  NOT NULL DEFAULT 'Received',  -- Received, Successfully Loaded, Failed
    CreatedDate       DATETIME     NOT NULL DEFAULT GETDATE(),
    UpdatedDate       DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

IF OBJECT_ID('dbo.RejectedRecords', 'U') IS NOT NULL DROP TABLE dbo.RejectedRecords;
CREATE TABLE dbo.RejectedRecords (
    RejectID        INT IDENTITY(1,1) PRIMARY KEY,
    SourceFile      VARCHAR(255) NULL,
    TableName       VARCHAR(50)  NULL,   -- which staging table this row came from
    RecordKey     VARCHAR(100) NULL,   -- e.g. the SaleID, CustomerID, etc. that failed
    RawData         VARCHAR(MAX) NULL,   -- the full original row, for support to inspect
    ErrorReason     VARCHAR(500) NOT NULL,
    ErrorDate       DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

IF OBJECT_ID('dbo.AuditLog', 'U') IS NOT NULL DROP TABLE dbo.AuditLog;
CREATE TABLE dbo.AuditLog (
    AuditID           INT IDENTITY(1,1) PRIMARY KEY,
    PackageName       VARCHAR(200) NOT NULL,
    SourceFile        VARCHAR(255) NULL,
    StartTime         DATETIME     NOT NULL,
    EndTime           DATETIME     NULL,
    Status            VARCHAR(50)  NOT NULL,  -- Running, Success, Failed
    RecordsRead       INT NULL,
    RecordsInserted   INT NULL,
    RecordsRejected   INT NULL,
    ErrorMessage      VARCHAR(MAX) NULL
);
GO


   SELECT * from StgProduct;
   select * from DimProduct;

   select * from StgStore;
   select * from DimStore;


   SELECT * from RejectedRecords;

   delete from DimProduct;

   select * from FactSales;

DELETE FROM dbo.FactSales;
DELETE FROM dbo.StgCustomer;
DELETE FROM dbo.StgProduct;
DELETE FROM dbo.StgStore;
DELETE FROM dbo.StgSales;
DELETE FROM dbo.DimCustomer;
DELETE FROM dbo.DimProduct;
DELETE FROM dbo.DimStore;
DELETE FROM dbo.RejectedRecords;
DELETE FROM dbo.AuditLog;
DELETE FROM dbo.FileImports;
 
DBCC CHECKIDENT ('dbo.FactSales', RESEED, 0);
DBCC CHECKIDENT ('dbo.DimCustomer', RESEED, 0);
DBCC CHECKIDENT ('dbo.DimProduct', RESEED, 0);
DBCC CHECKIDENT ('dbo.DimStore', RESEED, 0);
DBCC CHECKIDENT ('dbo.RejectedRecords', RESEED, 0);
DBCC CHECKIDENT ('dbo.AuditLog', RESEED, 0);
DBCC CHECKIDENT ('dbo.FileImports', RESEED, 0);

select * from AuditLog;

select * from FileImports;
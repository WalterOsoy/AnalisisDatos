USE master
GO


DECLARE @EliminarDB BIT = 1;
--Eliminar BDD si ya existe y si @EliminarDB = 1
if (((select COUNT(1) from sys.databases where name = 'RepuestosWebDWH')>0) AND (@EliminarDB = 1))
begin
	EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'RepuestosWebDWH'
	
	
	use [master];
	ALTER DATABASE [RepuestosWebDWH] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE;
		
	DROP DATABASE [RepuestosWebDWH]
	print 'RepuestosWebDWH ha sido eliminada'
end


CREATE DATABASE RepuestosWebDWH
GO

USE RepuestosWebDWH
GO
--Enteros
 --User Defined Type _ Surrogate Key
	--Tipo para SK entero: Surrogate Key
	CREATE TYPE [UDT_SK] FROM INT
	GO

	--Tipo para PK entero
	CREATE TYPE [UDT_PK] FROM INT
	GO

--Cadenas

	--Tipo para cadenas largas
	CREATE TYPE [UDT_VarcharLargo] FROM VARCHAR(600)
	GO

	--Tipo para cadenas medianas
	CREATE TYPE [UDT_VarcharMediano] FROM VARCHAR(300)
	GO

	--Tipo para cadenas cortas
	CREATE TYPE [UDT_VarcharCorto] FROM VARCHAR(100)
	GO

	--Tipo para cadenas cortas
	CREATE TYPE [UDT_UnCaracter] FROM CHAR(1)
	GO

--Decimal

	--Tipo Decimal 6,2
	CREATE TYPE [UDT_Decimal6.2] FROM DECIMAL(6,2)
	GO

	--Tipo Decimal 5,2
	CREATE TYPE [UDT_Decimal5.2] FROM DECIMAL(5,2)
	GO

--Fechas
	CREATE TYPE [UDT_DateTime] FROM DATETIME
	GO

--Schemas para separar objetos
	CREATE SCHEMA Fact
	GO

	CREATE SCHEMA Dimension
	GO

--------------------------------------------------------------------------------------------
-------------------------------MODELADO CONCEPTUAL------------------------------------------
--------------------------------------------------------------------------------------------
--Tablas Dimensiones
CREATE TABLE Dimension.Fecha
	(
		DateKey INT PRIMARY KEY
	)
	GO

	CREATE TABLE Dimension.Partes
	(
		SK_Partes [UDT_SK] PRIMARY KEY IDENTITY,
		--Columnas SCD Tipo 2
		[FechaInicioValidez] DATETIME NOT NULL DEFAULT(GETDATE()),
		[FechaFinValidez] DATETIME NULL,
		--Columnas Linaje
		ID_Batch UNIQUEIDENTIFIER NULL,
		ID_SourceSystem VARCHAR(20)
	)
	GO

	CREATE TABLE Dimension.Geografia
	(
		SK_Geografia [UDT_SK] PRIMARY KEY IDENTITY,
		--Columnas SCD Tipo 2
		[FechaInicioValidez] DATETIME NOT NULL DEFAULT(GETDATE()),
		[FechaFinValidez] DATETIME NULL,
		--Columnas Linaje
		ID_Batch UNIQUEIDENTIFIER NULL,
		ID_SourceSystem VARCHAR(20)
	)
	GO

	CREATE TABLE Dimension.Clientes
	(
		SK_Clientes [UDT_SK] PRIMARY KEY IDENTITY,
		--Columnas SCD Tipo 2
		[FechaInicioValidez] DATETIME NOT NULL DEFAULT(GETDATE()),
		[FechaFinValidez] DATETIME NULL,
		--Columnas Linaje
		ID_Batch UNIQUEIDENTIFIER NULL,
		ID_SourceSystem VARCHAR(20)
	)
	GO
--Tablas Fact

	CREATE TABLE Fact.Orden
	(
		SK_Oden [UDT_SK] PRIMARY KEY IDENTITY,
		SK_Partes [UDT_SK] REFERENCES Dimension.Partes(SK_Partes),
		SK_Geografia [UDT_SK] REFERENCES Dimension.Geografia(SK_Geografia),
		SK_Clientes [UDT_SK] REFERENCES Dimension.Clientes(SK_Clientes),
		DateKey INT REFERENCES Dimension.Fecha(DateKey),
		--Columnas Linaje
		ID_Batch UNIQUEIDENTIFIER NULL,
		ID_SourceSystem VARCHAR(20)
	)
	Go
--Metadata

	EXEC sys.sp_addextendedproperty 
     @name = N'Desnormalizacion', 
     @value = N'La dimension Partes provee una vista desnormalizada de las tablas origen  Partes, Linea y Categoria, dejando todo en una única dimensión para un modelo estrella', 
     @level0type = N'SCHEMA', 
     @level0name = N'Dimension', 
     @level1type = N'TABLE', 
     @level1name = N'Partes';
	GO

	EXEC sys.sp_addextendedproperty 
     @name = N'Desnormalizacion', 
     @value = N'La dimension Clientes provee una vista desnormalizada de las tabla clientes, dejando todo en una única dimensión para un modelo estrella', 
     @level0type = N'SCHEMA', 
     @level0name = N'Dimension', 
     @level1type = N'TABLE', 
     @level1name = N'Clientes';
	GO

	EXEC sys.sp_addextendedproperty 
     @name = N'Desnormalizacion', 
     @value = N'La dimension fecha es generada de forma automatica y no tiene datos origen, se puede regenerar enviando un rango de fechas al stored procedure USP_FillDimDate', 
     @level0type = N'SCHEMA', 
     @level0name = N'Dimension', 
     @level1type = N'TABLE', 
     @level1name = N'Fecha';
	GO

	EXEC sys.sp_addextendedproperty 
     @name = N'Desnormalizacion', 
     @value = N'La dimension Orden provee una vista desnormalizada de las tablas origen Orden, Detalle_Orden, Descuento y StatusOrden, dejando todo en una única dimensión para un modelo estrella', 
     @level0type = N'SCHEMA', 
     @level0name = N'Fact', 
     @level1type = N'TABLE', 
     @level1name = N'Orden';
	GO
--------------------------------------------------------------------------------------------
---------------------------------MODELADO LOGICO--------------------------------------------
--------------------------------------------------------------------------------------------
--Transformación en modelo lógico (mas detalles)

	--Fact
	ALTER TABLE Fact.Orden ADD ID_Orden [UDT_PK]
	ALTER TABLE Fact.Orden ADD ID_Cliente [UDT_PK]
    ALTER TABLE Fact.Orden ADD ID_StatusOrden [UDT_PK]
	ALTER TABLE Fact.Orden ADD ID_DetalleOrden [UDT_PK]
    ALTER TABLE Fact.Orden ADD ID_Descuento [UDT_PK]
    ALTER TABLE Fact.Orden ADD Total_Orden [UDT_Decimal6.2]
    ALTER TABLE Fact.Orden ADD PorcentajeDescuento [UDT_Decimal6.2]
    ALTER TABLE Fact.Orden ADD Cantidad INT
	ALTER TABLE Fact.Orden ADD NombreDescuento [UDT_VarcharMediano]
	ALTER TABLE Fact.Orden ADD NombreStatus [UDT_VarcharMediano]
	ALTER TABLE Fact.Orden ADD Fecha_Orden [UDT_DateTime]

--DimPartes
	ALTER TABLE Dimension.Partes ADD ID_Partes [UDT_PK]
	ALTER TABLE Dimension.Partes ADD ID_Categoria [UDT_PK]
	ALTER TABLE Dimension.Partes ADD ID_Linea [UDT_PK]
	ALTER TABLE Dimension.Partes ADD NombreParte [UDT_VarcharMediano]
	ALTER TABLE Dimension.Partes ADD DescripcionParte [UDT_VarcharMediano]
	ALTER TABLE Dimension.Partes ADD PrecioParte [UDT_Decimal6.2]
	ALTER TABLE Dimension.Partes ADD NombreCategoria [UDT_VarcharMediano]
	ALTER TABLE Dimension.Partes ADD DescripcionCategoria [UDT_VarcharMediano]
	ALTER TABLE Dimension.Partes ADD NombreLinea [UDT_VarcharMediano]
	ALTER TABLE Dimension.Partes ADD DescripcionLinea [UDT_VarcharMediano]

	--DimGeografia
	ALTER TABLE Dimension.Geografia ADD ID_Ciudad [UDT_PK]
	ALTER TABLE Dimension.Geografia ADD ID_Region [UDT_PK]
	ALTER TABLE Dimension.Geografia ADD ID_Pais [UDT_PK]
	ALTER TABLE Dimension.Geografia ADD NombreCiudad [UDT_VarcharCorto]
	ALTER TABLE Dimension.Geografia ADD CodigoPostal INT
	ALTER TABLE Dimension.Geografia ADD NombreRegion [UDT_VarcharCorto]
	ALTER TABLE Dimension.Geografia ADD NombrePais [UDT_VarcharCorto]

	--DimClientes
	ALTER TABLE Dimension.Clientes ADD ID_Cliente [UDT_PK]
	ALTER TABLE Dimension.Clientes ADD PrimerNombre [UDT_VarcharCorto]
	ALTER TABLE Dimension.Clientes ADD SegundoNombre [UDT_VarcharCorto]
	ALTER TABLE Dimension.Clientes ADD PrimerApellido [UDT_VarcharCorto]
	ALTER TABLE Dimension.Clientes ADD SegundoApellido [UDT_VarcharCorto]
	ALTER TABLE Dimension.Clientes ADD Genero [UDT_UnCaracter]
	ALTER TABLE Dimension.Clientes ADD Correo_Electronico [UDT_VarcharCorto]
	ALTER TABLE Dimension.Clientes ADD FechaNacimiento [UDT_DateTime]

	--DimFecha	
	ALTER TABLE Dimension.Fecha ADD [Date] DATE NOT NULL
    ALTER TABLE Dimension.Fecha ADD [Day] TINYINT NOT NULL
	ALTER TABLE Dimension.Fecha ADD [DaySuffix] CHAR(2) NOT NULL
	ALTER TABLE Dimension.Fecha ADD [Weekday] TINYINT NOT NULL
	ALTER TABLE Dimension.Fecha ADD [WeekDayName] VARCHAR(10) NOT NULL
	ALTER TABLE Dimension.Fecha ADD [WeekDayName_Short] CHAR(3) NOT NULL
	ALTER TABLE Dimension.Fecha ADD [WeekDayName_FirstLetter] CHAR(1) NOT NULL
	ALTER TABLE Dimension.Fecha ADD [DOWInMonth] TINYINT NOT NULL
	ALTER TABLE Dimension.Fecha ADD [DayOfYear] SMALLINT NOT NULL
	ALTER TABLE Dimension.Fecha ADD [WeekOfMonth] TINYINT NOT NULL
	ALTER TABLE Dimension.Fecha ADD [WeekOfYear] TINYINT NOT NULL
	ALTER TABLE Dimension.Fecha ADD [Month] TINYINT NOT NULL
	ALTER TABLE Dimension.Fecha ADD [MonthName] VARCHAR(10) NOT NULL
	ALTER TABLE Dimension.Fecha ADD [MonthName_Short] CHAR(3) NOT NULL
	ALTER TABLE Dimension.Fecha ADD [MonthName_FirstLetter] CHAR(1) NOT NULL
	ALTER TABLE Dimension.Fecha ADD [Quarter] TINYINT NOT NULL
	ALTER TABLE Dimension.Fecha ADD [QuarterName] VARCHAR(6) NOT NULL
	ALTER TABLE Dimension.Fecha ADD [Year] INT NOT NULL
	ALTER TABLE Dimension.Fecha ADD [MMYYYY] CHAR(6) NOT NULL
	ALTER TABLE Dimension.Fecha ADD [MonthYear] CHAR(7) NOT NULL
    ALTER TABLE Dimension.Fecha ADD IsWeekend BIT NOT NULL

--Indices Columnares
	CREATE NONCLUSTERED COLUMNSTORE INDEX [NCCS-rden] ON [Fact].[Orden]
	(
		[Total_Orden]
	)WITH (DROP_EXISTING = OFF, COMPRESSION_DELAY = 0)
	GO

--Queries para llenar datos
--Dimensiones
	--DimClientes
	INSERT INTO Dimension.Clientes
	(
		ID_Cliente,
		Genero,
		PrimerNombre,
		SegundoNombre,
		PrimerApellido,
		SegundoApellido,
		Correo_Electronico,
		FechaNacimiento
	)
	SELECT
		c.ID_Cliente,
		c.Genero,
		c.PrimerNombre,
		c.SegundoNombre,
		c.PrimerApellido,
		c.SegundoApellido,
		c.Correo_Electronico,
		c.FechaNacimiento
	FROM RepuestosWeb.dbo.Clientes as c
	
	SELECT * FROM Dimension.Clientes
	
	--DimGeografia
	INSERT INTO Dimension.Geografia
	(
		ID_Ciudad,
		ID_Region,
		ID_Pais,
		NombreCiudad,
		CodigoPostal,
		NombreRegion,
		NombrePais 
	)
	SELECT 
		c.ID_Ciudad,
		r.ID_Region,
		p.ID_Pais,
		c.Nombre,
		c.CodigoPostal,
		r.Nombre,
		p.Nombre
	FROM
	RepuestosWeb.dbo.Ciudad as c
	INNER JOIN RepuestosWeb.dbo.Region as r
		ON c.ID_Region = r.ID_Region
	INNER JOIN RepuestosWeb.dbo.Pais as p
		ON r.ID_Pais = p.ID_Pais

	Select * FROM Dimension.Geografia
	
	--DimPartes
	INSERT INTO Dimension.Partes
	(
		ID_Partes,
		ID_Categoria,
		ID_Linea,
		NombreParte,
		DescripcionParte,
		NombreCategoria,
		DescripcionCategoria,
		NombreLinea,
		DescripcionLinea,
		PrecioParte
	)
	SELECT 
		p.ID_Partes,
		c.ID_Categoria,
		l.ID_Linea,
		p.Nombre,
		p.Descripcion,
		c.Nombre,
		c.Descripcion,
		l.Nombre,
		l.Descripcion,
		p.Precio
	FROM 
		RepuestosWeb.dbo.Partes as p 
		INNER JOIN RepuestosWeb.dbo.Categoria as c 
			ON p.ID_Categoria = c.ID_Categoria
		INNER JOIN RepuestosWeb.dbo.Linea as l 
			ON c.ID_Linea = l.ID_Linea

	SELECT * FROM Dimension.Partes
--------------------------------------------------------------------------------------------
-----------------------CORRER CREATE de USP_FillDimDate PRIMERO!!!--------------------------
--------------------------------------------------------------------------------------------
CREATE PROCEDURE USP_FillDimDate @CurrentDate DATE = '2016-01-01', 
                                 @EndDate     DATE = '2022-12-31'
AS
    BEGIN
        SET NOCOUNT ON;
        DELETE FROM Dimension.Fecha;

        WHILE @CurrentDate < @EndDate
            BEGIN
                INSERT INTO Dimension.Fecha
                ([DateKey], 
                 [Date], 
                 [Day], 
                 [DaySuffix], 
                 [Weekday], 
                 [WeekDayName], 
                 [WeekDayName_Short], 
                 [WeekDayName_FirstLetter], 
                 [DOWInMonth], 
                 [DayOfYear], 
                 [WeekOfMonth], 
                 [WeekOfYear], 
                 [Month], 
                 [MonthName], 
                 [MonthName_Short], 
                 [MonthName_FirstLetter], 
                 [Quarter], 
                 [QuarterName], 
                 [Year], 
                 [MMYYYY], 
                 [MonthYear], 
                 [IsWeekend]
                )
                       SELECT DateKey = YEAR(@CurrentDate) * 10000 + MONTH(@CurrentDate) * 100 + DAY(@CurrentDate), 
                              DATE = @CurrentDate, 
                              Day = DAY(@CurrentDate), 
                              [DaySuffix] = CASE
                                                WHEN DAY(@CurrentDate) = 1
                                                     OR DAY(@CurrentDate) = 21
                                                     OR DAY(@CurrentDate) = 31
                                                THEN 'st'
                                                WHEN DAY(@CurrentDate) = 2
                                                     OR DAY(@CurrentDate) = 22
                                                THEN 'nd'
                                                WHEN DAY(@CurrentDate) = 3
                                                     OR DAY(@CurrentDate) = 23
                                                THEN 'rd'
                                                ELSE 'th'
                                            END, 
                              WEEKDAY = DATEPART(dw, @CurrentDate), 
                              WeekDayName = DATENAME(dw, @CurrentDate), 
                              WeekDayName_Short = UPPER(LEFT(DATENAME(dw, @CurrentDate), 3)), 
                              WeekDayName_FirstLetter = LEFT(DATENAME(dw, @CurrentDate), 1), 
                              [DOWInMonth] = DAY(@CurrentDate), 
                              [DayOfYear] = DATENAME(dy, @CurrentDate), 
                              [WeekOfMonth] = DATEPART(WEEK, @CurrentDate) - DATEPART(WEEK, DATEADD(MM, DATEDIFF(MM, 0, @CurrentDate), 0)) + 1, 
                              [WeekOfYear] = DATEPART(wk, @CurrentDate), 
                              [Month] = MONTH(@CurrentDate), 
                              [MonthName] = DATENAME(mm, @CurrentDate), 
                              [MonthName_Short] = UPPER(LEFT(DATENAME(mm, @CurrentDate), 3)), 
                              [MonthName_FirstLetter] = LEFT(DATENAME(mm, @CurrentDate), 1), 
                              [Quarter] = DATEPART(q, @CurrentDate), 
                              [QuarterName] = CASE
                                                  WHEN DATENAME(qq, @CurrentDate) = 1
                                                  THEN 'First'
                                                  WHEN DATENAME(qq, @CurrentDate) = 2
                                                  THEN 'second'
                                                  WHEN DATENAME(qq, @CurrentDate) = 3
                                                  THEN 'third'
                                                  WHEN DATENAME(qq, @CurrentDate) = 4
                                                  THEN 'fourth'
                                              END, 
                              [Year] = YEAR(@CurrentDate), 
                              [MMYYYY] = RIGHT('0' + CAST(MONTH(@CurrentDate) AS VARCHAR(2)), 2) + CAST(YEAR(@CurrentDate) AS VARCHAR(4)), 
                              [MonthYear] = CAST(YEAR(@CurrentDate) AS VARCHAR(4)) + UPPER(LEFT(DATENAME(mm, @CurrentDate), 3)), 
                              [IsWeekend] = CASE
                                                WHEN DATENAME(dw, @CurrentDate) = 'Sunday'
                                                     OR DATENAME(dw, @CurrentDate) = 'Saturday'
                                                THEN 1
                                                ELSE 0
                                            END     ;
                SET @CurrentDate = DATEADD(DD, 1, @CurrentDate);
            END;
    END;
go

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------


	DECLARE @FechaMaxima DATETIME=DATEADD(YEAR,2,GETDATE())
	--Fecha
	IF ISNULL((SELECT MAX(Date) FROM Dimension.Fecha),'1900-01-01')<@FechaMaxima
	begin
		EXEC USP_FillDimDate @CurrentDate = '2016-01-01', 
							 @EndDate     = @FechaMaxima
	end
	SELECT * FROM Dimension.Fecha
	
	--FACT Table
	INSERT INTO Fact.Orden 
	(
		SK_Clientes,
		SK_Geografia,
		SK_Partes,
		ID_Orden,
		ID_Cliente,
		ID_StatusOrden,
		ID_Descuento,
		ID_DetalleOrden,
		Total_Orden,
		PorcentajeDescuento,
		Cantidad,
		NombreDescuento,
		NombreStatus,
		Fecha_Orden,
		DateKey
	)
	SELECT 
		c.SK_Clientes,
		g.SK_Geografia,
		p.SK_Partes,
		o.ID_Orden,
		o.ID_Cliente,
		s.ID_StatusOrden,
		d.ID_Descuento,
		do.ID_DetalleOrden,
		o.Total_Orden,
		d.PorcentajeDescuento,
		do.Cantidad,
		d.NombreDescuento,
		s.NombreStatus,
		o.Fecha_Orden,
		f.DateKey
	FROM
	RepuestosWeb.dbo.Orden as o
	INNER JOIN RepuestosWeb.dbo.Detalle_orden as do
		ON(o.ID_Orden = do.ID_Orden)
	INNER JOIN RepuestosWeb.dbo.Descuento as d
		ON(do.ID_Descuento = d.ID_Descuento)
	INNER JOIN RepuestosWeb.dbo.StatusOrden as s 
		ON(o.ID_StatusOrden = s.ID_StatusOrden)
	--Referencias a DWH
	INNER JOIN Dimension.Clientes as c 
		ON(O.ID_Cliente = c.ID_Cliente)
	INNER JOIN Dimension.Geografia as g 
		ON(O.ID_Ciudad = g.ID_Ciudad)
	INNER JOIN Dimension.Partes as p 
		ON (do.ID_Partes = p.ID_Partes)
	INNER JOIN Dimension.Fecha as f 
		ON (CAST((CAST(YEAR(o.Fecha_Orden) AS VARCHAR(4)))+left('0'+CAST(MONTH(o.Fecha_Orden) AS VARCHAR(4)),2)+left('0'+(CAST(DAY(o.Fecha_Orden) AS VARCHAR(4))),2) AS INT) = f.DateKey)

	SELECT * FROM Fact.Orden
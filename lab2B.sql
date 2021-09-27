--Creamos tabla para log de fact batches
CREATE TABLE FactLog
(
	ID_Batch UNIQUEIDENTIFIER DEFAULT(NEWID()),
	FechaEjecucion DATETIME DEFAULT(GETDATE()),
	NuevosRegistros INT,
	CONSTRAINT [PK_FactLog] PRIMARY KEY
	(
		ID_Batch
	)
)
GO
--Agregamos FK
ALTER TABLE Fact.Orden ADD CONSTRAINT [FK_IDBatch] FOREIGN KEY (ID_Batch) 
REFERENCES Factlog(ID_Batch)
go

create schema [staging]
go

DROP TABLE IF EXISTS  [staging].[Orden]
GO

CREATE TABLE [staging].[Orden](
	[ID_Partes] [dbo].[UDT_PK] NULL,
	[ID_Ciudad] [dbo].[UDT_PK] NULL,
	[ID_Cliente] [dbo].[UDT_PK] NULL,	
	[ID_Orden] [dbo].[UDT_PK] NULL,
	[ID_DetalleOrden] [dbo].[UDT_PK] NULL,
	[ID_Descuento] [dbo].[UDT_PK] NULL,
	[ID_StatusOrden] [dbo].[UDT_PK] NULL,
	[Total_Orden] [dbo].[UDT_Decimal6.2] NULL,
	[Fecha_Orden] [dbo].[UDT_DateTime] NULL,
	[Cantidad] [int] NULL,
	[NombreDescuento] [dbo].[UDT_VarcharMediano] NULL,
	[PorcentajeDescuento] [dbo].[UDT_Decimal6.2] NULL,
	[NombreStatus] [dbo].[UDT_VarcharMediano] NULL,
) ON [PRIMARY]
GO

--Query para llenar datos en Staging
SELECT 
    [PR].[ID_Partes],
	[CI].[ID_Ciudad],
	[CL].[ID_Cliente],
	[O].[ID_Orden],
    [DO].[ID_DetalleOrden],
    [D].[ID_Descuento],
    [SO].[ID_StatusOrden],
    [O].[Total_Orden],
    [O].[Fecha_Orden],
    [DO].[Cantidad],
    [D].[NombreDescuento],
    [D].[PorcentajeDescuento],
    [SO].[NombreStatus]
FROM DBO.Orden O
     INNER JOIN DBO.Detalle_orden DO 
		ON O.ID_Orden = DO.ID_Orden
     INNER JOIN DBO.Descuento D 
		ON D.ID_Descuento = DO.ID_Descuento
     INNER JOIN DBO.StatusOrden SO 
		ON SO.ID_StatusOrden = O.ID_StatusOrden
	INNER JOIN DBO.Ciudad CI
		ON O.ID_Ciudad = CI.ID_Ciudad
	INNER JOIN DBO.Clientes CL
		ON O.ID_Ciudad = CL.ID_Cliente
	INNER JOIN DBO.Partes PR
		ON DO.ID_Partes = PR.ID_Partes
	WHERE ((FechaOrden>?)
GO

--Script de SP para MERGE
CREATE PROCEDURE USP_MergeFact
as
BEGIN

	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN
		DECLARE @NuevoGUIDInsert UNIQUEIDENTIFIER = NEWID(), @MaxFechaEjecucion DATETIME = GETDATE(), @RowsAffected INT

        -- Insert en factlog
		    INSERT INTO FactLog ([ID_Batch], [FechaEjecucion], [NuevosRegistros])
		    VALUES (@NuevoGUIDInsert,@MaxFechaEjecucion,NULL)
		-- Fin insert en factlog

        --Query de merge
		    MERGE [FACT].[ORDEN] AS FO
		    USING (
                SELECT
	                [PRT].[SK_Partes],
	                [GEO].[SK_Geografia],
	                [CLT].[SK_Clientes],
	                [F].[DateKey],
	                @NuevoGUIDINsert as ID_Batch,
	                'ssis' as ID_SourceSystem,
	                [O].[ID_Orden],
	                [O].[Total_Orden],
	                [O].[Fecha_Orden],
	                [O].[ID_StatusOrden],
	                [O].[NombreStatus],
	                [O].[ID_Descuento],
	                [O].[NombreDescuento],
	                [O].[PorcentajeDescuento],
	                [O].[ID_DetalleOrden],
	                [O].[Cantidad]
            		FROM [STAGING].[ORDEN] O
						INNER JOIN [Dimension].[Geografia] GEO 
							ON (O.Id_Ciudad = GEO.ID_Ciudad and O.Fecha_Orden BETWEEN GEO.FechaInicioValidez AND ISNULL(GEO.FechaFinValidez, '9999-12-31'))
						INNER JOIN [Dimension].[Clientes] CLT 
							ON (O.ID_Cliente = CLT.ID_Cliente and O.Fecha_Orden BETWEEN CLT.FechaInicioValidez AND ISNULL(CLT.FechaFinValidez, '9999-12-31'))
						INNER JOIN [Dimension].[Partes] PRT 
							ON (O.ID_Partes = PRT.ID_Partes and O.Fecha_Orden BETWEEN PRT.FechaInicioValidez AND ISNULL(PRT.FechaFinValidez, '9999-12-31'))	
						LEFT JOIN Dimension.Fecha F 
							ON(CAST( (CAST(YEAR(O.Fecha_Orden) AS VARCHAR(4)))+left('0'+CAST(MONTH(O.Fecha_Orden) AS VARCHAR(4)),2)+left('0'+(CAST(DAY(O.Fecha_Orden) AS VARCHAR(4))),2) AS INT)  = F.DateKey)
            ) AS SRC ON (SRC.ID_ORDEN = FO.ID_Orden)
        --Fin query de merge
        
        --Insertar cuando no existe
		    WHEN NOT MATCHED BY TARGET THEN
		    INSERT ([SK_Partes], [SK_Geografia], [SK_Clientes], [DateKey], [ID_Batch], [ID_SourceSystem], [ID_Orden], [Total_Orden], [Fecha_Orden], [ID_StatusOrden], [NombreStatus], [ID_Descuento], [NombreDescuento], [PorcentajeDescuento], [ID_DetalleOrden], [Cantidad])
		    VALUES (SRC.[SK_Partes], SRC.[SK_Geografia], SRC.[SK_Clientes], SRC.[DateKey], SRC.[ID_Batch], SRC.[ID_SourceSystem], SRC.[ID_Orden], SRC.[Total_Orden], SRC.[Fecha_Orden], SRC.[ID_StatusOrden], SRC.[NombreStatus], SRC.[ID_Descuento], SRC.[NombreDescuento], SRC.[PorcentajeDescuento], SRC.[ID_DetalleOrden], SRC.[Cantidad]);-- Fin Insertar cuando no existe
		-- Fin Inserta cuando no existe

		-- Obtiene la ultima fecha de ejecucion
		/*
        SET @RowsAffected =@@ROWCOUNT

		SELECT @MaxFechaEjecucion=MAX(MaxFechaEjecucion)
		FROM(
			SELECT MAX(Fecha_Orden) as MaxFechaEjecucion
			FROM FACT.Orden
			UNION
			SELECT MAX(FechaModificacionSource)  as MaxFechaEjecucion
			FROM FACT.Orden
		)AS A
		*/
		-- Fin obtiene la ultima fecha de ejecucion

		UPDATE FactLog
		SET NuevosRegistros=@RowsAffected, FechaEjecucion = @MaxFechaEjecucion
		WHERE ID_Batch = @NuevoGUIDInsert

		COMMIT
	END TRY
	BEGIN CATCH
		SELECT @@ERROR,'Ocurrio el siguiente error: '+ERROR_MESSAGE()
		IF (@@TRANCOUNT>0)
			ROLLBACK;
	END CATCH

END
go
EXEC USP_MergeFact
SELECT * FROM Fact.Orden
SELECT * FROM staging.Orden
SELECT * FROM FactLog
SELECT ISNULL(MAX(FechaEjecucion),'1900-01-01') AS UltimaFecha
	FROM Factlog
SELECT * FROM Dimension.Geografia

UPDATE Dimension.Geografia
set  FechaInicioValidez = '2000-01-01'
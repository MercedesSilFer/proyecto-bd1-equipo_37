-- =============================================================
-- ETAPA V - Índices: comparación de la búsqueda por período
-- Repite la misma consulta sin índice, con un índice agrupado y con
-- un índice no agrupado que incluye las columnas seleccionadas.
-- Requiere 01_carga_masiva.sql.
--
-- Para ver el plan en SSMS: Ctrl+M antes de ejecutar. Los tiempos y
-- las lecturas salen en la pestaña Mensajes. Cada consulta corre dos
-- veces: en frío (sin datos en memoria) y en caliente.
-- DBCC DROPCLEANBUFFERS vacía la memoria de datos de todo el servidor:
-- usar solo en un equipo de pruebas.
-- =============================================================

USE smarthome_store;
GO
SET NOCOUNT ON;
SET STATISTICS IO, TIME ON;
GO

-- === ESCENARIO 1: sin índice
-- Se quitan los índices de una ejecución anterior, para que el script se pueda repetir.
DROP INDEX IF EXISTS IX_venta_historica_fecha_cubre ON dbo.venta_historica;
DROP INDEX IF EXISTS IX_venta_historica_fecha ON dbo.venta_historica;
GO
CHECKPOINT;
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
GO
SELECT cod_venta, fecha_venta, importe FROM dbo.venta_historica WHERE fecha_venta >= '2025-01-01' AND fecha_venta < '2025-02-01';
GO
SELECT cod_venta, fecha_venta, importe FROM dbo.venta_historica WHERE fecha_venta >= '2025-01-01' AND fecha_venta < '2025-02-01';
GO

-- === ESCENARIO 2: índice agrupado sobre fecha_venta
CREATE CLUSTERED INDEX IX_venta_historica_fecha ON dbo.venta_historica (fecha_venta);
GO
CHECKPOINT;
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
GO
SELECT cod_venta, fecha_venta, importe FROM dbo.venta_historica WHERE fecha_venta >= '2025-01-01' AND fecha_venta < '2025-02-01';
GO
SELECT cod_venta, fecha_venta, importe FROM dbo.venta_historica WHERE fecha_venta >= '2025-01-01' AND fecha_venta < '2025-02-01';
GO

-- === ESCENARIO 3: índice no agrupado que incluye las columnas seleccionadas
-- SQL Server no admite INCLUDE en un índice agrupado, porque ese índice
-- ya contiene todas las columnas de la tabla.
DROP INDEX IX_venta_historica_fecha ON dbo.venta_historica;
GO
CREATE NONCLUSTERED INDEX IX_venta_historica_fecha_cubre ON dbo.venta_historica (fecha_venta) INCLUDE (cod_venta, importe);
GO
CHECKPOINT;
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
GO
SELECT cod_venta, fecha_venta, importe FROM dbo.venta_historica WHERE fecha_venta >= '2025-01-01' AND fecha_venta < '2025-02-01';
GO
SELECT cod_venta, fecha_venta, importe FROM dbo.venta_historica WHERE fecha_venta >= '2025-01-01' AND fecha_venta < '2025-02-01';
GO

SET STATISTICS IO, TIME OFF;
GO

-- Tamaño de la tabla y del índice que queda
SELECT i.name AS indice, i.type_desc AS tipo, SUM(s.used_page_count) AS paginas,
       SUM(s.used_page_count) * 8 / 1024 AS mb
FROM sys.dm_db_partition_stats s
JOIN sys.indexes i ON i.object_id = s.object_id AND i.index_id = s.index_id
WHERE s.object_id = OBJECT_ID('dbo.venta_historica')
GROUP BY i.name, i.type_desc;
GO

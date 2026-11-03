
-- Procedimientos: limpieza de los productos de los lotes
-- Elimina los productos "LOTE-A" y "LOTE-P" de 04_lote_insert_directo.sql y
-- 05_lote_via_procedimientos.sql, y restablece el contador de IDENTITY,
-- para dejar el catálogo como en la carga inicial.

USE smarthome_store;
GO
SET NOCOUNT ON;

DELETE FROM dbo.producto WHERE nombre LIKE 'LOTE-A %' OR nombre LIKE 'LOTE-P %';

DECLARE @max INT = (SELECT ISNULL(MAX(cod_producto), 0) FROM dbo.producto);
DBCC CHECKIDENT ('dbo.producto', RESEED, @max) WITH NO_INFOMSGS;

SELECT COUNT(*) AS productos FROM dbo.producto;
GO

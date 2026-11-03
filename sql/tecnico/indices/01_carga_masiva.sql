-- =============================================================
-- ETAPA V - Índices: carga masiva
-- Crea venta_historica, una tabla auxiliar sin índices, y le carga
-- un millón de ventas con fechas de 2021 a 2026. No forma parte del
-- modelo: se elimina con 03_limpieza.sql.
-- No se usa pedido porque ya tiene un índice agrupado en su clave
-- primaria y su trigger generaría un millón de filas de auditoría.
-- =============================================================

USE smarthome_store;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.venta_historica') IS NOT NULL
    DROP TABLE dbo.venta_historica;
GO

CREATE TABLE dbo.venta_historica
(
    cod_venta    INT           NOT NULL,
    fecha_venta  DATETIME      NOT NULL,
    cod_cliente  INT           NOT NULL,
    cod_producto INT           NOT NULL,
    cantidad     INT           NOT NULL,
    importe      DECIMAL(10,2) NOT NULL,
    observacion  VARCHAR(200)  NOT NULL
);
GO

-- Los valores se calculan a partir del número de fila, así la carga da
-- siempre los mismos datos. 189216000 segundos son 6 años.
WITH numeros AS
(
    SELECT TOP (1000000) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS BIGINT) AS i
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.venta_historica WITH (TABLOCK)
    (cod_venta, fecha_venta, cod_cliente, cod_producto, cantidad, importe, observacion)
SELECT i,
       DATEADD(SECOND, CAST((i * 2654435761) % 189216000 AS INT), '2021-01-01'),
       1 + i % 10,
       1 + (i * 7) % 10,
       1 + i % 5,
       1000 + (i * 13) % 100000,
       'Venta histórica de prueba para la comparación de índices ' + REPLICATE('-', 100)
FROM numeros;
GO

SELECT COUNT(*) AS filas, MIN(fecha_venta) AS primera, MAX(fecha_venta) AS ultima
FROM dbo.venta_historica;

-- Esperado: 0 índices (la tabla es un heap).
SELECT COUNT(*) AS indices
FROM sys.indexes
WHERE object_id = OBJECT_ID('dbo.venta_historica') AND type > 0;
GO

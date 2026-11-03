
-- Comparación de eficiencia: operaciones directas vs.
-- procedimientos y funciones almacenadas.

-- Todo el banco de pruebas corre dentro de una transacción que se
-- revierte, así que no deja datos. Los tiempos se guardan en una variable
-- de tabla (el ROLLBACK no la afecta). Requiere haber creado
-- usp_producto_insertar y dbo.fn_monto_pedido (carpeta funciones).
--
-- Recomendación: ejecutar el script DOS veces y registrar la segunda
-- (la primera incluye el costo de compilar los planes).

USE smarthome_store;
GO
SET NOCOUNT ON;

DECLARE @n INT = 2000, @i INT, @t0 DATETIME2(3), @nom VARCHAR(50), @id INT;
DECLARE @alic INT = (SELECT cod_alicuota FROM dbo.alicuota_iva WHERE porcentaje = 21.00);
DECLARE @cat  INT = (SELECT cod_categoria FROM dbo.categoria WHERE nombre = N'Accesorios');
DECLARE @res  TABLE (prueba VARCHAR(70), repeticiones INT, ms INT);

BEGIN TRANSACTION;

-- A) 2.000 INSERT directos, uno por uno ---------------------------------
SET @i = 1;
SET @t0 = SYSDATETIME();
WHILE @i <= @n
BEGIN
    SET @nom = CONCAT('BENCH-A ', @i);
    INSERT INTO dbo.producto (nombre, descripcion, precio_lista, cod_alicuota, stock, cod_categoria)
    VALUES (@nom, 'Prueba de eficiencia', 100.00, @alic, 1, @cat);
    SET @i += 1;
END;
INSERT INTO @res VALUES ('A) INSERT directo en bucle', @n, DATEDIFF(MILLISECOND, @t0, SYSDATETIME()));

-- B) 2.000 llamadas al procedimiento (con sus validaciones) -------------
SET @i = 1;
SET @t0 = SYSDATETIME();
WHILE @i <= @n
BEGIN
    SET @nom = CONCAT('BENCH-B ', @i);
    EXEC dbo.usp_producto_insertar @nombre = @nom, @descripcion = 'Prueba de eficiencia', @precio_lista = 100.00,
         @cod_alicuota = @alic, @stock = 1, @cod_categoria = @cat, @cod_producto = @id OUTPUT;
    SET @i += 1;
END;
INSERT INTO @res VALUES ('B) EXEC usp_producto_insertar en bucle', @n, DATEDIFF(MILLISECOND, @t0, SYSDATETIME()));

-- C) un único INSERT ... SELECT (operación por conjuntos) ---------------
SET @t0 = SYSDATETIME();
INSERT INTO dbo.producto (nombre, descripcion, precio_lista, cod_alicuota, stock, cod_categoria)
SELECT CONCAT('BENCH-C ', x.i), 'Prueba de eficiencia', 100.00, @alic, 1, @cat
FROM (SELECT TOP (@n) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
      FROM sys.all_objects a CROSS JOIN sys.all_objects b) AS x;
INSERT INTO @res VALUES ('C) INSERT ... SELECT (un solo comando)', @n, DATEDIFF(MILLISECOND, @t0, SYSDATETIME()));

ROLLBACK TRANSACTION;

-- Los identity avanzaron aunque se hizo ROLLBACK: se restablece el contador
DECLARE @max INT = (SELECT ISNULL(MAX(cod_producto), 0) FROM dbo.producto);
DECLARE @sql NVARCHAR(200) = N'DBCC CHECKIDENT (''dbo.producto'', RESEED, ' + CAST(@max AS NVARCHAR(12)) + N')';
EXEC (@sql);

-- D) función escalar vs. consulta directa --------------------------------
--    12 pedidos x 20.000 repeticiones = 240.000 cálculos del monto
SELECT TOP (20000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
INTO #nums
FROM sys.all_objects a CROSS JOIN sys.all_objects b;

DECLARE @acum DECIMAL(18, 2);

SET @t0 = SYSDATETIME();
SELECT @acum = SUM(dbo.fn_monto_pedido(p.cod_pedido))
FROM dbo.pedido p CROSS JOIN #nums;
INSERT INTO @res VALUES ('D) monto con función escalar fn_monto_pedido', 240000, DATEDIFF(MILLISECOND, @t0, SYSDATETIME()));

SET @t0 = SYSDATETIME();
SELECT @acum = SUM(t.monto)
FROM dbo.pedido p
CROSS JOIN #nums
CROSS APPLY (SELECT SUM(d.cantidad * d.precio_unitario_venta) AS monto
             FROM dbo.detalle_pedido d
             WHERE d.cod_pedido = p.cod_pedido) AS t;
INSERT INTO @res VALUES ('E) monto con subconsulta directa (CROSS APPLY)', 240000, DATEDIFF(MILLISECOND, @t0, SYSDATETIME()));

DROP TABLE #nums;

SELECT prueba, repeticiones, ms FROM @res;
GO

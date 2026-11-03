-- =====================================================================
-- Etapa V - Transacciones: pruebas con T-SQL explícito (sin procedimiento)
-- SmartHome Store (equipo 37) - SQL Server
--
-- Tarea de la cátedra: transacción que inserta un registro en una tabla,
-- otro en una segunda tabla y actualiza registros de una tercera; los
-- datos solo se confirman si TODA la operación termina bien.
--
--   Prueba A  operación exitosa                      -> COMMIT
--   Prueba B  error provocado después del INSERT     -> ROLLBACK, sin cambios
--   Prueba C  stock insuficiente (error de negocio)  -> ROLLBACK, sin cambios
--   Prueba D  el MISMO error SIN transacción         -> quedan datos a medias
--
-- Cada prueba muestra el estado ANTES y DESPUÉS (pedidos, líneas y stock).
-- Los datos creados por A y D se eliminan con 99_limpieza_demo.sql.
-- Requiere: dbo.fn_precio_con_iva (carpeta funciones).
-- =====================================================================
USE smarthome_store;
GO
SET NOCOUNT ON;

-- ============================ PRUEBA A: éxito ========================
DECLARE @cod_cliente INT = 1, @cod_metodo_pago INT = 1, @cod_producto INT = 2, @cantidad INT = 1;
DECLARE @cod_pedido INT, @precio DECIMAL(10, 2), @alicuota DECIMAL(4, 2);

SELECT @precio = dbo.fn_precio_con_iva(p.cod_producto), @alicuota = a.porcentaje
FROM dbo.producto p JOIN dbo.alicuota_iva a ON a.cod_alicuota = p.cod_alicuota
WHERE p.cod_producto = @cod_producto;

SELECT 'PRUEBA A - ANTES' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;

SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

        INSERT INTO dbo.pedido (calle, numero, ciudad, provincia, cod_postal, cod_cliente, cod_metodo_pago, estado)
        SELECT dir.calle, dir.numero, loc.nombre, prov.nombre, dir.cod_postal, c.cod_cliente, @cod_metodo_pago, 'confirmado'
        FROM dbo.cliente c
        JOIN dbo.direccion dir ON dir.cod_cliente = c.cod_cliente AND dir.principal = 1
        JOIN dbo.localidad loc ON loc.cod_localidad = dir.cod_localidad
        JOIN dbo.provincia prov ON prov.cod_provincia = loc.cod_provincia
        WHERE c.cod_cliente = @cod_cliente;
        SET @cod_pedido = SCOPE_IDENTITY();

        INSERT INTO dbo.detalle_pedido (item, precio_unitario_venta, cantidad, alicuota_iva, iva_monto, cod_pedido, cod_producto)
        VALUES (1, @precio, @cantidad, @alicuota,
                ROUND(@cantidad * @precio * @alicuota / (100 + @alicuota), 2), @cod_pedido, @cod_producto);

        UPDATE dbo.producto SET stock = stock - @cantidad
        WHERE cod_producto = @cod_producto AND stock >= @cantidad;
        IF @@ROWCOUNT = 0
            THROW 50211, 'Stock insuficiente: se revierte toda la operación.', 1;

    COMMIT TRANSACTION;
    PRINT 'PRUEBA A: COMMIT. Pedido ' + CAST(@cod_pedido AS VARCHAR(10)) + ' registrado.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'PRUEBA A: ROLLBACK. Motivo: ' + ERROR_MESSAGE();
END CATCH;

SELECT 'PRUEBA A - DESPUÉS' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;
GO

-- ================ PRUEBA B: error provocado después del INSERT ========
SET NOCOUNT ON;
DECLARE @cod_cliente INT = 1, @cod_metodo_pago INT = 1, @cod_producto INT = 2, @cantidad INT = 1;
DECLARE @cod_pedido INT, @precio DECIMAL(10, 2), @alicuota DECIMAL(4, 2);

SELECT @precio = dbo.fn_precio_con_iva(p.cod_producto), @alicuota = a.porcentaje
FROM dbo.producto p JOIN dbo.alicuota_iva a ON a.cod_alicuota = p.cod_alicuota
WHERE p.cod_producto = @cod_producto;

SELECT 'PRUEBA B - ANTES' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;

SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

        INSERT INTO dbo.pedido (calle, numero, ciudad, provincia, cod_postal, cod_cliente, cod_metodo_pago, estado)
        SELECT dir.calle, dir.numero, loc.nombre, prov.nombre, dir.cod_postal, c.cod_cliente, @cod_metodo_pago, 'confirmado'
        FROM dbo.cliente c
        JOIN dbo.direccion dir ON dir.cod_cliente = c.cod_cliente AND dir.principal = 1
        JOIN dbo.localidad loc ON loc.cod_localidad = dir.cod_localidad
        JOIN dbo.provincia prov ON prov.cod_provincia = loc.cod_provincia
        WHERE c.cod_cliente = @cod_cliente;
        SET @cod_pedido = SCOPE_IDENTITY();

        -- >>> ERROR PROVOCADO INTENCIONALMENTE (también serviría: SELECT 1 / 0;)
        THROW 50299, 'Error provocado intencionalmente después del INSERT.', 1;

        INSERT INTO dbo.detalle_pedido (item, precio_unitario_venta, cantidad, alicuota_iva, iva_monto, cod_pedido, cod_producto)
        VALUES (1, @precio, @cantidad, @alicuota,
                ROUND(@cantidad * @precio * @alicuota / (100 + @alicuota), 2), @cod_pedido, @cod_producto);

        UPDATE dbo.producto SET stock = stock - @cantidad WHERE cod_producto = @cod_producto;

    COMMIT TRANSACTION;
    PRINT 'PRUEBA B: COMMIT (no debería llegar acá).';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'PRUEBA B: ROLLBACK. Motivo: ' + ERROR_MESSAGE();
END CATCH;

SELECT 'PRUEBA B - DESPUÉS' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;
GO

-- ================== PRUEBA C: stock insuficiente =====================
SET NOCOUNT ON;
DECLARE @cod_cliente INT = 1, @cod_metodo_pago INT = 1, @cod_producto INT = 2, @cantidad INT = 9999;
DECLARE @cod_pedido INT, @precio DECIMAL(10, 2), @alicuota DECIMAL(4, 2);

SELECT @precio = dbo.fn_precio_con_iva(p.cod_producto), @alicuota = a.porcentaje
FROM dbo.producto p JOIN dbo.alicuota_iva a ON a.cod_alicuota = p.cod_alicuota
WHERE p.cod_producto = @cod_producto;

SELECT 'PRUEBA C - ANTES' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;

SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

        INSERT INTO dbo.pedido (calle, numero, ciudad, provincia, cod_postal, cod_cliente, cod_metodo_pago, estado)
        SELECT dir.calle, dir.numero, loc.nombre, prov.nombre, dir.cod_postal, c.cod_cliente, @cod_metodo_pago, 'confirmado'
        FROM dbo.cliente c
        JOIN dbo.direccion dir ON dir.cod_cliente = c.cod_cliente AND dir.principal = 1
        JOIN dbo.localidad loc ON loc.cod_localidad = dir.cod_localidad
        JOIN dbo.provincia prov ON prov.cod_provincia = loc.cod_provincia
        WHERE c.cod_cliente = @cod_cliente;
        SET @cod_pedido = SCOPE_IDENTITY();

        INSERT INTO dbo.detalle_pedido (item, precio_unitario_venta, cantidad, alicuota_iva, iva_monto, cod_pedido, cod_producto)
        VALUES (1, @precio, @cantidad, @alicuota,
                ROUND(@cantidad * @precio * @alicuota / (100 + @alicuota), 2), @cod_pedido, @cod_producto);

        UPDATE dbo.producto SET stock = stock - @cantidad
        WHERE cod_producto = @cod_producto AND stock >= @cantidad;
        IF @@ROWCOUNT = 0
            THROW 50211, 'Stock insuficiente: se revierte toda la operación.', 1;

    COMMIT TRANSACTION;
    PRINT 'PRUEBA C: COMMIT (no debería llegar acá).';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'PRUEBA C: ROLLBACK. Motivo: ' + ERROR_MESSAGE();
END CATCH;

SELECT 'PRUEBA C - DESPUÉS' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;
GO

-- ========== PRUEBA D (contraste): el mismo error SIN transacción ======
-- Sin BEGIN TRANSACTION cada INSERT se confirma por separado: al fallar el
-- paso siguiente queda un pedido SIN detalle y con el stock sin descontar
-- (datos inconsistentes). Se limpia con 99_limpieza_demo.sql.
SET NOCOUNT ON;
SET XACT_ABORT OFF;
DECLARE @cod_cliente INT = 1, @cod_metodo_pago INT = 1, @cod_producto INT = 2;
DECLARE @cod_pedido INT;

SELECT 'PRUEBA D - ANTES' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;

BEGIN TRY
    INSERT INTO dbo.pedido (calle, numero, ciudad, provincia, cod_postal, cod_cliente, cod_metodo_pago, estado)
    SELECT dir.calle, dir.numero, loc.nombre, prov.nombre, dir.cod_postal, c.cod_cliente, @cod_metodo_pago, 'confirmado'
    FROM dbo.cliente c
    JOIN dbo.direccion dir ON dir.cod_cliente = c.cod_cliente AND dir.principal = 1
    JOIN dbo.localidad loc ON loc.cod_localidad = dir.cod_localidad
    JOIN dbo.provincia prov ON prov.cod_provincia = loc.cod_provincia
    WHERE c.cod_cliente = @cod_cliente;
    SET @cod_pedido = SCOPE_IDENTITY();

    THROW 50299, 'Error provocado intencionalmente después del INSERT.', 1;
END TRY
BEGIN CATCH
    PRINT 'PRUEBA D: error SIN transacción. Motivo: ' + ERROR_MESSAGE();
END CATCH;

SELECT 'PRUEBA D - DESPUÉS (pedido huérfano)' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;
GO

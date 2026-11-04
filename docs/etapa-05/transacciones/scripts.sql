-- =============================================================
-- ETAPA V - Tema 2: Transacciones
-- =============================================================

USE smarthome_store;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- =============================================================
-- T1. Transacción exitosa con COMMIT
-- Se abre una transacción explícita, se registra la venta y se
-- confirma con COMMIT. Después se limpia el pedido de prueba
-- (en otra transacción) para no alterar los datos de las etapas
-- anteriores.
-- =============================================================

BEGIN TRY
    BEGIN TRANSACTION;

        DECLARE @items1 dbo.tipo_items_pedido;
        DECLARE @nuevo1 INT;

        INSERT INTO @items1 (cod_producto, cantidad) VALUES (2, 1);

        SELECT 'ANTES' AS momento, cod_producto, stock
        FROM producto WHERE cod_producto = 2;

        EXEC dbo.sp_registrar_venta_completa
             @cod_cliente     = 1,
             @cod_metodo_pago = 1,
             @ref_transaccion = 'TX-T1-COMMIT',
             @items           = @items1,
             @cod_pedido      = @nuevo1 OUTPUT;

    COMMIT TRANSACTION;

    SELECT 'DESPUES DEL COMMIT' AS momento, cod_producto, stock
    FROM producto WHERE cod_producto = 2;

    SELECT cod_pedido, estado, estado_pago, ref_transaccion
    FROM pedido WHERE cod_pedido = @nuevo1;

    SELECT dbo.fn_total_pedido(@nuevo1) AS total_pedido;

    -- Limpieza: se elimina el pedido (el detalle cae por CASCADE)
    -- y se repone el stock, en otra transacción.
    BEGIN TRANSACTION;
        DELETE FROM pedido WHERE cod_pedido = @nuevo1;
        UPDATE producto SET stock = stock + 1 WHERE cod_producto = 2;
    COMMIT TRANSACTION;

    SELECT 'TRAS LA LIMPIEZA' AS momento, cod_producto, stock
    FROM producto WHERE cod_producto = 2;

    SELECT COUNT(*) AS pedido_existe FROM pedido WHERE cod_pedido = @nuevo1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;
GO

-- =============================================================
-- T2. Transacción fallida: ROLLBACK por stock insuficiente
-- Se intentan vender 6 lavarropas y hay 5. El procedimiento
-- lanza el error 50005 y el CATCH revierte todo.
-- =============================================================

DECLARE @pedidos_antes2 INT = (SELECT COUNT(*) FROM pedido);
DECLARE @stock_antes2   INT = (SELECT stock FROM producto WHERE cod_producto = 8);

BEGIN TRY
    BEGIN TRANSACTION;

        DECLARE @items2 dbo.tipo_items_pedido;
        DECLARE @nuevo2 INT;

        INSERT INTO @items2 (cod_producto, cantidad) VALUES (8, 6);

        EXEC dbo.sp_registrar_venta_completa
             @cod_cliente     = 1,
             @cod_metodo_pago = 1,
             @ref_transaccion = 'TX-T2-ROLLBACK',
             @items           = @items2,
             @cod_pedido      = @nuevo2 OUTPUT;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;

SELECT @pedidos_antes2 AS pedidos_antes, COUNT(*) AS pedidos_despues FROM pedido;
SELECT @stock_antes2 AS stock_antes,
       (SELECT stock FROM producto WHERE cod_producto = 8) AS stock_despues;
SELECT @@TRANCOUNT AS transacciones_abiertas;
GO

-- =============================================================
-- T3. Atomicidad con varias sentencias
-- Se inserta un pedido y un detalle válido; después, un detalle
-- inválido (cantidad = 0) que viola CK_detalle_pedido_cantidad.
-- El CATCH revierte las tres sentencias: no queda nada.
-- =============================================================

DECLARE @pedidos_antes3  INT = (SELECT COUNT(*) FROM pedido);
DECLARE @detalles_antes3 INT = (SELECT COUNT(*) FROM detalle_pedido);

BEGIN TRY
    BEGIN TRANSACTION;

        INSERT INTO pedido
            (estado, estado_pago, calle, numero, ciudad, provincia, cod_postal,
             cod_cliente, cod_metodo_pago)
        SELECT 'pendiente', 'pendiente', dir.calle, dir.numero, loc.nombre, prov.nombre, dir.cod_postal,
               c.cod_cliente, 1
        FROM cliente c
        INNER JOIN direccion dir ON dir.cod_cliente = c.cod_cliente AND dir.principal = 1
        INNER JOIN localidad loc ON loc.cod_localidad = dir.cod_localidad
        INNER JOIN provincia prov ON prov.cod_provincia = loc.cod_provincia
        WHERE c.cod_cliente = 1;

        DECLARE @cod3 INT = SCOPE_IDENTITY();

        INSERT INTO detalle_pedido
            (cod_pedido, cod_producto, item, cantidad,
             precio_unitario_venta, alicuota_iva, iva_monto)
        VALUES (@cod3, 2, 1, 1, 25000.00, 21.00, 4338.84);

        -- Falla a propósito: cantidad = 0
        INSERT INTO detalle_pedido
            (cod_pedido, cod_producto, item, cantidad,
             precio_unitario_venta, alicuota_iva, iva_monto)
        VALUES (@cod3, 4, 2, 0, 8000.00, 21.00, 1388.43);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;

SELECT @pedidos_antes3 AS pedidos_antes, COUNT(*) AS pedidos_despues FROM pedido;
SELECT @detalles_antes3 AS detalles_antes, COUNT(*) AS detalles_despues FROM detalle_pedido;
GO

-- =============================================================
-- T4. Punto de guardado (SAVE TRANSACTION)
-- Se guarda un punto, se inserta un detalle y se vuelve al punto:
-- el detalle desaparece pero el pedido sigue existiendo.
-- Después se revierte todo para no dejar datos.
-- =============================================================

BEGIN TRY
    BEGIN TRANSACTION;

        INSERT INTO pedido
            (estado, estado_pago, calle, numero, ciudad, provincia, cod_postal,
             cod_cliente, cod_metodo_pago)
        SELECT 'pendiente', 'pendiente', dir.calle, dir.numero, loc.nombre, prov.nombre, dir.cod_postal,
               c.cod_cliente, 1
        FROM cliente c
        INNER JOIN direccion dir ON dir.cod_cliente = c.cod_cliente AND dir.principal = 1
        INNER JOIN localidad loc ON loc.cod_localidad = dir.cod_localidad
        INNER JOIN provincia prov ON prov.cod_provincia = loc.cod_provincia
        WHERE c.cod_cliente = 1;

        DECLARE @cod4 INT = SCOPE_IDENTITY();

        SAVE TRANSACTION punto_detalle;

        INSERT INTO detalle_pedido
            (cod_pedido, cod_producto, item, cantidad,
             precio_unitario_venta, alicuota_iva, iva_monto)
        VALUES (@cod4, 2, 1, 1, 25000.00, 21.00, 4338.84);

        SELECT 'CON DETALLE' AS momento,
               (SELECT COUNT(*) FROM detalle_pedido WHERE cod_pedido = @cod4) AS renglones;

        ROLLBACK TRANSACTION punto_detalle;

        SELECT 'TRAS ROLLBACK AL PUNTO' AS momento,
               (SELECT COUNT(*) FROM detalle_pedido WHERE cod_pedido = @cod4) AS renglones,
               (SELECT COUNT(*) FROM pedido WHERE cod_pedido = @cod4) AS pedido_existe;

    ROLLBACK TRANSACTION;   -- se revierte todo

    SELECT 'TRAS ROLLBACK TOTAL' AS momento,
           (SELECT COUNT(*) FROM pedido WHERE cod_pedido = @cod4) AS pedido_existe;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;
GO

-- =============================================================
-- T5. Transacción del llamador
-- Se abre una transacción, se ejecuta la venta y se revierte
-- desde afuera. El stock vuelve a su valor original: eso prueba
-- que el procedimiento respetó la transacción del llamador
-- (@tran_propia) y no confirmó por su cuenta.
-- =============================================================

DECLARE @stock_antes5 INT = (SELECT stock FROM producto WHERE cod_producto = 2);

BEGIN TRY
    BEGIN TRANSACTION;

        DECLARE @items5 dbo.tipo_items_pedido;
        DECLARE @nuevo5 INT;

        INSERT INTO @items5 (cod_producto, cantidad) VALUES (2, 1);

        EXEC dbo.sp_registrar_venta_completa
             @cod_cliente     = 1,
             @cod_metodo_pago = 1,
             @ref_transaccion = 'TX-T5-EXTERNA',
             @items           = @items5,
             @cod_pedido      = @nuevo5 OUTPUT;

        SELECT 'DENTRO DE LA TRANSACCION' AS momento,
               @@TRANCOUNT AS tran_count,
               (SELECT stock FROM producto WHERE cod_producto = 2) AS stock;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;

SELECT 'DESPUES DEL ROLLBACK' AS momento,
       @stock_antes5 AS stock_antes,
       (SELECT stock FROM producto WHERE cod_producto = 2) AS stock_despues,
       @@TRANCOUNT AS tran_count;
GO

-- =============================================================
-- T6. Cancelación de un pedido
-- El estado y el stock cambian juntos: si se cancela un pedido
-- confirmado, sus unidades vuelven al stock en la misma transacción
-- (RN.30). Un pedido pendiente todavía no descontó stock.
-- No se puede cancelar un pedido facturado o ya despachado.
--
-- Códigos de error propios:
--   50008 pedido inexistente
--   50009 el pedido ya está cancelado
--   50010 el pedido ya tiene factura
--   50011 el pedido ya fue despachado o entregado
-- =============================================================

CREATE OR ALTER PROCEDURE dbo.sp_cancelar_pedido
    @cod_pedido INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Si quien llama ya abrió una transacción, no se abre otra.
    DECLARE @tran_propia BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @estado VARCHAR(20), @estado_envio VARCHAR(20);

    BEGIN TRY
        IF @tran_propia = 1 BEGIN TRANSACTION;

        SELECT @estado = estado, @estado_envio = estado_envio
        FROM dbo.pedido WITH (UPDLOCK, HOLDLOCK)
        WHERE cod_pedido = @cod_pedido;

        IF @estado IS NULL
            THROW 50008, 'Pedido inexistente.', 1;

        IF @estado = 'cancelado'
            THROW 50009, 'El pedido ya está cancelado.', 1;

        IF EXISTS (SELECT 1 FROM dbo.factura WHERE cod_pedido = @cod_pedido)
            THROW 50010, 'El pedido ya tiene factura: no se puede cancelar.', 1;

        IF @estado_envio IN ('despachado', 'entregado')
            THROW 50011, 'El pedido ya fue despachado o entregado: no se puede cancelar.', 1;

        IF @estado = 'confirmado'
            UPDATE p
            SET p.stock = p.stock + d.cantidad
            FROM dbo.producto p
            INNER JOIN dbo.detalle_pedido d ON d.cod_producto = p.cod_producto
            WHERE d.cod_pedido = @cod_pedido;

        UPDATE dbo.pedido
        SET estado = 'cancelado', estado_envio = NULL
        WHERE cod_pedido = @cod_pedido;

        IF @tran_propia = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @tran_propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- T6a. Cancelar un pedido confirmado: el stock vuelve a su valor.
-- Esperado: stock 40 -> 39 con la venta y 40 con la cancelación; todo
-- se revierte al final, para no alterar los datos de prueba.
BEGIN TRY
    BEGIN TRANSACTION;

        DECLARE @items6 dbo.tipo_items_pedido;
        DECLARE @nuevo6 INT;

        INSERT INTO @items6 (cod_producto, cantidad) VALUES (2, 1);

        SELECT 'ANTES DE LA VENTA' AS momento, stock FROM producto WHERE cod_producto = 2;

        EXEC dbo.sp_registrar_venta_completa
             @cod_cliente     = 1,
             @cod_metodo_pago = 1,
             @ref_transaccion = 'TX-T6-CANCELA',
             @items           = @items6,
             @cod_pedido      = @nuevo6 OUTPUT;

        SELECT 'TRAS LA VENTA' AS momento, stock FROM producto WHERE cod_producto = 2;

        EXEC dbo.sp_cancelar_pedido @cod_pedido = @nuevo6;

        SELECT 'TRAS LA CANCELACION' AS momento, stock FROM producto WHERE cod_producto = 2;
        SELECT estado, estado_pago FROM pedido WHERE cod_pedido = @nuevo6;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;
GO

-- T6b. Cancelar un pedido pendiente: no cambia el stock.
-- Esperado: pedido 10 cancelado y la misma suma de stock.
BEGIN TRY
    BEGIN TRANSACTION;

        SELECT 'ANTES' AS momento, SUM(stock) AS stock_total FROM producto;

        EXEC dbo.sp_cancelar_pedido @cod_pedido = 10;

        SELECT 'DESPUES' AS momento, SUM(stock) AS stock_total FROM producto;
        SELECT estado FROM pedido WHERE cod_pedido = 10;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;
GO

-- T6c. Pedido inexistente. Esperado: error 50008.
BEGIN TRY
    EXEC dbo.sp_cancelar_pedido @cod_pedido = 999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;
GO

-- T6d. Pedido ya cancelado (el 11). Esperado: error 50009.
BEGIN TRY
    EXEC dbo.sp_cancelar_pedido @cod_pedido = 11;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;
GO

-- T6e. Pedido con factura (el 1). Esperado: error 50010 y estado sin cambios.
BEGIN TRY
    EXEC dbo.sp_cancelar_pedido @cod_pedido = 1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;

SELECT cod_pedido, estado FROM pedido WHERE cod_pedido = 1;
GO

-- T6f. Pedido despachado. Esperado: error 50011 y stock 40 tras revertir.
BEGIN TRY
    BEGIN TRANSACTION;

        DECLARE @items7 dbo.tipo_items_pedido;
        DECLARE @nuevo7 INT;

        INSERT INTO @items7 (cod_producto, cantidad) VALUES (2, 1);

        EXEC dbo.sp_registrar_venta_completa
             @cod_cliente     = 1,
             @cod_metodo_pago = 1,
             @ref_transaccion = 'TX-T6-DESPACHO',
             @items           = @items7,
             @cod_pedido      = @nuevo7 OUTPUT;

        UPDATE pedido SET estado_envio = 'despachado' WHERE cod_pedido = @nuevo7;

        EXEC dbo.sp_cancelar_pedido @cod_pedido = @nuevo7;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;

SELECT cod_producto, stock FROM producto WHERE cod_producto = 2;
SELECT COUNT(*) AS pedidos, (SELECT COUNT(*) FROM detalle_pedido) AS detalles FROM pedido;
GO

-- #############################################################
-- PARTE 2: COMPLEMENTO - TRANSACCION EXPLICITA, ANIDAMIENTO Y COMPRAS
-- (se agrega a T1-T6; no los reemplaza)
-- #############################################################
-- Objetos y pruebas:
--   T7  a T10   transaccion explicita (sin procedimiento) sobre pedido,
--               detalle_pedido y producto; T10 es el contraste SIN transaccion
--   T11 a T13   transacciones anidadas y puntos de recuperacion
--   usp_confirmar_compra   pasa una compra de pendiente a recibida y suma
--                          el stock (RN.20, RN.09)
--   T14 a T16   pruebas de usp_confirmar_compra
--
-- Codigos de error propios: 50211 (T7-T9), 50221 (usp_confirmar_compra) y
-- 50299 (error provocado a proposito en T8 y T10). No se superponen con los
-- 50001-50011 ni con los 50101-50121 de los otros scripts.
-- Las pruebas que modifican datos (T7, T10) los eliminan al final; el resto
-- termina en ROLLBACK. Si una prueba se interrumpe a mitad de camino, se
-- puede usar 99_limpieza_demo.sql.

USE smarthome_store;
GO

-- =============================================================
-- T7. Transaccion explicita exitosa (sin procedimiento)
-- Caso: una transaccion que inserta un registro en una
-- tabla (pedido), otro en una segunda tabla (detalle_pedido) y actualiza
-- registros de una tercera (producto). Los datos solo se confirman si TODA
-- la operacion termina bien. Despues se limpia el pedido de prueba (en otra
-- transaccion) para no alterar los datos de las etapas anteriores.
-- Esperado: pedidos 12 -> 13, lineas 18 -> 19, stock del producto 2: 40 -> 39;
--           tras la limpieza vuelve a 12, 18 y 40.
-- =============================================================

SET NOCOUNT ON;
DECLARE @cod_cliente INT = 1, @cod_metodo_pago INT = 1, @cod_producto INT = 2, @cantidad INT = 1;
DECLARE @cod_pedido INT, @precio DECIMAL(10, 2), @alicuota DECIMAL(4, 2);

-- Precio final (IVA y descuento vigente, RN.19 y RN.24) y alicuota del producto
SELECT @precio = dbo.fn_precio_final(p.cod_producto, GETDATE()), @alicuota = a.porcentaje
FROM dbo.producto p
INNER JOIN dbo.alicuota_iva a ON a.cod_alicuota = p.cod_alicuota
WHERE p.cod_producto = @cod_producto;

SELECT 'T7 - ANTES' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;

SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

        INSERT INTO dbo.pedido
            (estado, estado_pago, ref_transaccion,
             calle, numero, ciudad, provincia, cod_postal,
             cod_cliente, cod_metodo_pago)
        SELECT 'confirmado', 'aprobado', 'TX-T7-COMMIT',
               dir.calle, dir.numero, loc.nombre, prov.nombre, dir.cod_postal,
               c.cod_cliente, @cod_metodo_pago
        FROM dbo.cliente c
        INNER JOIN dbo.direccion dir ON dir.cod_cliente = c.cod_cliente AND dir.principal = 1
        INNER JOIN dbo.localidad loc ON loc.cod_localidad = dir.cod_localidad
        INNER JOIN dbo.provincia prov ON prov.cod_provincia = loc.cod_provincia
        WHERE c.cod_cliente = @cod_cliente;
        SET @cod_pedido = SCOPE_IDENTITY();

        INSERT INTO dbo.detalle_pedido
            (cod_pedido, cod_producto, item, cantidad,
             precio_unitario_venta, alicuota_iva, iva_monto)
        VALUES (@cod_pedido, @cod_producto, 1, @cantidad, @precio, @alicuota,
                ROUND(@cantidad * @precio * @alicuota / (100 + @alicuota), 2));

        -- La condicion "stock >= cantidad" evita stock negativo (RN.11)
        UPDATE dbo.producto SET stock = stock - @cantidad
        WHERE cod_producto = @cod_producto AND stock >= @cantidad;
        IF @@ROWCOUNT = 0
            THROW 50211, 'Stock insuficiente: se revierte toda la operacion.', 1;

    COMMIT TRANSACTION;
    PRINT 'T7: COMMIT. Pedido ' + CAST(@cod_pedido AS VARCHAR(10)) + ' registrado.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'T7: ROLLBACK. Motivo: ' + ERROR_MESSAGE();
END CATCH;

SELECT 'T7 - DESPUES DEL COMMIT' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;

-- Limpieza: se elimina el pedido (el detalle cae por CASCADE) y se repone el stock
IF EXISTS (SELECT 1 FROM dbo.pedido WHERE cod_pedido = @cod_pedido)
BEGIN
    BEGIN TRANSACTION;
        DELETE FROM dbo.pedido WHERE cod_pedido = @cod_pedido;
        UPDATE dbo.producto SET stock = stock + @cantidad WHERE cod_producto = @cod_producto;
    COMMIT TRANSACTION;
END;

SELECT 'T7 - TRAS LA LIMPIEZA' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;
GO

-- =============================================================
-- T8. Error provocado despues del primer INSERT -> ROLLBACK
-- Se inserta el pedido y despues se lanza un error a proposito. El CATCH
-- revierte todo: no queda ni el pedido ni cambios de stock.
-- Esperado: error 50299; pedidos 12, lineas 18 y stock 40, antes y despues.
-- =============================================================

SET NOCOUNT ON;
DECLARE @cod_cliente INT = 1, @cod_metodo_pago INT = 1, @cod_producto INT = 2, @cantidad INT = 1;
DECLARE @cod_pedido INT, @precio DECIMAL(10, 2), @alicuota DECIMAL(4, 2);

-- Precio final (IVA y descuento vigente, RN.19 y RN.24) y alicuota del producto
SELECT @precio = dbo.fn_precio_final(p.cod_producto, GETDATE()), @alicuota = a.porcentaje
FROM dbo.producto p
INNER JOIN dbo.alicuota_iva a ON a.cod_alicuota = p.cod_alicuota
WHERE p.cod_producto = @cod_producto;

SELECT 'T8 - ANTES' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;

SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

        INSERT INTO dbo.pedido
            (estado, estado_pago, ref_transaccion,
             calle, numero, ciudad, provincia, cod_postal,
             cod_cliente, cod_metodo_pago)
        SELECT 'confirmado', 'aprobado', 'TX-T8-ERROR',
               dir.calle, dir.numero, loc.nombre, prov.nombre, dir.cod_postal,
               c.cod_cliente, @cod_metodo_pago
        FROM dbo.cliente c
        INNER JOIN dbo.direccion dir ON dir.cod_cliente = c.cod_cliente AND dir.principal = 1
        INNER JOIN dbo.localidad loc ON loc.cod_localidad = dir.cod_localidad
        INNER JOIN dbo.provincia prov ON prov.cod_provincia = loc.cod_provincia
        WHERE c.cod_cliente = @cod_cliente;
        SET @cod_pedido = SCOPE_IDENTITY();

        -- >>> ERROR PROVOCADO INTENCIONALMENTE (tambien serviria: SELECT 1 / 0;)
        THROW 50299, 'Error provocado intencionalmente despues del INSERT.', 1;

        -- Estas sentencias no llegan a ejecutarse
        INSERT INTO dbo.detalle_pedido
            (cod_pedido, cod_producto, item, cantidad,
             precio_unitario_venta, alicuota_iva, iva_monto)
        VALUES (@cod_pedido, @cod_producto, 1, @cantidad, @precio, @alicuota,
                ROUND(@cantidad * @precio * @alicuota / (100 + @alicuota), 2));

        UPDATE dbo.producto SET stock = stock - @cantidad WHERE cod_producto = @cod_producto;

    COMMIT TRANSACTION;
    PRINT 'T8: COMMIT (no deberia llegar aca).';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'T8: ROLLBACK. Motivo: ' + ERROR_MESSAGE();
END CATCH;

SELECT 'T8 - DESPUES' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;
GO

-- =============================================================
-- T9. Stock insuficiente (error de negocio) -> ROLLBACK
-- Se intentan vender 9999 unidades. El pedido y el detalle se insertan,
-- pero el UPDATE de stock no encuentra filas y lanza el error 50211: el
-- CATCH revierte los dos INSERT.
-- Esperado: error 50211; pedidos 12, lineas 18 y stock 40, antes y despues.
-- =============================================================

SET NOCOUNT ON;
DECLARE @cod_cliente INT = 1, @cod_metodo_pago INT = 1, @cod_producto INT = 2, @cantidad INT = 9999;
DECLARE @cod_pedido INT, @precio DECIMAL(10, 2), @alicuota DECIMAL(4, 2);

-- Precio final (IVA y descuento vigente, RN.19 y RN.24) y alicuota del producto
SELECT @precio = dbo.fn_precio_final(p.cod_producto, GETDATE()), @alicuota = a.porcentaje
FROM dbo.producto p
INNER JOIN dbo.alicuota_iva a ON a.cod_alicuota = p.cod_alicuota
WHERE p.cod_producto = @cod_producto;

SELECT 'T9 - ANTES' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;

SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

        INSERT INTO dbo.pedido
            (estado, estado_pago, ref_transaccion,
             calle, numero, ciudad, provincia, cod_postal,
             cod_cliente, cod_metodo_pago)
        SELECT 'confirmado', 'aprobado', 'TX-T9-STOCK',
               dir.calle, dir.numero, loc.nombre, prov.nombre, dir.cod_postal,
               c.cod_cliente, @cod_metodo_pago
        FROM dbo.cliente c
        INNER JOIN dbo.direccion dir ON dir.cod_cliente = c.cod_cliente AND dir.principal = 1
        INNER JOIN dbo.localidad loc ON loc.cod_localidad = dir.cod_localidad
        INNER JOIN dbo.provincia prov ON prov.cod_provincia = loc.cod_provincia
        WHERE c.cod_cliente = @cod_cliente;
        SET @cod_pedido = SCOPE_IDENTITY();

        INSERT INTO dbo.detalle_pedido
            (cod_pedido, cod_producto, item, cantidad,
             precio_unitario_venta, alicuota_iva, iva_monto)
        VALUES (@cod_pedido, @cod_producto, 1, @cantidad, @precio, @alicuota,
                ROUND(@cantidad * @precio * @alicuota / (100 + @alicuota), 2));

        UPDATE dbo.producto SET stock = stock - @cantidad
        WHERE cod_producto = @cod_producto AND stock >= @cantidad;
        IF @@ROWCOUNT = 0
            THROW 50211, 'Stock insuficiente: se revierte toda la operacion.', 1;

    COMMIT TRANSACTION;
    PRINT 'T9: COMMIT (no deberia llegar aca).';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'T9: ROLLBACK. Motivo: ' + ERROR_MESSAGE();
END CATCH;

SELECT 'T9 - DESPUES' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;
GO

-- =============================================================
-- T10. Contraste: el MISMO error SIN transaccion
-- Sin BEGIN TRANSACTION cada INSERT se confirma por separado: al fallar el
-- paso siguiente queda un pedido SIN detalle (datos inconsistentes). Al final
-- se elimina ese pedido de prueba.
-- Esperado: pedidos 12 -> 13 (pedido huerfano), lineas 18, stock 40; tras la
--           limpieza vuelve a 12 pedidos.
-- =============================================================

SET NOCOUNT ON;
DECLARE @cod_cliente INT = 1, @cod_metodo_pago INT = 1, @cod_producto INT = 2, @cantidad INT = 1;
DECLARE @cod_pedido INT, @precio DECIMAL(10, 2), @alicuota DECIMAL(4, 2);

-- Precio final (IVA y descuento vigente, RN.19 y RN.24) y alicuota del producto
SELECT @precio = dbo.fn_precio_final(p.cod_producto, GETDATE()), @alicuota = a.porcentaje
FROM dbo.producto p
INNER JOIN dbo.alicuota_iva a ON a.cod_alicuota = p.cod_alicuota
WHERE p.cod_producto = @cod_producto;

SELECT 'T10 - ANTES' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;

SET XACT_ABORT OFF;
BEGIN TRY
    INSERT INTO dbo.pedido
        (estado, estado_pago, ref_transaccion,
         calle, numero, ciudad, provincia, cod_postal,
         cod_cliente, cod_metodo_pago)
    SELECT 'confirmado', 'aprobado', 'TX-T10-SIN-TRAN',
           dir.calle, dir.numero, loc.nombre, prov.nombre, dir.cod_postal,
           c.cod_cliente, @cod_metodo_pago
    FROM dbo.cliente c
    INNER JOIN dbo.direccion dir ON dir.cod_cliente = c.cod_cliente AND dir.principal = 1
    INNER JOIN dbo.localidad loc ON loc.cod_localidad = dir.cod_localidad
    INNER JOIN dbo.provincia prov ON prov.cod_provincia = loc.cod_provincia
    WHERE c.cod_cliente = @cod_cliente;
    SET @cod_pedido = SCOPE_IDENTITY();

    THROW 50299, 'Error provocado intencionalmente despues del INSERT.', 1;
END TRY
BEGIN CATCH
    PRINT 'T10: error SIN transaccion. Motivo: ' + ERROR_MESSAGE();
END CATCH;

SELECT 'T10 - DESPUES (pedido huerfano)' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;

-- Limpieza del pedido huerfano
DELETE FROM dbo.pedido WHERE cod_pedido = @cod_pedido;

SELECT 'T10 - TRAS LA LIMPIEZA' AS momento,
       (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas,
       (SELECT stock FROM dbo.producto WHERE cod_producto = @cod_producto) AS stock_producto;
GO

-- =============================================================
-- T11 a T13. Transacciones anidadas y puntos de recuperacion
-- La clave es el contador @@TRANCOUNT:
--   T11  el COMMIT de una transaccion interna no confirma nada: solo resta 1.
--   T12  un ROLLBACK sin nombre deshace TODO y deja el contador en 0,
--        aunque haya transacciones internas.
--   T13  SAVE TRANSACTION permite deshacer solo una parte; el resto se
--        puede confirmar despues.
-- Usan la tabla categoria con nombres "DEMO-..." que se eliminan al final.
-- Los resultados de los PRINT se ven en la pestana Mensajes.
-- =============================================================

SET NOCOUNT ON;
SET XACT_ABORT OFF;   -- estas demostraciones se hacen con el valor por defecto

-- T11) COMMIT interno + ROLLBACK externo
-- Esperado: contador 0, 1, 2, 1 y 0; filas DEMO-ANIDADA-1 = 0
PRINT '--- T11) COMMIT interno + ROLLBACK externo';
PRINT 'Contador al inicio: ' + CAST(@@TRANCOUNT AS VARCHAR(3));
BEGIN TRANSACTION externa;
    PRINT 'Despues de BEGIN externa: ' + CAST(@@TRANCOUNT AS VARCHAR(3));
    BEGIN TRANSACTION interna;
        PRINT 'Despues de BEGIN interna: ' + CAST(@@TRANCOUNT AS VARCHAR(3));
        INSERT INTO dbo.categoria (nombre) VALUES ('DEMO-ANIDADA-1');
    COMMIT TRANSACTION interna;
    PRINT 'Despues de COMMIT interna: ' + CAST(@@TRANCOUNT AS VARCHAR(3));   -- todavia no es permanente
ROLLBACK TRANSACTION externa;
PRINT 'Despues de ROLLBACK externa: ' + CAST(@@TRANCOUNT AS VARCHAR(3));
SELECT COUNT(*) AS filas_DEMO_ANIDADA_1_esperado_0
FROM dbo.categoria WHERE nombre = 'DEMO-ANIDADA-1';

-- T12) ROLLBACK dentro de la transaccion interna: deshace todo
-- Esperado: contador 0 despues del ROLLBACK interno; filas DEMO-ANIDADA-2 = 0
PRINT '--- T12) ROLLBACK dentro de la transaccion interna';
BEGIN TRANSACTION;
    BEGIN TRANSACTION;
        INSERT INTO dbo.categoria (nombre) VALUES ('DEMO-ANIDADA-2');
    ROLLBACK TRANSACTION;   -- deshace TODO, tambien la transaccion externa
PRINT 'Contador despues del ROLLBACK interno: ' + CAST(@@TRANCOUNT AS VARCHAR(3));
SELECT COUNT(*) AS filas_DEMO_ANIDADA_2_esperado_0
FROM dbo.categoria WHERE nombre = 'DEMO-ANIDADA-2';

-- T13) Punto de recuperacion: se deshace una parte y se confirma el resto
-- Esperado: contador 1 tras el ROLLBACK al punto (la transaccion sigue
--           abierta); despues del COMMIT queda solo DEMO-SP-A.
PRINT '--- T13) Punto de recuperacion';
BEGIN TRANSACTION;
    INSERT INTO dbo.categoria (nombre) VALUES ('DEMO-SP-A');
    SAVE TRANSACTION punto_1;
    INSERT INTO dbo.categoria (nombre) VALUES ('DEMO-SP-B');
    ROLLBACK TRANSACTION punto_1;   -- solo se deshace DEMO-SP-B
    PRINT 'Contador despues de ROLLBACK al punto: ' + CAST(@@TRANCOUNT AS VARCHAR(3));
COMMIT TRANSACTION;
SELECT nombre, 'esperado: solo DEMO-SP-A' AS nota
FROM dbo.categoria WHERE nombre IN ('DEMO-SP-A', 'DEMO-SP-B');
GO

-- Limpieza de las categorias de demostracion
DELETE FROM dbo.categoria WHERE nombre LIKE 'DEMO-%';
SELECT COUNT(*) AS categorias_DEMO_restantes_esperado_0 FROM dbo.categoria WHERE nombre LIKE 'DEMO-%';
GO

-- =============================================================
-- Procedimiento: confirmar una compra a proveedor
-- Reglas de negocio vinculadas
--   RN.20  Toda compra nace "pendiente" y debe confirmarse explicitamente
--          para que el stock se incremente.
--   RN.09  El stock sube al confirmarse la compra.
--
-- Pasa la compra de 'pendiente' a 'recibida' y suma al stock de cada
-- producto las unidades de su detalle, todo en una sola transaccion.
--
-- Anidamiento: si se la llama SIN transaccion abierta, crea y confirma la
-- suya; si se la llama DENTRO de otra transaccion, usa un punto de
-- recuperacion (SAVE TRANSACTION) y, ante un error, deshace solo su parte
-- y el llamador puede seguir. Por eso usa XACT_ABORT OFF (el valor por
-- defecto) dentro del procedimiento. Es un enfoque distinto al de
-- sp_registrar_venta_completa y sp_cancelar_pedido (XACT_ABORT ON, que ante
-- un error condena toda la transaccion del llamador).
--
-- Codigo de error propio:
--   50221 la compra no existe o no esta en estado pendiente
-- =============================================================
CREATE OR ALTER PROCEDURE dbo.usp_confirmar_compra
    @cod_compra INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE @tran_propia BIT = 0;

    BEGIN TRY
        IF @@TRANCOUNT = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @tran_propia = 1;
        END
        ELSE
            SAVE TRANSACTION sv_confirmar_compra;

        UPDATE dbo.compra
        SET estado = 'recibida'
        WHERE cod_compra = @cod_compra AND estado = 'pendiente';

        IF @@ROWCOUNT = 0
            THROW 50221, 'La compra no existe o no esta en estado pendiente.', 1;

        UPDATE p
        SET p.stock = p.stock + dc.cantidad
        FROM dbo.producto p
        INNER JOIN dbo.detalle_compra dc ON dc.cod_producto = p.cod_producto
        WHERE dc.cod_compra = @cod_compra;

        IF @tran_propia = 1
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @tran_propia = 1
        BEGIN
            IF XACT_STATE() <> 0
                ROLLBACK TRANSACTION;
        END
        ELSE IF XACT_STATE() = 1
            ROLLBACK TRANSACTION sv_confirmar_compra;

        THROW;
    END CATCH;
END;
GO

-- =============================================================
-- T14. Confirmar una compra pendiente
-- La compra 9 esta pendiente y trae 5 unidades del producto 1 y 5 del 9. Se
-- confirma dentro de una transaccion que se revierte al final, para no
-- alterar los datos de prueba.
-- Esperado: estado pendiente -> recibida; stock del producto 1: 12 -> 17 y
--           del producto 9: 15 -> 20; tras el ROLLBACK vuelve a pendiente, 12 y 15.
-- =============================================================

SET NOCOUNT ON;
SET XACT_ABORT OFF;

BEGIN TRY
    BEGIN TRANSACTION;

        SELECT 'T14 - ANTES' AS momento, c.cod_compra, c.estado,
               (SELECT stock FROM dbo.producto WHERE cod_producto = 1) AS stock_producto_1,
               (SELECT stock FROM dbo.producto WHERE cod_producto = 9) AS stock_producto_9
        FROM dbo.compra c WHERE c.cod_compra = 9;

        EXEC dbo.usp_confirmar_compra @cod_compra = 9;

        SELECT 'T14 - TRAS CONFIRMAR' AS momento, c.cod_compra, c.estado,
               (SELECT stock FROM dbo.producto WHERE cod_producto = 1) AS stock_producto_1,
               (SELECT stock FROM dbo.producto WHERE cod_producto = 9) AS stock_producto_9
        FROM dbo.compra c WHERE c.cod_compra = 9;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;

SELECT 'T14 - TRAS ROLLBACK' AS momento, c.cod_compra, c.estado,
       (SELECT stock FROM dbo.producto WHERE cod_producto = 1) AS stock_producto_1,
       (SELECT stock FROM dbo.producto WHERE cod_producto = 9) AS stock_producto_9
FROM dbo.compra c WHERE c.cod_compra = 9;
GO

-- =============================================================
-- T15. Confirmar una compra que no se puede confirmar
-- Sin transaccion del llamador: el procedimiento abre la suya y la revierte.
-- Esperado: tres errores 50221 (compra ya recibida, cancelada e inexistente),
--           @@TRANCOUNT = 0 en cada caso y estados sin cambios
--           (compra 1 recibida, 9 pendiente, 10 cancelada).
-- =============================================================

BEGIN TRY
    EXEC dbo.usp_confirmar_compra @cod_compra = 1;      -- ya recibida
END TRY
BEGIN CATCH
    SELECT 'compra ya recibida (1)' AS caso, ERROR_NUMBER() AS error,
           ERROR_MESSAGE() AS mensaje, @@TRANCOUNT AS tran_count;
END CATCH;

BEGIN TRY
    EXEC dbo.usp_confirmar_compra @cod_compra = 10;     -- cancelada
END TRY
BEGIN CATCH
    SELECT 'compra cancelada (10)' AS caso, ERROR_NUMBER() AS error,
           ERROR_MESSAGE() AS mensaje, @@TRANCOUNT AS tran_count;
END CATCH;

BEGIN TRY
    EXEC dbo.usp_confirmar_compra @cod_compra = 999;    -- inexistente
END TRY
BEGIN CATCH
    SELECT 'compra inexistente (999)' AS caso, ERROR_NUMBER() AS error,
           ERROR_MESSAGE() AS mensaje, @@TRANCOUNT AS tran_count;
END CATCH;

SELECT cod_compra, estado FROM dbo.compra WHERE cod_compra IN (1, 9, 10) ORDER BY cod_compra;
GO

-- =============================================================
-- T16. Procedimiento dentro de una transaccion externa
-- Se confirma la compra 9 y despues se intenta confirmar la 10 (cancelada).
-- El error revierte solo la parte del procedimiento (hasta su punto de
-- recuperacion): la confirmacion de la compra 9 sigue vigente y la
-- transaccion externa sigue abierta. Despues el llamador decide descartar todo.
-- Esperado: tras la confirmacion rechazada, contador 1, estado de la
--           transaccion 1, compra 9 recibida y stock del producto 1 = 17;
--           tras el ROLLBACK externo, pendiente y stock 12.
-- =============================================================

SET NOCOUNT ON;
SET XACT_ABORT OFF;

BEGIN TRANSACTION;

    EXEC dbo.usp_confirmar_compra @cod_compra = 9;
    SELECT 'T16 - DENTRO DE LA TRANSACCION' AS momento, c.cod_compra, c.estado,
           (SELECT stock FROM dbo.producto WHERE cod_producto = 1) AS stock_producto_1,
           (SELECT stock FROM dbo.producto WHERE cod_producto = 9) AS stock_producto_9
    FROM dbo.compra c WHERE c.cod_compra = 9;

    -- Un error de negocio dentro del procedimiento revierte solo su parte
    BEGIN TRY
        EXEC dbo.usp_confirmar_compra @cod_compra = 10;
    END TRY
    BEGIN CATCH
        PRINT 'Confirmacion rechazada: ' + ERROR_MESSAGE();
    END CATCH;

    SELECT 'T16 - TRAS LA CONFIRMACION RECHAZADA (la primera sigue vigente)' AS momento,
           @@TRANCOUNT AS contador, XACT_STATE() AS estado_transaccion,
           (SELECT estado FROM dbo.compra WHERE cod_compra = 9) AS estado_compra_9,
           (SELECT stock FROM dbo.producto WHERE cod_producto = 1) AS stock_producto_1;

ROLLBACK TRANSACTION;   -- el llamador decide descartar todo

SELECT 'T16 - DESPUES DEL ROLLBACK EXTERNO' AS momento,
       (SELECT estado FROM dbo.compra WHERE cod_compra = 9) AS estado_compra_9,
       (SELECT stock FROM dbo.producto WHERE cod_producto = 1) AS stock_producto_1,
       @@TRANCOUNT AS contador;
GO

-- Se restablece el valor de XACT_ABORT con el que empiezan las pruebas T1 a T6
SET XACT_ABORT ON;
GO


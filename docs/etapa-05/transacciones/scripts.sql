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
-- =============================================================
-- ETAPA V - Tema 3: Triggers y auditoria
-- =============================================================

USE smarthome_store;
GO

SET NOCOUNT ON;
GO
-- -------------------------------------------------------------
-- Trigger 1: producto (precio_lista y stock)
-- Un trigger se ejecuta una vez por sentencia: inserted y deleted
-- pueden tener muchas filas. El FULL OUTER JOIN cubre los tres
-- casos (INSERT, UPDATE y DELETE).
-- -------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_producto_auditoria
ON dbo.producto
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Si el trigger se dispara desde otro trigger, no se repite.
    IF TRIGGER_NESTLEVEL() > 1 RETURN;

    DECLARE @cod_usuario INT = ISNULL(TRY_CAST(SESSION_CONTEXT(N'cod_usuario') AS INT), 1);

    INSERT INTO dbo.auditoria
        (entidad, operacion, registro_id, valor_anterior, valor_nuevo, cod_usuario)
    SELECT
        'producto',
        CASE WHEN d.cod_producto IS NULL THEN 'INSERT'
             WHEN i.cod_producto IS NULL THEN 'DELETE'
             ELSE 'UPDATE' END,
        COALESCE(i.cod_producto, d.cod_producto),
        CASE WHEN d.cod_producto IS NULL THEN NULL
             ELSE CONCAT('precio_lista=', d.precio_lista, '; stock=', d.stock) END,
        CASE WHEN i.cod_producto IS NULL THEN NULL
             ELSE CONCAT('precio_lista=', i.precio_lista, '; stock=', i.stock) END,
        @cod_usuario
    FROM inserted i
    FULL OUTER JOIN deleted d ON d.cod_producto = i.cod_producto
    WHERE i.cod_producto IS NULL
       OR d.cod_producto IS NULL
       OR i.precio_lista <> d.precio_lista
       OR i.stock        <> d.stock;
END;
GO

-- -------------------------------------------------------------
-- Trigger 2: pedido (estado, estado_pago y estado_envio)
-- Solo audita si alguno de esos campos cambia: un UPDATE de la
-- direccion de envio no genera fila.
-- -------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_pedido_auditoria
ON dbo.pedido
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRIGGER_NESTLEVEL() > 1 RETURN;

    DECLARE @cod_usuario INT = ISNULL(TRY_CAST(SESSION_CONTEXT(N'cod_usuario') AS INT), 1);

    INSERT INTO dbo.auditoria
        (entidad, operacion, registro_id, valor_anterior, valor_nuevo, cod_usuario)
    SELECT
        'pedido',
        CASE WHEN d.cod_pedido IS NULL THEN 'INSERT'
             WHEN i.cod_pedido IS NULL THEN 'DELETE'
             ELSE 'UPDATE' END,
        COALESCE(i.cod_pedido, d.cod_pedido),
        CASE WHEN d.cod_pedido IS NULL THEN NULL
             ELSE CONCAT('estado=', d.estado, '; pago=', d.estado_pago,
                         '; envio=', ISNULL(d.estado_envio, '-')) END,
        CASE WHEN i.cod_pedido IS NULL THEN NULL
             ELSE CONCAT('estado=', i.estado, '; pago=', i.estado_pago,
                         '; envio=', ISNULL(i.estado_envio, '-')) END,
        @cod_usuario
    FROM inserted i
    FULL OUTER JOIN deleted d ON d.cod_pedido = i.cod_pedido
    WHERE i.cod_pedido IS NULL
       OR d.cod_pedido IS NULL
       OR i.estado       <> d.estado
       OR i.estado_pago  <> d.estado_pago
       OR ISNULL(i.estado_envio, '-') <> ISNULL(d.estado_envio, '-');
END;
GO

-- -------------------------------------------------------------
-- Trigger 3: compra (estado)
-- -------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_compra_auditoria
ON dbo.compra
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRIGGER_NESTLEVEL() > 1 RETURN;

    DECLARE @cod_usuario INT = ISNULL(TRY_CAST(SESSION_CONTEXT(N'cod_usuario') AS INT), 1);

    INSERT INTO dbo.auditoria
        (entidad, operacion, registro_id, valor_anterior, valor_nuevo, cod_usuario)
    SELECT
        'compra',
        CASE WHEN d.cod_compra IS NULL THEN 'INSERT'
             WHEN i.cod_compra IS NULL THEN 'DELETE'
             ELSE 'UPDATE' END,
        COALESCE(i.cod_compra, d.cod_compra),
        CASE WHEN d.cod_compra IS NULL THEN NULL
             ELSE CONCAT('estado=', d.estado) END,
        CASE WHEN i.cod_compra IS NULL THEN NULL
             ELSE CONCAT('estado=', i.estado) END,
        @cod_usuario
    FROM inserted i
    FULL OUTER JOIN deleted d ON d.cod_compra = i.cod_compra
    WHERE i.cod_compra IS NULL
       OR d.cod_compra IS NULL
       OR i.estado <> d.estado;
END;
GO

-- -------------------------------------------------------------
-- Trigger 4: factura (emision y total)
-- Una factura no deberia modificarse; si se modifica, se audita
-- igual, sin filtrar por columna.
-- -------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_factura_auditoria
ON dbo.factura
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRIGGER_NESTLEVEL() > 1 RETURN;

    DECLARE @cod_usuario INT = ISNULL(TRY_CAST(SESSION_CONTEXT(N'cod_usuario') AS INT), 1);

    INSERT INTO dbo.auditoria
        (entidad, operacion, registro_id, valor_anterior, valor_nuevo, cod_usuario)
    SELECT
        'factura',
        CASE WHEN d.cod_factura IS NULL THEN 'INSERT'
             WHEN i.cod_factura IS NULL THEN 'DELETE'
             ELSE 'UPDATE' END,
        COALESCE(i.cod_factura, d.cod_factura),
        CASE WHEN d.cod_factura IS NULL THEN NULL
             ELSE CONCAT('tipo=', d.tipo_comprobante, '; numero=', d.numero,
                         '; total=', d.total) END,
        CASE WHEN i.cod_factura IS NULL THEN NULL
             ELSE CONCAT('tipo=', i.tipo_comprobante, '; numero=', i.numero,
                         '; total=', i.total) END,
        @cod_usuario
    FROM inserted i
    FULL OUTER JOIN deleted d ON d.cod_factura = i.cod_factura;
END;
GO

-- #############################################################
-- PARTE 2: DEMOSTRACION (ejecutar cada bloque por separado)
-- #############################################################

-- =============================================================
-- 0. Verificacion: los cuatro triggers quedaron creados
-- Esperado: 4 filas, todas AFTER y habilitadas.
-- =============================================================
SELECT OBJECT_NAME(parent_id) AS tabla,
       name                   AS trigger_name,
       CASE WHEN is_instead_of_trigger = 1 THEN 'INSTEAD OF' ELSE 'AFTER' END AS momento,
       is_disabled
FROM sys.triggers
WHERE parent_id IN (OBJECT_ID('dbo.producto'), OBJECT_ID('dbo.pedido'),
                    OBJECT_ID('dbo.compra'),   OBJECT_ID('dbo.factura'))
ORDER BY tabla;
GO

-- =============================================================
-- A1. UPDATE de stock con COMMIT
-- Usuario: 3 (lramirez, DEPOSITO).
-- Esperado: stock 40 -> 39 y una fila nueva en auditoria:
--   valor_anterior = 'precio_lista=20661.16; stock=40'
--   valor_nuevo    = 'precio_lista=20661.16; stock=39'
-- Despues se repone el stock y se borran las dos filas de la
-- prueba, para dejar la tabla como estaba.
-- =============================================================
DECLARE @antes1 INT = (SELECT ISNULL(MAX(cod_auditoria), 0) FROM auditoria);

EXEC sys.sp_set_session_context @key = N'cod_usuario', @value = 3;

UPDATE producto SET stock = stock - 1 WHERE cod_producto = 2;

SELECT 'STOCK MODIFICADO' AS momento, cod_producto, stock
FROM producto WHERE cod_producto = 2;

SELECT cod_auditoria, entidad, operacion, registro_id,
       valor_anterior, valor_nuevo, cod_usuario, fecha
FROM auditoria
WHERE cod_auditoria > @antes1;

-- Limpieza
UPDATE producto SET stock = stock + 1 WHERE cod_producto = 2;
DELETE FROM auditoria WHERE cod_auditoria > @antes1;
EXEC sys.sp_set_session_context @key = N'cod_usuario', @value = NULL;

SELECT 'TRAS LA LIMPIEZA' AS momento, cod_producto, stock
FROM producto WHERE cod_producto = 2;

SELECT COUNT(*) AS auditoria_total FROM auditoria;
GO

-- =============================================================
-- A2. INSERT y DELETE de un producto
-- Usuario: 9 (vlopez, ADMINISTRADOR).
-- Esperado: dos filas. En el INSERT valor_anterior es NULL; en el
-- DELETE valor_nuevo es NULL. Las dos guardan precio y stock.
-- =============================================================
DECLARE @antes2 INT = (SELECT ISNULL(MAX(cod_auditoria), 0) FROM auditoria);

EXEC sys.sp_set_session_context @key = N'cod_usuario', @value = 9;

INSERT INTO producto (nombre, descripcion, precio_lista, cod_alicuota, stock, cod_categoria)
VALUES ('Producto de prueba', 'Alta y baja para la demo de auditoria', 1000.00, 5, 3, 3);

DECLARE @id2 INT = SCOPE_IDENTITY();

DELETE FROM producto WHERE cod_producto = @id2;

SELECT cod_auditoria, entidad, operacion, registro_id,
       valor_anterior, valor_nuevo, cod_usuario
FROM auditoria
WHERE cod_auditoria > @antes2
ORDER BY cod_auditoria;

-- Limpieza
DELETE FROM auditoria WHERE cod_auditoria > @antes2;
EXEC sys.sp_set_session_context @key = N'cod_usuario', @value = NULL;

SELECT COUNT(*) AS auditoria_total FROM auditoria;
GO

-- =============================================================
-- A3. Venta completa con el procedimiento del Tema 1
-- Usuario: 4 (afernandez, DEPOSITO).
-- No se toca el procedimiento: el trigger audita solo el alta del
-- pedido y la baja de stock. Todo va en una transaccion que se
-- revierte, asi que no queda ningun cambio (ni auditoria): eso
-- muestra que la auditoria es transaccional.
-- Esperado dentro de la transaccion: 2 filas (pedido INSERT y
-- producto UPDATE, stock 40 -> 39). Tras el ROLLBACK: 10 filas y
-- stock 40.
-- =============================================================
DECLARE @antes3 INT = (SELECT ISNULL(MAX(cod_auditoria), 0) FROM auditoria);

EXEC sys.sp_set_session_context @key = N'cod_usuario', @value = 4;

BEGIN TRANSACTION;

    DECLARE @items3 dbo.tipo_items_pedido;
    DECLARE @nuevo3 INT;

    INSERT INTO @items3 (cod_producto, cantidad) VALUES (2, 1);

    EXEC dbo.sp_registrar_venta_completa
         @cod_cliente     = 1,
         @cod_metodo_pago = 1,
         @ref_transaccion = 'TX-A3-AUDITORIA',
         @items           = @items3,
         @cod_pedido      = @nuevo3 OUTPUT;

    SELECT cod_auditoria, entidad, operacion, registro_id,
           valor_anterior, valor_nuevo, cod_usuario
    FROM auditoria
    WHERE cod_auditoria > @antes3
    ORDER BY cod_auditoria;

ROLLBACK TRANSACTION;

EXEC sys.sp_set_session_context @key = N'cod_usuario', @value = NULL;

SELECT COUNT(*) AS auditoria_tras_rollback FROM auditoria;
SELECT cod_producto, stock FROM producto WHERE cod_producto = 2;
GO

-- =============================================================
-- A4. Si la auditoria falla, el cambio no se aplica
-- Se fija un usuario inexistente (999). El trigger no puede
-- insertar en auditoria (FK 547) y el UPDATE de stock se revierte.
-- Esperado: error 547; stock 40; auditoria 10.
-- =============================================================
DECLARE @antes4 INT = (SELECT COUNT(*) FROM auditoria);

EXEC sys.sp_set_session_context @key = N'cod_usuario', @value = 999;

BEGIN TRY
    UPDATE producto SET stock = stock - 1 WHERE cod_producto = 2;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;

EXEC sys.sp_set_session_context @key = N'cod_usuario', @value = NULL;

SELECT cod_producto, stock FROM producto WHERE cod_producto = 2;
SELECT @antes4 AS auditoria_antes, COUNT(*) AS auditoria_despues FROM auditoria;
GO

-- =============================================================
-- A5. Un solo UPDATE sobre los 10 productos
-- Usuario: 9. El trigger procesa todas las filas de inserted de
-- una vez: 10 filas de auditoria en una sola sentencia. Es la
-- prueba de que es set-based y no fila por fila.
-- =============================================================
DECLARE @antes5 INT = (SELECT ISNULL(MAX(cod_auditoria), 0) FROM auditoria);

EXEC sys.sp_set_session_context @key = N'cod_usuario', @value = 9;

UPDATE producto SET stock = stock + 1;

SELECT COUNT(*) AS filas_auditadas FROM auditoria WHERE cod_auditoria > @antes5;

SELECT TOP 3 cod_auditoria, operacion, registro_id, valor_anterior, valor_nuevo
FROM auditoria
WHERE cod_auditoria > @antes5
ORDER BY cod_auditoria;

-- Limpieza
UPDATE producto SET stock = stock - 1;
DELETE FROM auditoria WHERE cod_auditoria > @antes5;
EXEC sys.sp_set_session_context @key = N'cod_usuario', @value = NULL;

SELECT COUNT(*) AS auditoria_total FROM auditoria;
GO

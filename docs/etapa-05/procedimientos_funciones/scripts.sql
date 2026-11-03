-- =============================================================
-- ETAPA V - Tema 1: Funciones y procedimientos almacenados
-- Objetos que cree:
--   tipo_items_pedido         tipo tabla para pasar los productos de una venta
--   fn_descuento_vigente      mayor descuento de promocion vigente de un producto (RN.24)
--   fn_precio_final           precio con IVA y descuento, el que se congela en el detalle (RN.19, RN.24, RN.28)
--   fn_total_pedido           total de un pedido, calculado desde el detalle (RN.10)
--   sp_registrar_venta_completa  registra pedido + detalle + baja de stock en una sola operacion
-- =============================================================

USE smarthome_store;
GO

-- -------------------------------------------------------------
-- Tipo tabla: lista de productos y cantidades de una venta
-- -------------------------------------------------------------
IF TYPE_ID('dbo.tipo_items_pedido') IS NULL
    CREATE TYPE dbo.tipo_items_pedido AS TABLE
    (
        cod_producto INT NOT NULL PRIMARY KEY,
        cantidad     INT NOT NULL CHECK (cantidad > 0)
    );
GO

-- -------------------------------------------------------------
-- Funcion 1: descuento vigente de un producto en una fecha
-- Si el producto tiene mas de una promocion vigente, se aplica
-- la de mayor descuento (RN.24). Las promociones que solo
-- ofrecen cuotas (porcentaje 0) no cuentan como descuento.
-- Devuelve 0 si no hay promocion con descuento.
-- -------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_descuento_vigente
(
    @cod_producto INT,
    @fecha        DATETIME
)
RETURNS DECIMAL(5,2)
AS
BEGIN
    RETURN ISNULL(
        (SELECT MAX(pr.porcentaje_descuento)
         FROM dbo.promocion pr
         INNER JOIN dbo.promocion_producto pp ON pp.cod_promocion = pr.cod_promocion
         WHERE pp.cod_producto = @cod_producto
           AND @fecha BETWEEN pr.fecha_inicio AND pr.fecha_fin),
        0);
END;
GO

-- -------------------------------------------------------------
-- Funcion 2: precio final de un producto en una fecha
-- precio_lista es neto (RN.19): se le suma el IVA del producto
-- y despues se aplica el descuento vigente.
-- Devuelve NULL si el producto no existe.
-- -------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_precio_final
(
    @cod_producto INT,
    @fecha        DATETIME
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @precio DECIMAL(10,2);

    SELECT @precio = ROUND(
               p.precio_lista
               * (1 + a.porcentaje / 100)
               * (1 - dbo.fn_descuento_vigente(p.cod_producto, @fecha) / 100),
               2)
    FROM dbo.producto p
    INNER JOIN dbo.alicuota_iva a ON a.cod_alicuota = p.cod_alicuota
    WHERE p.cod_producto = @cod_producto;

    RETURN @precio;
END;
GO

-- -------------------------------------------------------------
-- Funcion 3: total de un pedido (con IVA)
-- El total no se guarda, se calcula desde el detalle (RN.10).
-- Devuelve 0 si el pedido no existe o no tiene renglones.
-- -------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_total_pedido
(
    @cod_pedido INT
)
RETURNS DECIMAL(12,2)
AS
BEGIN
    RETURN ISNULL(
        (SELECT SUM(cantidad * precio_unitario_venta)
         FROM dbo.detalle_pedido
         WHERE cod_pedido = @cod_pedido),
        0);
END;
GO

-- -------------------------------------------------------------
-- Procedimiento: registrar una venta completa
-- Pasos:
--   1. Validar cliente, direccion, metodo de pago, referencia de pago y productos.
--   2. Verificar stock de todos los productos (RN.11).
--   3. Insertar el pedido confirmado/aprobado, con la direccion principal
--      del cliente o la indicada en @cod_direccion (RN.04) y fecha actual (RN.16).
--   4. Insertar el detalle congelando precio, alicuota e IVA (RN.03, RN.19, RN.28).
--   5. Descontar el stock (RN.09).
-- Si algo falla se deshace todo y se re-lanza el error.
--
-- Codigos de error propios:
--   50001 cliente inexistente o inactivo
--   50002 metodo de pago inexistente
--   50003 la venta no tiene productos
--   50004 producto inexistente o inactivo
--   50005 stock insuficiente
--   50006 falta la referencia de la transaccion de pago
--   50007 la direccion no existe o no es del cliente
-- -------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_registrar_venta_completa
    @cod_cliente     INT,
    @cod_metodo_pago INT,
    @ref_transaccion VARCHAR(50),
    @items           dbo.tipo_items_pedido READONLY,
    @cod_pedido      INT OUTPUT,
    @cod_direccion   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Si quien llama ya abrio una transaccion, no abrimos otra.
    DECLARE @tran_propia BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @ahora DATETIME = GETDATE();

    BEGIN TRY
        IF @tran_propia = 1 BEGIN TRANSACTION;

        -- 1. Validaciones
        IF NOT EXISTS (SELECT 1 FROM dbo.cliente WHERE cod_cliente = @cod_cliente AND activo = 1)
            THROW 50001, 'Cliente inexistente o inactivo.', 1;

        -- Si no se indica una direccion, se usa la principal (RN.04)
        IF @cod_direccion IS NULL
            SELECT @cod_direccion = cod_direccion
            FROM dbo.direccion
            WHERE cod_cliente = @cod_cliente AND principal = 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.direccion
                       WHERE cod_direccion = @cod_direccion AND cod_cliente = @cod_cliente)
            THROW 50007, 'La direccion no existe o no es del cliente.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.metodo_pago WHERE cod_metodo_pago = @cod_metodo_pago)
            THROW 50002, 'Metodo de pago inexistente.', 1;

        IF @ref_transaccion IS NULL
            THROW 50006, 'Falta la referencia de la transaccion de pago.', 1;

        IF NOT EXISTS (SELECT 1 FROM @items)
            THROW 50003, 'La venta no tiene productos.', 1;

        IF EXISTS (SELECT 1
                   FROM @items i
                   LEFT JOIN dbo.producto p ON p.cod_producto = i.cod_producto
                   WHERE p.cod_producto IS NULL OR p.activo = 0)
            THROW 50004, 'Producto inexistente o inactivo.', 1;

        -- 2. Stock: nadie mas modifica esas filas hasta terminar
        IF EXISTS (SELECT 1
                   FROM @items i
                   INNER JOIN dbo.producto p WITH (UPDLOCK, HOLDLOCK)
                           ON p.cod_producto = i.cod_producto
                   WHERE p.stock < i.cantidad)
            THROW 50005, 'Stock insuficiente para al menos un producto de la venta.', 1;

        -- 3. Encabezado del pedido
        INSERT INTO dbo.pedido
            (estado, estado_pago, ref_transaccion,
             calle, numero, ciudad, provincia, cod_postal,
             cod_cliente, cod_metodo_pago)
        SELECT 'confirmado', 'aprobado', @ref_transaccion,
               dir.calle, dir.numero, loc.nombre, prov.nombre, dir.cod_postal,
               c.cod_cliente, @cod_metodo_pago
        FROM dbo.cliente c
        INNER JOIN dbo.direccion dir ON dir.cod_cliente = c.cod_cliente AND dir.cod_direccion = @cod_direccion
        INNER JOIN dbo.localidad loc ON loc.cod_localidad = dir.cod_localidad
        INNER JOIN dbo.provincia prov ON prov.cod_provincia = loc.cod_provincia
        WHERE c.cod_cliente = @cod_cliente;

        SET @cod_pedido = SCOPE_IDENTITY();

        -- 4. Detalle con precio, alicuota e IVA congelados
        INSERT INTO dbo.detalle_pedido
            (cod_pedido, cod_producto, item, cantidad,
             precio_unitario_venta, alicuota_iva, iva_monto)
        SELECT @cod_pedido,
               i.cod_producto,
               ROW_NUMBER() OVER (ORDER BY i.cod_producto),
               i.cantidad,
               pf.precio,
               a.porcentaje,
               ROUND(i.cantidad * pf.precio
                     - (i.cantidad * pf.precio) / (1 + a.porcentaje / 100), 2)
        FROM @items i
        INNER JOIN dbo.producto    p ON p.cod_producto = i.cod_producto
        INNER JOIN dbo.alicuota_iva a ON a.cod_alicuota = p.cod_alicuota
        CROSS APPLY (SELECT dbo.fn_precio_final(p.cod_producto, @ahora) AS precio) pf;

        -- 5. Salida de stock
        UPDATE p
        SET p.stock = p.stock - i.cantidad
        FROM dbo.producto p
        INNER JOIN @items i ON i.cod_producto = p.cod_producto;

        IF @tran_propia = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @tran_propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- #############################################################
-- PARTE 2: DEMOSTRACION (ejecutar cada bloque por separado)
-- #############################################################
-- =============================================================
-- ETAPA V - Tema 1: DEMOSTRACION de funciones y procedimiento
-- =============================================================

USE smarthome_store;
GO

-- =============================================================
-- A. FUNCIONES
-- =============================================================

-- A1. Descuento y precio final de todos los productos al 20/09/2026
--     (ese dia estaba vigente la promo 4 "Liquidacion Accesorios", 35 %,
--      y la promo 3, que solo ofrece cuotas y no cuenta como descuento).
-- Esperado: producto 4 (Funda Notebook) -> descuento 35.00 y precio_final 5200.00.
--           Resto -> descuento 0.00 y precio_final = precio_lista + IVA
--           (por ejemplo producto 1 -> 350000.00; producto 5 -> 850000.00 con IVA 10,5 %).
SELECT
    cod_producto,
    nombre,
    precio_lista,
    dbo.fn_descuento_vigente(cod_producto, '2026-09-20') AS descuento_pct,
    dbo.fn_precio_final(cod_producto, '2026-09-20')      AS precio_final
FROM producto
ORDER BY cod_producto;
GO

-- A2. Total de pedidos ya cargados
-- Esperado: pedido 1 -> 245000.00 ; pedido 2 -> 89250.00 ; pedido 9 -> 405000.01
SELECT cod_pedido, dbo.fn_total_pedido(cod_pedido) AS total
FROM pedido
WHERE cod_pedido IN (1, 2, 9);
GO

-- A3. Control: la funcion reproduce el precio congelado en los pedidos existentes.
--     Lista solo los renglones donde el precio guardado NO coincide con la funcion.
-- Esperado: 0 filas o, a lo sumo, diferencias de 1 centavo (por ejemplo pedido 3,
--           producto 3), que vendrian de como se cargo el dato a mano, no de la funcion.
SELECT
    dp.cod_pedido,
    dp.cod_producto,
    dp.precio_unitario_venta                              AS precio_guardado,
    dbo.fn_precio_final(dp.cod_producto, p.fecha_pedido)  AS precio_funcion
FROM detalle_pedido dp
INNER JOIN pedido p ON p.cod_pedido = dp.cod_pedido
WHERE dp.precio_unitario_venta <> dbo.fn_precio_final(dp.cod_producto, p.fecha_pedido);
GO

-- =============================================================
-- B. PROCEDIMIENTO sp_registrar_venta_completa
-- =============================================================

-- B1. Venta correcta (2 auriculares + 1 funda).
--     Va dentro de una transaccion que se deshace al final (ROLLBACK),
--     para no ensuciar los datos de prueba de las etapas anteriores.
-- Esperado (si se ejecuta desde el 28/10/2026 en adelante, sin promo vigente
--           sobre los productos 2 y 4):
--   - stock ANTES:   producto 2 = 40, producto 4 = 30
--   - se crea un pedido nuevo (confirmado / aprobado) con 2 renglones
--   - precios: producto 2 = 25000.00 ; producto 4 = 8000.00
--   - total = 58000.00
--   - stock DESPUES: producto 2 = 38, producto 4 = 29
--   - stock tras el ROLLBACK: vuelve a 40 y 30
BEGIN TRANSACTION;

DECLARE @items dbo.tipo_items_pedido;
DECLARE @nuevo INT;

INSERT INTO @items (cod_producto, cantidad) VALUES (2, 2), (4, 1);

SELECT 'ANTES' AS momento, cod_producto, nombre, stock
FROM producto WHERE cod_producto IN (2, 4);

EXEC dbo.sp_registrar_venta_completa
     @cod_cliente     = 1,
     @cod_metodo_pago = 1,
     @ref_transaccion = 'DEMO-0001',
     @items           = @items,
     @cod_pedido      = @nuevo OUTPUT;

SELECT cod_pedido, fecha_pedido, estado, estado_pago, ref_transaccion, cod_cliente, calle, numero, ciudad
FROM pedido WHERE cod_pedido = @nuevo;

SELECT cod_pedido, item, cod_producto, cantidad, precio_unitario_venta, alicuota_iva, iva_monto
FROM detalle_pedido WHERE cod_pedido = @nuevo;

SELECT dbo.fn_total_pedido(@nuevo) AS total_pedido;

SELECT 'DESPUES' AS momento, cod_producto, nombre, stock
FROM producto WHERE cod_producto IN (2, 4);

ROLLBACK TRANSACTION;

SELECT 'TRAS ROLLBACK' AS momento, cod_producto, nombre, stock
FROM producto WHERE cod_producto IN (2, 4);
GO

-- B2. Venta con stock insuficiente (6 lavarropas, hay 5).
-- Esperado: error 50005 "Stock insuficiente..."; la cantidad de pedidos no cambia y el stock del producto 8 sigue en 5 (no queda ningun registro parcial).
DECLARE @items dbo.tipo_items_pedido;
DECLARE @nuevo INT;
DECLARE @pedidos_antes INT = (SELECT COUNT(*) FROM pedido);

INSERT INTO @items (cod_producto, cantidad) VALUES (8, 6);

BEGIN TRY
    EXEC dbo.sp_registrar_venta_completa
         @cod_cliente     = 1,
         @cod_metodo_pago = 1,
         @ref_transaccion = 'DEMO-0002',
         @items           = @items,
         @cod_pedido      = @nuevo OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;

SELECT @pedidos_antes AS pedidos_antes, COUNT(*) AS pedidos_despues FROM pedido;
SELECT cod_producto, nombre, stock FROM producto WHERE cod_producto = 8;
GO

-- B3. Cliente inexistente.
-- Esperado: error 50001 "Cliente inexistente o inactivo."
DECLARE @items dbo.tipo_items_pedido;
DECLARE @nuevo INT;

INSERT INTO @items (cod_producto, cantidad) VALUES (2, 1);

BEGIN TRY
    EXEC dbo.sp_registrar_venta_completa
         @cod_cliente     = 999,
         @cod_metodo_pago = 1,
         @ref_transaccion = 'DEMO-0003',
         @items           = @items,
         @cod_pedido      = @nuevo OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;
GO
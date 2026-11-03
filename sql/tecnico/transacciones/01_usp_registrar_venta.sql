-- =====================================================================
-- Etapa V - Transacciones: procedimiento usp_registrar_venta
-- SmartHome Store (equipo 37) - SQL Server
--
-- Registra una venta completa de un producto como UNA unidad de trabajo:
--   1) encabezado del pedido (con la dirección principal del cliente)
--   2) renglón de detalle con precio e IVA congelados
--   3) descuento de stock
-- Si cualquier paso falla se revierte todo (atomicidad).
--
-- Reglas de negocio vinculadas
--   RN.04  El pedido toma la dirección principal del cliente.
--   RN.09  El stock baja al confirmarse el pedido.
--   RN.11  No se confirma un pedido si el stock es insuficiente.
--   RN.19  El precio final con IVA se congela en el detalle.
--   RN.24  Se aplica la mayor promoción vigente y el precio con descuento
--          queda congelado en el detalle.
--
-- Anidamiento: si se la llama SIN transacción abierta, crea y confirma la
-- suya; si se la llama DENTRO de otra transacción, usa un punto de
-- recuperación (SAVE TRANSACTION) y, ante un error, deshace solo su parte.
-- Errores propios: 50201 a 50204.
-- Requiere: dbo.fn_precio_con_iva y dbo.fn_mayor_descuento_vigente.
-- =====================================================================
USE smarthome_store;
GO

CREATE OR ALTER PROCEDURE dbo.usp_registrar_venta
    @cod_cliente     INT,
    @cod_metodo_pago INT,
    @cod_producto    INT,
    @cantidad        INT,
    @cod_pedido      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @tran_propia  BIT = 0;
    DECLARE @precio_base  DECIMAL(12, 2);
    DECLARE @descuento    DECIMAL(5, 2);
    DECLARE @precio_final DECIMAL(10, 2);
    DECLARE @alicuota     DECIMAL(4, 2);

    BEGIN TRY
        IF @@TRANCOUNT = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @tran_propia = 1;
        END
        ELSE
            SAVE TRANSACTION sv_registrar_venta;

        IF @cantidad IS NULL OR @cantidad <= 0
            THROW 50201, 'La cantidad debe ser mayor a cero.', 1;

        -- Precio vigente con IVA y promoción (RN.19, RN.24)
        SELECT @precio_base = dbo.fn_precio_con_iva(p.cod_producto),
               @descuento   = dbo.fn_mayor_descuento_vigente(p.cod_producto, GETDATE()),
               @alicuota    = a.porcentaje
        FROM dbo.producto p
        JOIN dbo.alicuota_iva a ON a.cod_alicuota = p.cod_alicuota
        WHERE p.cod_producto = @cod_producto AND p.activo = 1;

        IF @precio_base IS NULL
            THROW 50202, 'El producto no existe o está inactivo.', 1;

        SET @precio_final = ROUND(@precio_base * (1 - @descuento / 100.0), 2);

        -- 1) Encabezado del pedido con la dirección principal del cliente (RN.04)
        INSERT INTO dbo.pedido (calle, numero, ciudad, provincia, cod_postal, cod_cliente, cod_metodo_pago, estado)
        SELECT dir.calle, dir.numero, loc.nombre, prov.nombre, dir.cod_postal, c.cod_cliente, @cod_metodo_pago, 'confirmado'
        FROM dbo.cliente c
        JOIN dbo.direccion dir ON dir.cod_cliente = c.cod_cliente AND dir.principal = 1
        JOIN dbo.localidad loc ON loc.cod_localidad = dir.cod_localidad
        JOIN dbo.provincia prov ON prov.cod_provincia = loc.cod_provincia
        WHERE c.cod_cliente = @cod_cliente AND c.activo = 1;

        IF @@ROWCOUNT = 0
            THROW 50203, 'El cliente no existe, está inactivo o no tiene dirección principal.', 1;

        SET @cod_pedido = SCOPE_IDENTITY();

        -- 2) Detalle con precio e IVA congelados (el IVA se extrae del precio final)
        INSERT INTO dbo.detalle_pedido (item, precio_unitario_venta, cantidad, alicuota_iva, iva_monto, cod_pedido, cod_producto)
        VALUES (1, @precio_final, @cantidad, @alicuota,
                ROUND(@cantidad * @precio_final * @alicuota / (100 + @alicuota), 2),
                @cod_pedido, @cod_producto);

        -- 3) Descuento de stock. La condición "stock >= cantidad" evita stock
        --    negativo aunque dos ventas simultáneas compitan por el mismo producto (RN.11).
        UPDATE dbo.producto
        SET stock = stock - @cantidad
        WHERE cod_producto = @cod_producto AND stock >= @cantidad;

        IF @@ROWCOUNT = 0
            THROW 50204, 'Stock insuficiente para completar la venta.', 1;

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
            ROLLBACK TRANSACTION sv_registrar_venta;

        SET @cod_pedido = NULL;
        THROW;
    END CATCH;
END;
GO

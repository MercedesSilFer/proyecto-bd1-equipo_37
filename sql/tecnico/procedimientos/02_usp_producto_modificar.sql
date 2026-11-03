
-- Procedimientos almacenados: MODIFICAR producto

-- Reglas de negocio vinculadas

--   RN.03/RN.19  El cambio de precio de lista NO altera los pedidos ya
--                registrados (el precio queda congelado en detalle_pedido).
--   RN.14        Los cambios de precio y stock quedan auditados (trigger de
--                docs/etapa-05/triggers_auditoria/scripts.sql).

USE smarthome_store;
GO

CREATE OR ALTER PROCEDURE dbo.usp_producto_modificar
    @cod_producto  INT,
    @nombre        VARCHAR(50),
    @descripcion   VARCHAR(1000),
    @precio_lista  DECIMAL(10, 2),
    @cod_alicuota  INT,
    @stock         INT,
    @cod_categoria INT,
    @activo        BIT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.producto WHERE cod_producto = @cod_producto)
            THROW 50111, 'El producto indicado no existe.', 1;

        IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
            THROW 50114, 'El nombre del producto es obligatorio.', 1;

        IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
            THROW 50115, 'La descripción del producto es obligatoria.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.categoria WHERE cod_categoria = @cod_categoria)
            THROW 50112, 'La categoría indicada no existe.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.alicuota_iva WHERE cod_alicuota = @cod_alicuota)
            THROW 50113, 'La alícuota de IVA indicada no existe.', 1;

        UPDATE dbo.producto
        SET nombre        = LTRIM(RTRIM(@nombre)),
            descripcion   = @descripcion,
            precio_lista  = @precio_lista,
            cod_alicuota  = @cod_alicuota,
            stock         = @stock,
            cod_categoria = @cod_categoria,
            activo        = @activo
        WHERE cod_producto = @cod_producto;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH;
END;
GO

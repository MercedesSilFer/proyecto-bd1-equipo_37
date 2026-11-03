
-- Procedimientos almacenados: ELIMINAR producto

-- Decisión de diseño: un producto con historial (vendido o comprado) NO
-- puede borrarse físicamente sin perder trazabilidad, y la base ya lo
-- impide con claves foráneas. El procedimiento decide solo:
--   * sin historial  -> DELETE físico            (@resultado = 'ELIMINADO')
--   * con historial  -> baja lógica (activo = 0) (@resultado = 'BAJA_LOGICA')


USE smarthome_store;
GO

CREATE OR ALTER PROCEDURE dbo.usp_producto_eliminar
    @cod_producto INT,
    @resultado    VARCHAR(12) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.producto WHERE cod_producto = @cod_producto)
            THROW 50121, 'El producto indicado no existe.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.detalle_pedido WHERE cod_producto = @cod_producto)
           AND NOT EXISTS (SELECT 1 FROM dbo.detalle_compra WHERE cod_producto = @cod_producto)
        BEGIN
            DELETE FROM dbo.producto WHERE cod_producto = @cod_producto;
            SET @resultado = 'ELIMINADO';
        END
        ELSE
        BEGIN
            UPDATE dbo.producto SET activo = 0 WHERE cod_producto = @cod_producto;
            SET @resultado = 'BAJA_LOGICA';
        END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH;
END;
GO

-- =====================================================================
-- Etapa V - Transacciones: procedimiento usp_confirmar_compra
-- SmartHome Store (equipo 37) - SQL Server
--
-- Reglas de negocio vinculadas
--   RN.20  Toda compra nace "pendiente" y debe confirmarse explícitamente
--          para que el stock se incremente.
--   RN.09  El stock sube al confirmarse la compra.
--
-- Pasa la compra de 'pendiente' a 'recibida' y suma al stock de cada
-- producto las unidades de su detalle, todo en una sola transacción.
-- Usa el mismo esquema de anidamiento que usp_registrar_venta.
-- Errores propios: 50221.
-- =====================================================================
USE smarthome_store;
GO

CREATE OR ALTER PROCEDURE dbo.usp_confirmar_compra
    @cod_compra INT
AS
BEGIN
    SET NOCOUNT ON;

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
            THROW 50221, 'La compra no existe o no está en estado pendiente.', 1;

        UPDATE p
        SET p.stock = p.stock + dc.cantidad
        FROM dbo.producto p
        JOIN dbo.detalle_compra dc ON dc.cod_producto = p.cod_producto
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


-- Procedimientos almacenados: INSERTAR producto

-- Reglas de negocio vinculadas
--   RN.06  Cada producto pertenece a una única categoría ya definida.
--   RN.28  Cada producto tiene asignada una alícuota del catálogo.

-- El procedimiento valida los datos ANTES de insertar y devuelve el
-- código generado en un parámetro de salida. Los errores se informan con
-- THROW (números 50101-50104). Las restricciones CHECK de la tabla
-- (precio > 0, stock >= 0) siguen actuando como última barrera.

USE smarthome_store;
GO

CREATE OR ALTER PROCEDURE dbo.usp_producto_insertar
    @nombre        VARCHAR(50),
    @descripcion   VARCHAR(1000),
    @precio_lista  DECIMAL(10, 2),
    @cod_alicuota  INT,
    @stock         INT,
    @cod_categoria INT,
    @cod_producto  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
            THROW 50101, 'El nombre del producto es obligatorio.', 1;

        IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
            THROW 50104, 'La descripción del producto es obligatoria.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.categoria
                       WHERE cod_categoria = @cod_categoria AND activo = 1)
            THROW 50102, 'La categoría indicada no existe o está inactiva.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.alicuota_iva WHERE cod_alicuota = @cod_alicuota)
            THROW 50103, 'La alícuota de IVA indicada no existe.', 1;

        INSERT INTO dbo.producto (nombre, descripcion, precio_lista, cod_alicuota, stock, cod_categoria)
        VALUES (LTRIM(RTRIM(@nombre)), @descripcion, @precio_lista, @cod_alicuota, @stock, @cod_categoria);

        SET @cod_producto = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        THROW;   -- se vuelve a lanzar el error original al llamador
    END CATCH;
END;
GO

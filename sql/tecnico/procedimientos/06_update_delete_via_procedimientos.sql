
-- Procedimientos: UPDATE y DELETE invocando a los procedimientos
-- Opera sobre los productos del lote "LOTE-P" (ver 05_lote_via_procedimientos.sql).
-- Incluye casos de error y un caso de baja lógica (dentro de una
-- transacción que se revierte para no alterar los datos originales).

USE smarthome_store;
GO
SET NOCOUNT ON;


-- 1) MODIFICAR: subir 10 % el precio de lista y bajar el stock de un producto
-- ---------------------------------------------------------------------
DECLARE @id_mod INT = (SELECT TOP (1) cod_producto FROM dbo.producto
                       WHERE nombre LIKE 'LOTE-P %' ORDER BY cod_producto);
DECLARE @nombre VARCHAR(50), @descripcion VARCHAR(1000), @precio DECIMAL(10, 2),
        @alic INT, @stock INT, @cat INT, @activo BIT, @precio_nuevo DECIMAL(10, 2);

SELECT @nombre = nombre, @descripcion = descripcion, @precio = precio_lista,
       @alic = cod_alicuota, @stock = stock, @cat = cod_categoria, @activo = activo
FROM dbo.producto WHERE cod_producto = @id_mod;

SET @precio_nuevo = ROUND(@precio * 1.10, 2);
SET @stock = @stock - 3;

EXEC dbo.usp_producto_modificar
     @cod_producto = @id_mod, @nombre = @nombre, @descripcion = @descripcion,
     @precio_lista = @precio_nuevo, @cod_alicuota = @alic, @stock = @stock,
     @cod_categoria = @cat, @activo = @activo;

SELECT cod_producto, nombre, precio_lista, stock, 'Después del UPDATE' AS momento
FROM dbo.producto WHERE cod_producto = @id_mod;


-- 2) ELIMINAR un producto sin historial -> DELETE físico
-- ---------------------------------------------------------------------
DECLARE @id_del INT = (SELECT TOP (1) cod_producto FROM dbo.producto
                       WHERE nombre LIKE 'LOTE-P %' ORDER BY cod_producto DESC);
DECLARE @res VARCHAR(12);

EXEC dbo.usp_producto_eliminar @cod_producto = @id_del, @resultado = @res OUTPUT;
SELECT @id_del AS cod_producto, @res AS resultado,
       (SELECT COUNT(*) FROM dbo.producto WHERE cod_producto = @id_del) AS filas_restantes;
GO


-- 3) ELIMINAR un producto CON historial -> baja lógica
--    (se hace dentro de una transacción y se revierte, para no dejar
--     inactivo un producto del catálogo original)
-- ---------------------------------------------------------------------
DECLARE @res2 VARCHAR(12);
DECLARE @id_vendido INT = (SELECT TOP (1) cod_producto FROM dbo.detalle_pedido ORDER BY cod_producto);

BEGIN TRANSACTION;
    EXEC dbo.usp_producto_eliminar @cod_producto = @id_vendido, @resultado = @res2 OUTPUT;
    SELECT cod_producto, nombre, activo, @res2 AS resultado
    FROM dbo.producto WHERE cod_producto = @id_vendido;
ROLLBACK TRANSACTION;

SELECT cod_producto, nombre, activo, 'Después del ROLLBACK' AS momento
FROM dbo.producto WHERE cod_producto = @id_vendido;
GO


-- 4) CASOS DE ERROR (se capturan y se muestran los mensajes)
-- ---------------------------------------------------------------------
DECLARE @id INT;

BEGIN TRY   -- producto inexistente
    DECLARE @r VARCHAR(12);
    EXEC dbo.usp_producto_eliminar @cod_producto = 999999, @resultado = @r OUTPUT;
END TRY
BEGIN CATCH
    SELECT 'Eliminar inexistente' AS caso, ERROR_NUMBER() AS nro_error, ERROR_MESSAGE() AS mensaje;
END CATCH;

BEGIN TRY   -- categoría inexistente
    EXEC dbo.usp_producto_insertar @nombre = 'LOTE-P error', @precio_lista = 100,
         @cod_alicuota = 5, @stock = 1, @cod_categoria = 999999, @cod_producto = @id OUTPUT;
END TRY
BEGIN CATCH
    SELECT 'Insertar con categoría inexistente' AS caso, ERROR_NUMBER() AS nro_error, ERROR_MESSAGE() AS mensaje;
END CATCH;

BEGIN TRY   -- precio negativo: lo frena la restricción CHECK de la tabla
    EXEC dbo.usp_producto_insertar @nombre = 'LOTE-P error', @precio_lista = -50,
         @cod_alicuota = 5, @stock = 1, @cod_categoria = 1, @cod_producto = @id OUTPUT;
END TRY
BEGIN CATCH
    SELECT 'Insertar con precio negativo' AS caso, ERROR_NUMBER() AS nro_error, ERROR_MESSAGE() AS mensaje;
END CATCH;
GO

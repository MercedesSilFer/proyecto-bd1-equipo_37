
-- Procedimientos: LOTE 2 de datos invocando al procedimiento
-- usp_producto_insertar. Los productos de este lote llevan el prefijo
-- "LOTE-P" y son los MISMOS 5 productos del lote 04 ("LOTE-A"), con los
-- mismos precios, stock, alícuotas y categorías. Solo cambia el prefijo
-- y el mecanismo de carga (EXEC al procedimiento en lugar de INSERT).
-- Requiere haber ejecutado 01_usp_producto_insertar.sql.

USE smarthome_store;
GO
SET NOCOUNT ON;

DECLARE @alic_general    INT = (SELECT cod_alicuota FROM dbo.alicuota_iva WHERE porcentaje = 21.00);
DECLARE @alic_reducida   INT = (SELECT cod_alicuota FROM dbo.alicuota_iva WHERE porcentaje = 10.50);
DECLARE @cat_accesorios  INT = (SELECT cod_categoria FROM dbo.categoria WHERE nombre = N'Accesorios');
DECLARE @cat_audio       INT = (SELECT cod_categoria FROM dbo.categoria WHERE nombre = N'Audio');
DECLARE @cat_informatica INT = (SELECT cod_categoria FROM dbo.categoria WHERE nombre = N'Informática');
DECLARE @cat_notebooks   INT = (SELECT cod_categoria FROM dbo.categoria WHERE nombre = N'Notebooks');
DECLARE @id INT;

EXEC dbo.usp_producto_insertar
     @nombre = 'LOTE-P Teclado mecánico', @descripcion = 'Teclado mecánico retroiluminado',
     @precio_lista = 33057.85, @cod_alicuota = @alic_general, @stock = 25,
     @cod_categoria = @cat_informatica, @cod_producto = @id OUTPUT;
PRINT 'Producto creado: ' + CAST(@id AS VARCHAR(10));

EXEC dbo.usp_producto_insertar
     @nombre = 'LOTE-P Mouse inalámbrico', @descripcion = 'Mouse óptico inalámbrico 1600 dpi',
     @precio_lista = 8264.46, @cod_alicuota = @alic_general, @stock = 40,
     @cod_categoria = @cat_accesorios, @cod_producto = @id OUTPUT;
PRINT 'Producto creado: ' + CAST(@id AS VARCHAR(10));

EXEC dbo.usp_producto_insertar
     @nombre = 'LOTE-P Auriculares gamer', @descripcion = 'Auriculares con micrófono USB',
     @precio_lista = 24793.39, @cod_alicuota = @alic_general, @stock = 18,
     @cod_categoria = @cat_audio, @cod_producto = @id OUTPUT;
PRINT 'Producto creado: ' + CAST(@id AS VARCHAR(10));

EXEC dbo.usp_producto_insertar
     @nombre = 'LOTE-P Notebook gamer', @descripcion = 'Notebook 16GB RAM, SSD 512GB',
     @precio_lista = 950000.00, @cod_alicuota = @alic_reducida, @stock = 6,
     @cod_categoria = @cat_notebooks, @cod_producto = @id OUTPUT;
PRINT 'Producto creado: ' + CAST(@id AS VARCHAR(10));

EXEC dbo.usp_producto_insertar
     @nombre = 'LOTE-P Soporte monitor', @descripcion = 'Soporte articulado para monitor',
     @precio_lista = 12396.69, @cod_alicuota = @alic_general, @stock = 30,
     @cod_categoria = @cat_accesorios, @cod_producto = @id OUTPUT;
PRINT 'Producto creado: ' + CAST(@id AS VARCHAR(10));

SELECT cod_producto, nombre, precio_lista, stock
FROM dbo.producto
WHERE nombre LIKE 'LOTE-P %'
ORDER BY cod_producto;
GO

-- ---------------------------------------------------------------------
-- Verificación opcional de equivalencia (requiere haber ejecutado antes
-- 04_lote_insert_directo.sql). Compara cada producto LOTE-A con su par
-- LOTE-P; 'iguales' = 1 si precio, stock, alícuota y categoría coinciden.
-- ---------------------------------------------------------------------
SELECT a.nombre AS lote_a,
       p.nombre AS lote_p,
       a.precio_lista, a.stock, a.cod_alicuota, a.cod_categoria,
       CASE WHEN a.precio_lista = p.precio_lista
             AND a.stock        = p.stock
             AND a.cod_alicuota = p.cod_alicuota
             AND a.cod_categoria = p.cod_categoria
            THEN 1 ELSE 0 END AS iguales
FROM dbo.producto a
INNER JOIN dbo.producto p
        ON SUBSTRING(a.nombre, 8, 100) = SUBSTRING(p.nombre, 8, 100)
WHERE a.nombre LIKE 'LOTE-A %'
  AND p.nombre LIKE 'LOTE-P %'
ORDER BY a.cod_producto;
GO

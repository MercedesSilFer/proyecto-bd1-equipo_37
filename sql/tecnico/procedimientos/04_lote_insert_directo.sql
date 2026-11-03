
-- Procedimientos: LOTE 1 de datos con sentencias INSERT directas
--  Los productos de este lote llevan el prefijo "LOTE-A".

USE smarthome_store;
GO
SET NOCOUNT ON;

DECLARE @alic_general    INT = (SELECT cod_alicuota FROM dbo.alicuota_iva WHERE porcentaje = 21.00);
DECLARE @alic_reducida   INT = (SELECT cod_alicuota FROM dbo.alicuota_iva WHERE porcentaje = 10.50);
DECLARE @cat_accesorios  INT = (SELECT cod_categoria FROM dbo.categoria WHERE nombre = N'Accesorios');
DECLARE @cat_audio       INT = (SELECT cod_categoria FROM dbo.categoria WHERE nombre = N'Audio');
DECLARE @cat_informatica INT = (SELECT cod_categoria FROM dbo.categoria WHERE nombre = N'Informática');
DECLARE @cat_notebooks   INT = (SELECT cod_categoria FROM dbo.categoria WHERE nombre = N'Notebooks');

-- columnas: nombre, descripcion, precio_lista (neto), cod_alicuota, stock, cod_categoria
INSERT INTO dbo.producto (nombre, descripcion, precio_lista, cod_alicuota, stock, cod_categoria)
VALUES
    ('LOTE-A Teclado mecánico',  'Teclado mecánico retroiluminado',   33057.85, @alic_general,  25, @cat_informatica),
    ('LOTE-A Mouse inalámbrico', 'Mouse óptico inalámbrico 1600 dpi',  8264.46, @alic_general,  40, @cat_accesorios),
    ('LOTE-A Auriculares gamer', 'Auriculares con micrófono USB',     24793.39, @alic_general,  18, @cat_audio),
    ('LOTE-A Notebook gamer',    'Notebook 16GB RAM, SSD 512GB',     950000.00, @alic_reducida,  6, @cat_notebooks),
    ('LOTE-A Soporte monitor',   'Soporte articulado para monitor',   12396.69, @alic_general,  30, @cat_accesorios);

SELECT cod_producto, nombre, precio_lista, stock
FROM dbo.producto
WHERE nombre LIKE 'LOTE-A %'
ORDER BY cod_producto;
GO

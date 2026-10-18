-- Reporte agregado de ventas por categoria
-- Total vendido por categoria de producto en un rango de fechas.
-- Se considera VENTA: pedido 'confirmado' con pago 'aprobado'.
-- Cambiar @fecha_desde y @fecha_hasta por el rango a consultar (ambas fechas incluidas).

USE smarthome_store;
GO

DECLARE @fecha_desde DATE = '2026-07-01';
DECLARE @fecha_hasta DATE = '2026-09-30';

-- ---------------------------------------------------------------
--   1  Ventas por categoria
--      Cantidad de ventas, unidades e importes vendidos en cada categoria
--      (la categoria a la que pertenece directamente el producto).
--      Tablas: pedido, detalle_pedido, producto, categoria
--      Tecnica: INNER JOIN + GROUP BY + COUNT(DISTINCT) y SUM.
-- ---------------------------------------------------------------
SELECT
    cat.cod_categoria,
    cat.nombre                                                AS categoria,
    COUNT(DISTINCT p.cod_pedido)                              AS cant_ventas,
    SUM(dp.cantidad)                                          AS unidades_vendidas,
    SUM(dp.cantidad * dp.precio_unitario_venta)               AS total_vendido,
    SUM(dp.cantidad * dp.precio_unitario_venta - dp.iva_monto) AS total_neto
FROM pedido p
INNER JOIN detalle_pedido dp  ON dp.cod_pedido    = p.cod_pedido
INNER JOIN producto       pr  ON pr.cod_producto  = dp.cod_producto
INNER JOIN categoria      cat ON cat.cod_categoria = pr.cod_categoria
WHERE p.estado = 'confirmado'
  AND p.estado_pago = 'aprobado'
  AND p.fecha_pedido >= @fecha_desde
  AND p.fecha_pedido <  DATEADD(DAY, 1, @fecha_hasta)   -- incluye todo el dia @fecha_hasta
GROUP BY cat.cod_categoria, cat.nombre
ORDER BY total_vendido DESC;

-- ---------------------------------------------------------------
--   2  Ventas por categoria principal
--      Mismo reporte, pero sumando cada subcategoria dentro de su categoria padre
--      (ej. Audio y Televisores dentro de Electronica).
--      Tablas: pedido, detalle_pedido, producto, categoria (dos veces: hija y padre)
--      Tecnica: LEFT JOIN de categoria consigo misma + COALESCE + GROUP BY.
-- ---------------------------------------------------------------
SELECT
    COALESCE(padre.cod_categoria, cat.cod_categoria)          AS cod_categoria,
    COALESCE(padre.nombre, cat.nombre)                        AS categoria_principal,
    COUNT(DISTINCT p.cod_pedido)                              AS cant_ventas,
    SUM(dp.cantidad)                                          AS unidades_vendidas,
    SUM(dp.cantidad * dp.precio_unitario_venta)               AS total_vendido,
    SUM(dp.cantidad * dp.precio_unitario_venta - dp.iva_monto) AS total_neto
FROM pedido p
INNER JOIN detalle_pedido dp    ON dp.cod_pedido      = p.cod_pedido
INNER JOIN producto       pr    ON pr.cod_producto    = dp.cod_producto
INNER JOIN categoria      cat   ON cat.cod_categoria  = pr.cod_categoria
LEFT  JOIN categoria      padre ON padre.cod_categoria = cat.cod_categoria_padre
WHERE p.estado = 'confirmado'
  AND p.estado_pago = 'aprobado'
  AND p.fecha_pedido >= @fecha_desde
  AND p.fecha_pedido <  DATEADD(DAY, 1, @fecha_hasta)
GROUP BY COALESCE(padre.cod_categoria, cat.cod_categoria), COALESCE(padre.nombre, cat.nombre)
ORDER BY total_vendido DESC;
GO
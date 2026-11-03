
-- Demostración de las funciones (casos normales y casos límite)
-- Requiere haber ejecutado 01_funciones.sql.

USE smarthome_store;
GO
SET NOCOUNT ON;                          --no envía el mensaje de “N filas afectadas”

-- 1) Precio con IVA y stock disponible de todo el catálogo
SELECT p.cod_producto,
       p.nombre,
       p.precio_lista                         AS precio_neto,
       dbo.fn_precio_con_iva(p.cod_producto)  AS precio_con_iva,
       dbo.fn_stock_disponible(p.cod_producto) AS stock_disponible
FROM dbo.producto p
ORDER BY p.cod_producto;
 
-- 2) Monto de cada pedido calculado con la función (RN.10)
SELECT p.cod_pedido, p.estado, p.estado_pago, dbo.fn_monto_pedido(p.cod_pedido) AS monto
FROM dbo.pedido p
ORDER BY p.cod_pedido;

-- 3) Promociones vigentes el 10/10/2026
SELECT pr.cod_producto, pr.nombre,
       dbo.fn_mayor_descuento_vigente(pr.cod_producto, '2026-10-10') AS descuento_pct
FROM dbo.producto pr
WHERE dbo.fn_mayor_descuento_vigente(pr.cod_producto, '2026-10-10') > 0
ORDER BY pr.cod_producto;

-- 4) Función de tabla: pedidos de un cliente (se usa como una tabla más)
SELECT * FROM dbo.fn_pedidos_cliente(2) ORDER BY cod_pedido;

SELECT c.cod_cliente, c.nombre + ' ' + c.apellido AS cliente, t.cod_pedido, t.monto
FROM dbo.cliente c
CROSS APPLY dbo.fn_pedidos_cliente(c.cod_cliente) AS t  --ejecuta una función de tabla (o subconsulta) una vez por cada fila de la tabla de la izquierda, y combina cada fila con lo que esa ejecución devuelve
WHERE t.estado = 'confirmado' AND t.estado_pago = 'aprobado'
ORDER BY c.cod_cliente, t.cod_pedido;

-- 5) Casos límite
SELECT dbo.fn_precio_con_iva(999999)  AS precio_producto_inexistente,   -- NULL
       dbo.fn_stock_disponible(999999) AS stock_producto_inexistente,   -- 0
       dbo.fn_monto_pedido(999999)     AS monto_pedido_inexistente;     -- 0
GO

--Consultas de negocio avanzadas

-- Se considera VENTA: pedido 'confirmado' con pago 'aprobado'.
-- Se considera COMPRA valida: compra en estado 'recibida'.

USE smarthome_store;
GO

--   1  Clientes de alto valor: clientes cuyo total comprado supera
--      el promedio de compra por cliente.
--      Tablas: cliente, pedido, detalle_pedido
--      Tecnica: GROUP BY + HAVING con subconsulta escalar (que a su
--      vez usa una tabla derivada) para calcular el promedio.
-- ---------------------------------------------------------------
SELECT
    c.cod_cliente, c.nombre + ' ' + c.apellido AS cliente,
    c.ciudad, c.provincia,  COUNT(DISTINCT p.cod_pedido) AS cant_pedidos,
    SUM(dp.cantidad * dp.precio_unitario_venta)          AS total_comprado,
    SUM(dp.cantidad * dp.precio_unitario_venta)
        / COUNT(DISTINCT p.cod_pedido)                   AS ticket_promedio,
    MAX(p.fecha_pedido)                                  AS ultimo_pedido
FROM cliente c
INNER JOIN pedido         p  ON p.cod_cliente = c.cod_cliente   --Solo clientes con pedido
INNER JOIN detalle_pedido dp ON dp.cod_pedido = p.cod_pedido
WHERE p.estado = 'confirmado'
  AND p.estado_pago = 'aprobado'
GROUP BY c.cod_cliente, c.nombre, c.apellido, c.ciudad, c.provincia
HAVING SUM(dp.cantidad * dp.precio_unitario_venta) >
       (SELECT AVG(t.total_cliente) --Monto promedio
        FROM (SELECT SUM(dp2.cantidad * dp2.precio_unitario_venta) AS total_cliente --Monto comprado por cada cliente
              FROM pedido p2
              INNER JOIN detalle_pedido dp2 ON dp2.cod_pedido = p2.cod_pedido
              WHERE p2.estado = 'confirmado'
                AND p2.estado_pago = 'aprobado'
              GROUP BY p2.cod_cliente) AS t)
ORDER BY total_comprado DESC;


-- 2  Productos con margen bajo: compara la venta NETA (sin IVA)
--      contra el costo promedio ponderado de las compras recibidas
--      y lista los productos con margen menor al minimo indicado.
--      Tablas: detalle_pedido, pedido, producto, categoria y
--              (CTE) detalle_compra + compra
--      Tecnica: CTE + GROUP BY + HAVING con parametro.
--      Supuesto: costo_unitario de compra esta expresado sin IVA.
-- ---------------------------------------------------------------
DECLARE @margen_minimo DECIMAL(5,2) = 25.00;   -- porcentaje

WITH costo_prod AS (
    SELECT dc.cod_producto,             --Costo promedio de cada producto
           SUM(dc.cantidad * dc.costo_unitario) / SUM(dc.cantidad) AS costo_promedio
    FROM detalle_compra dc
    INNER JOIN compra co ON co.cod_compra = dc.cod_compra
    WHERE co.estado = 'recibida'
    GROUP BY dc.cod_producto
)
SELECT
    pr.cod_producto, pr.nombre AS producto, cat.nombre AS categoria, SUM(dp.cantidad) AS unidades_vendidas,
    SUM(dp.cantidad * dp.precio_unitario_venta - dp.iva_monto) AS venta_neta,
    ROUND(SUM(dp.cantidad) * cp.costo_promedio, 2) AS costo_total,
    ROUND(SUM(dp.cantidad * dp.precio_unitario_venta - dp.iva_monto) - SUM(dp.cantidad) * cp.costo_promedio, 2) AS margen,
    ROUND(100.0 * (SUM(dp.cantidad * dp.precio_unitario_venta - dp.iva_monto)
                   - SUM(dp.cantidad) * cp.costo_promedio)
          / SUM(dp.cantidad * dp.precio_unitario_venta - dp.iva_monto), 2) AS margen_producto
FROM detalle_pedido dp
INNER JOIN pedido     p   ON p.cod_pedido      = dp.cod_pedido
INNER JOIN producto   pr  ON pr.cod_producto   = dp.cod_producto
INNER JOIN categoria  cat ON cat.cod_categoria = pr.cod_categoria
INNER JOIN costo_prod cp  ON cp.cod_producto   = pr.cod_producto
WHERE p.estado = 'confirmado'
  AND p.estado_pago = 'aprobado'
GROUP BY pr.cod_producto, pr.nombre, cat.nombre, cp.costo_promedio
HAVING 100.0 * (SUM(dp.cantidad * dp.precio_unitario_venta - dp.iva_monto)
                - SUM(dp.cantidad) * cp.costo_promedio)
       / SUM(dp.cantidad * dp.precio_unitario_venta - dp.iva_monto) < @margen_minimo
ORDER BY margen_producto;

-- 3  Proveedores principales: proveedores cuyo monto comprado
--      (compras recibidas) supera el promedio por proveedor.
--      Tablas: proveedor, compra, detalle_compra
--      Tecnica: GROUP BY + HAVING con subconsulta escalar.
-- ---------------------------------------------------------------
SELECT
    pv.cod_proveedor, pv.razon_social, pv.provincia,
    COUNT(DISTINCT co.cod_compra)   AS compras_recibidas,
    COUNT(DISTINCT dc.cod_producto) AS productos_distintos,
    SUM(dc.cantidad)                AS unidades,
    SUM(dc.cantidad * dc.costo_unitario)  AS monto_comprado
FROM proveedor pv             --Proveedores con compra
INNER JOIN compra         co ON co.cod_proveedor = pv.cod_proveedor
INNER JOIN detalle_compra dc ON dc.cod_compra    = co.cod_compra
WHERE co.estado = 'recibida'
GROUP BY pv.cod_proveedor, pv.razon_social, pv.provincia
HAVING SUM(dc.cantidad * dc.costo_unitario) >
       (SELECT AVG(t.monto)  --Promedio de monto comprado a cada proveedor
        FROM (SELECT SUM(dc2.cantidad * dc2.costo_unitario) AS monto  --Monto comprado por cada proveedor
              FROM compra co2
              INNER JOIN detalle_compra dc2 ON dc2.cod_compra = co2.cod_compra
              WHERE co2.estado = 'recibida'
              GROUP BY co2.cod_proveedor) AS t)
ORDER BY monto_comprado DESC;

--   4  Clientes sin compras concretadas
--      Clientes registrados que nunca tuvieron una venta (pedido confirmado y pagado).
--      Tablas: cliente, pedido
--      Tecnica: NOT EXISTS (subconsulta correlacionada) + subconsulta escalar en el SELECT.
-- ---------------------------------------------------------------
SELECT c.cod_cliente, c.nombre + ' ' + c.apellido AS cliente, c.ciudad, c.provincia, c.fecha_registro,
    (SELECT COUNT(*) FROM pedido p2
     WHERE p2.cod_cliente = c.cod_cliente) AS pedidos_registrados
FROM cliente c
WHERE NOT EXISTS (SELECT 1
                  FROM pedido p
                  WHERE p.cod_cliente = c.cod_cliente
                    AND p.estado = 'confirmado'
                    AND p.estado_pago = 'aprobado')
ORDER BY c.fecha_registro;

--   5  Actividad de cada usuario interno
--      Cuantas operaciones registro cada usuario en pedidos, compras, facturas y auditoria.
--      Tablas: usuario, pedido, compra, factura, auditoria
--      Tecnica: cuatro subconsultas escalares correlacionadas en el SELECT dentro de una
--      tabla derivada, que permite ordenar por el total sumado.
-- ---------------------------------------------------------------
SELECT t.*, t.pedidos_gestionados + t.compras_registradas
         + t.facturas_emitidas + t.cambios_auditados     AS total_operaciones
FROM (SELECT
          u.cod_usuario,
          u.nombre_usuario,
          u.rol,
          (SELECT COUNT(*) FROM pedido   p  WHERE p.cod_usuario  = u.cod_usuario) AS pedidos_gestionados,
          (SELECT COUNT(*) FROM compra   co WHERE co.cod_usuario = u.cod_usuario) AS compras_registradas,
          (SELECT COUNT(*) FROM factura  f  WHERE f.cod_usuario  = u.cod_usuario) AS facturas_emitidas,
          (SELECT COUNT(*) FROM auditoria a WHERE a.cod_usuario  = u.cod_usuario) AS cambios_auditados
      FROM usuario u) AS t
ORDER BY total_operaciones DESC, t.cod_usuario;

--   6  Clientes que compraron productos de una categoria
--      Cambiar @categoria por el nombre de otra categoria (ej. 'Celulares').
--      Tablas: cliente, pedido, detalle_pedido, producto, categoria
--      Tecnica: IN con subconsultas anidadas en 4 niveles. IN no duplica clientes aunque
--      hayan comprado el producto en varios pedidos.
-- ---------------------------------------------------------------
DECLARE @categoria VARCHAR(50) = 'Audio';

SELECT
    c.cod_cliente,    c.nombre + ' ' + c.apellido AS cliente, c.ciudad, c.provincia
FROM cliente c
WHERE c.cod_cliente IN
      (SELECT p.cod_cliente
       FROM pedido p
       WHERE p.estado = 'confirmado'
         AND p.estado_pago = 'aprobado'
         AND p.cod_pedido IN
             (SELECT dp.cod_pedido
              FROM detalle_pedido dp
              WHERE dp.cod_producto IN
                    (SELECT pr.cod_producto
                     FROM producto pr
                     WHERE pr.cod_categoria IN
                           (SELECT cat.cod_categoria
                            FROM categoria cat
                            WHERE cat.nombre = @categoria))))
ORDER BY c.cod_cliente;


--   7  Productos en promocion vigente
--      Productos alcanzados por alguna promocion vigente en @fecha, con el mayor
--      descuento y la mayor cantidad de cuotas disponibles. Para hoy: GETDATE().
--      Tablas: producto, promocion, promocion_producto
--      Tecnica: EXISTS + subconsultas escalares en el SELECT.
-- ---------------------------------------------------------------
DECLARE @fecha DATETIME = '2026-10-10';

SELECT
    p.cod_producto, p.nombre AS producto, p.precio_lista,
    (SELECT MAX(pm.porcentaje_descuento)
     FROM promocion pm
     INNER JOIN promocion_producto pp ON pp.cod_promocion = pm.cod_promocion
     WHERE pp.cod_producto = p.cod_producto
       AND @fecha BETWEEN pm.fecha_inicio AND pm.fecha_fin) AS mayor_descuento_pct,
    (SELECT MAX(pm.nro_cuotas)
     FROM promocion pm
     JOIN promocion_producto pp ON pp.cod_promocion = pm.cod_promocion
     WHERE pp.cod_producto = p.cod_producto
       AND @fecha BETWEEN pm.fecha_inicio AND pm.fecha_fin) AS max_cuotas
FROM producto p
WHERE EXISTS (SELECT 1
              FROM promocion pm
              INNER JOIN promocion_producto pp ON pp.cod_promocion = pm.cod_promocion
              WHERE pp.cod_producto = p.cod_producto
                AND @fecha BETWEEN pm.fecha_inicio AND pm.fecha_fin)
ORDER BY p.cod_producto;

--   8  Proveedores sin compras recibidas
--      Proveedores dados de alta que todavia no concretaron ninguna compra.
--      Tablas: proveedor, compra
--      Tecnica: NOT EXISTS + subconsulta escalar. Se prefiere a NOT IN porque NOT IN
--      devuelve un resultado vacio si la subconsulta contiene algun NULL.
-- ---------------------------------------------------------------
SELECT
    pv.cod_proveedor, pv.razon_social, pv.provincia,
    (SELECT COUNT(*) FROM compra co2
     WHERE co2.cod_proveedor = pv.cod_proveedor) AS compras_registradas
FROM proveedor pv
WHERE NOT EXISTS (SELECT 1
                  FROM compra co
                  WHERE co.cod_proveedor = pv.cod_proveedor
                    AND co.estado = 'recibida')
ORDER BY pv.cod_proveedor;

--   9  Pedido de mayor importe
--      Pedido(s) de venta cuyo importe es el maximo (importe = suma de sus lineas).
--      Tablas: pedido, cliente, detalle_pedido
--      Tecnica: tablas derivadas + subconsulta escalar con MAX en el WHERE.
-- ---------------------------------------------------------------
SELECT
    p.cod_pedido, cl.nombre + ' ' + cl.apellido AS cliente, p.fecha_pedido, t.importe
FROM pedido p
INNER JOIN cliente cl ON cl.cod_cliente = p.cod_cliente
INNER JOIN (SELECT dp.cod_pedido,
             SUM(dp.cantidad * dp.precio_unitario_venta) AS importe
             FROM detalle_pedido dp
             GROUP BY dp.cod_pedido) AS t ON t.cod_pedido = p.cod_pedido
WHERE p.estado = 'confirmado'
  AND p.estado_pago = 'aprobado'
  AND t.importe = (SELECT MAX(t2.importe)
                   FROM (SELECT dp2.cod_pedido,
                                SUM(dp2.cantidad * dp2.precio_unitario_venta) AS importe
                         FROM detalle_pedido dp2
                         INNER JOIN pedido p2 ON p2.cod_pedido = dp2.cod_pedido
                         WHERE p2.estado = 'confirmado'
                           AND p2.estado_pago = 'aprobado'
                         GROUP BY dp2.cod_pedido) AS t2);

--  10  Productos a reponer
--      Productos con stock inferior al promedio que ademas tuvieron ventas.
--      Tablas: producto, categoria, detalle_pedido, pedido
--      Tecnica: subconsulta escalar (AVG) y EXISTS en el WHERE + subconsultas en el SELECT.
-- ---------------------------------------------------------------
SELECT
    pr.cod_producto, pr.nombre AS producto, cat.nombre AS categoria, pr.stock,
    (SELECT SUM(dp.cantidad)
     FROM detalle_pedido dp
     INNER JOIN pedido p ON p.cod_pedido = dp.cod_pedido
     WHERE dp.cod_producto = pr.cod_producto
       AND p.estado = 'confirmado'
       AND p.estado_pago = 'aprobado') AS unidades_vendidas,
    (SELECT MAX(p.fecha_pedido)
     FROM detalle_pedido dp
     INNER JOIN pedido p ON p.cod_pedido = dp.cod_pedido
     WHERE dp.cod_producto = pr.cod_producto
       AND p.estado = 'confirmado'
       AND p.estado_pago = 'aprobado') AS ultima_venta
FROM producto pr
INNER JOIN categoria cat ON cat.cod_categoria = pr.cod_categoria
WHERE pr.stock < (SELECT AVG(CAST(p2.stock AS DECIMAL(10,2))) FROM producto p2)
  AND EXISTS (SELECT 1
              FROM detalle_pedido dp2
              INNER JOIN pedido p3 ON p3.cod_pedido = dp2.cod_pedido
              WHERE dp2.cod_producto = pr.cod_producto
                AND p3.estado = 'confirmado'
                AND p3.estado_pago = 'aprobado')
ORDER BY pr.stock, pr.nombre;

--  11  Productos mas caros que todos los de una categoria
--      Productos cuyo precio de lista supera al de CADA producto de @categoria_ref.
--      Tablas: producto, categoria
--      Tecnica: operador > ALL. Atencion: si @categoria_ref no existe, la subconsulta queda
--      vacia y > ALL resulta verdadero para todos los productos.
-- ---------------------------------------------------------------
DECLARE @categoria_ref NVARCHAR(50) = N'Línea blanca';

SELECT
    pr.cod_producto,
    pr.nombre                                            AS producto,
    cat.nombre                                           AS categoria,
    pr.precio_lista
FROM producto pr
INNER JOIN categoria cat ON cat.cod_categoria = pr.cod_categoria
WHERE pr.precio_lista > ALL (SELECT p2.precio_lista
                             FROM producto p2
                             INNER JOIN categoria c2 ON c2.cod_categoria = p2.cod_categoria
                             WHERE c2.nombre = @categoria_ref)
ORDER BY pr.precio_lista DESC;

--  12  Ultimo pedido de cada cliente
--      Estado del ultimo pedido (cualquiera sea su estado) de cada cliente.
--      Tablas: pedido, cliente
--      Tecnica: subconsulta escalar correlacionada con MAX en el WHERE.
-- ---------------------------------------------------------------
SELECT
    cl.cod_cliente, cl.nombre + ' ' + cl.apellido AS cliente, p.cod_pedido, p.fecha_pedido,
    p.estado, p.estado_pago
FROM pedido p
INNER JOIN cliente cl ON cl.cod_cliente = p.cod_cliente
WHERE p.fecha_pedido = (SELECT MAX(p2.fecha_pedido)
                        FROM pedido p2
                        WHERE p2.cod_cliente = p.cod_cliente)
ORDER BY p.fecha_pedido DESC;


--  13  Facturas por encima del promedio de su tipo
--      Facturas cuyo total supera el promedio de las facturas del mismo tipo (A, B o C).
--      Tablas: factura
--      Tecnica: subconsulta escalar correlacionada con AVG en el WHERE y en el SELECT.
-- ---------------------------------------------------------------
SELECT
    f.cod_factura,
    f.tipo_comprobante,
    RIGHT('0000'     + CAST(f.punto_venta AS VARCHAR(4)), 4) + '-' +
    RIGHT('00000000' + CAST(f.numero      AS VARCHAR(8)), 8)  AS nro_comprobante,
    f.total,
    ROUND((SELECT AVG(f3.total)
           FROM factura f3
           WHERE f3.tipo_comprobante = f.tipo_comprobante), 2) AS promedio_del_tipo
FROM factura f
WHERE f.total > (SELECT AVG(f2.total)
                 FROM factura f2
                 WHERE f2.tipo_comprobante = f.tipo_comprobante)
ORDER BY f.tipo_comprobante, f.total DESC;
GO

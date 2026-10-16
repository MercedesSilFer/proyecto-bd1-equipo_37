# Consultas de negocio avanzadas

**Archivo:** [consulta_avanzada.sql](../../sql/consulta_avanzada.sql)

Se desarrollan 13 consultas que combinan tablas mediante "JOIN" y aplican filtros condicionales con "HAVING" y subconsultas:


| Consulta | Necesidad | Tipo de subconsulta |
|---|---|---|
| 1 | Clientes de alto valor | HAVING con subconsulta escalar y tabla derivada |
| 2 | Productos con margen bajo | CTE + HAVING |
| 3 | Proveedores principales | HAVING con subconsulta escalar |
| 4 | Clientes sin compras concretadas | NOT EXISTS correlacionada |
| 5 | Actividad de cada usuario interno | Subconsultas escalares en el SELECT |
| 6 | Clientes que compraron una categoría | IN anidado en 4 niveles |
| 7 | Productos en promoción vigente | EXISTS + subconsultas en el SELECT |
| 8 | Proveedores sin compras recibidas | NOT EXISTS |
| 9 | Pedido de mayor importe | Tablas derivadas + MAX en el WHERE |
| 10 | Productos a reponer | Subconsulta escalar (AVG) + EXISTS |
| 11 | Productos más caros que toda una categoría | > ALL |
| 12 | Último pedido de cada cliente | Subconsulta correlacionada con MAX|
| 13 | Facturas sobre el promedio de su tipo | Subconsulta correlacionada con AVG |

---

## 1 — Clientes de alto valor

### Necesidad de información

Identificar los clientes que compran por encima del promedio, para priorizar su atención o campañas comerciales.

**Reglas de negocio relacionadas:** solo se consideran ventas los pedidos confirmados con pago aprobado; cada pedido pertenece a un único cliente.

### Estrategia SQL

Une "cliente", "pedido" y "detalle_pedido" (3 tablas) y agrupa por cliente. El filtro condicional está en el HAVING: el total comprado por el cliente debe ser mayor que una **subconsulta escalar** que calcula el promedio de compra por cliente. Esa subconsulta usa una tabla derivada que primero suma el total de cada cliente y luego promedia esos totales. Se informan además la cantidad de pedidos, el ticket promedio y la fecha del último pedido.

### Resultado esperado

El promedio de compra por cliente es **$ 407.538,89** (9 clientes con ventas; Federico Molina no tiene ninguna venta confirmada). Superan ese promedio 4 clientes:

| Cliente | Ciudad | Provincia | Pedidos | Total comprado | Ticket promedio |
|---|---|---|---|---|---|
| Tomás Benítez | Posadas | MISIONES | 1 | 858.000,00 | 858.000,00 |
| Camila Ortiz | Córdoba | CÓRDOBA | 1 | 630.000,00 | 630.000,00 |
| Valentina Díaz | Buenos Aires | CIUDAD AUTÓNOMA DE BUENOS AIRES | 1 | 500.000,00 | 500.000,00 |
| Sofía Acosta | Resistencia | CHACO | 1 | 479.999,99 | 479.999,99 |

Agustina Ríos queda apenas por debajo del promedio (405.000,01).

---
```sql
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

```
## 2 — Productos con margen bajo

### Necesidad de información

Detectar los productos cuyo margen de ganancia es inferior a un mínimo definido (por defecto 25 %), comparando lo vendido contra lo que costó comprarlo, para revisar precios o condiciones con proveedores.

**Reglas de negocio relacionadas:** el costo unitario de compra queda registrado en el detalle de cada compra; el precio de venta queda registrado (con IVA) en el detalle del pedido junto con el IVA del renglón.

### Estrategia SQL

- Una **CTE** (costo_prod) calcula el costo promedio ponderado de cada producto a partir de "detalle_compra" y "compra", considerando solo compras en estado "recibida".
- La consulta principal une "detalle_pedido", "pedido", "producto", "categoria" y la CTE (5 tablas) y agrupa por producto.
- La venta se toma **neta de IVA** (cantidad × precio_unitario_venta − iva_monto) para compararla con un costo sin IVA, y el margen es "venta_neta − unidades × costo_promedio".
- El HAVING conserva solo los productos cuyo margen porcentual es menor a "@margen_minimo".
- Supuesto: el "costo_unitario" de las compras está expresado sin IVA.

### Resultado esperado

Con `@margen_minimo = 25`, se listan 4 de los 10 productos:

| Producto | Categoría | Unidades | Venta neta | Costo total | Margen | Margen % |
|---|---|---|---|---|---|---|
| Funda Notebook | Accesorios | 4 | 19.504,13 | 16.800,00 | 2.704,13 | 13,86 |
| Smart TV 50" | Televisores | 2 | 491.735,54 | 420.000,00 | 71.735,54 | 14,59 |
| Parlante BT portátil | Audio | 2 | 84.090,91 | 64.250,00 | 19.840,91 | 23,59 |
| Auriculares BT | Audio | 4 | 76.446,29 | 58.342,86 | 18.103,43 | 23,68 |

*Observación :* el margen del Smart TV está condicionado por la venta del Hot Sale (precio con 30 % de descuento), cuyo neto es de  202.479,34 (quedó por debajo de su costo de $ 210.000,00). Los importes pueden diferir en ±0,01 según el redondeo del motor.

---
```sql
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
```
## 3 — Proveedores principales

### Necesidad de información

Identificar los proveedores con mayor volumen de compras (por encima del promedio por proveedor), para evaluar la dependencia de abastecimiento y negociar condiciones.

**Reglas de negocio relacionadas:** el vínculo proveedor–producto surge de las compras realizadas; solo las compras recibidas cuentan como compras efectivas.

### Estrategia SQL

Une "proveedor", "compra" y "detalle_compra" (3 tablas), filtra compras "recibida" y agrupa por proveedor, informando cantidad de compras, productos distintos, unidades y monto comprado. El HAVING compara el monto de cada proveedor contra una subconsulta escalar que calcula el promedio de monto comprado por proveedor.

### Resultado esperado

El promedio por proveedor es **$ 3.852.000,00** (7 proveedores con compras recibidas; las compras 9 —pendiente— y 10 —cancelada— no se computan). Superan ese promedio 3 proveedores:

| Proveedor | Provincia | Compras | Productos distintos | Unidades | Monto comprado |
|---|---|---|---|---|---|
| Informática Central S.A. | CIUDAD AUTÓNOMA DE BUENOS AIRES | 1 | 2 | 22 | 7.160.000,00 |
| ElectroMayorista S.A. | CIUDAD AUTÓNOMA DE BUENOS AIRES | 1 | 2 | 25 | 6.600.000,00 |
| Línea Blanca Argentina S.A. | BUENOS AIRES | 1 | 2 | 14 | 4.560.000,00 |


---
```sql
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
```
## 4 — Clientes sin compras concretadas

### Necesidad de información

Identificar los clientes registrados que nunca concretaron una compra, para ofrecerles seguimiento o una promoción de primera compra.

**Reglas de negocio relacionadas:** los clientes se registran por sí mismos; solo los pedidos confirmados con pago aprobado constituyen ventas.

### Estrategia SQL

NOT EXISTS con una subconsulta **correlacionada**: para cada cliente se busca si existe algún pedido confirmado y pagado; si no existe, el cliente se lista. Además, una subconsulta escalar en el SELECT cuenta cuántos pedidos registró en total (de cualquier estado), lo que permite distinguir al cliente que nunca pidió del que pidió pero no pudo concretar.

### Resultado esperado

| Cliente | Ciudad | Provincia | Fecha de registro | Pedidos registrados |
|---|---|---|---|---|
| Federico Molina | Mendoza | MENDOZA | 2026-08-09 | 1 |

Su único pedido (el 10) quedó en estado pendiente con pago pendiente.

---
```sql
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
```
## 5 — Actividad de cada usuario interno

### Necesidad de información

Conocer cuántas operaciones registró cada usuario interno (pedidos gestionados, compras registradas, facturas emitidas y cambios auditados), para controlar la carga de trabajo y verificar que cada rol opere dentro de sus funciones.

**Reglas de negocio relacionadas:** toda operación interna se realiza a través de un usuario con rol; depósito gestiona compras y despachos, administrador gestiona el catálogo, y soporte solo consulta, sin permisos sobre compras ni catálogo; los cambios sobre datos sensibles quedan en la auditoría.

### Estrategia SQL

Cuatro **subconsultas escalares correlacionadas en el SELECT** (una por tipo de operación), cada una con un COUNT(*) filtrado por el usuario de la fila. Se encierran en una tabla derivada para poder sumar las cuatro columnas y ordenar por el total.

### Resultado esperado

| Usuario | Rol | Pedidos gestionados | Compras registradas | Facturas emitidas | Cambios auditados | Total |
|---|---|---|---|---|---|---|
| lramirez | DEPOSITO | 3 | 3 | 0 | 2 | 8 |
| afernandez | DEPOSITO | 2 | 3 | 0 | 3 | 8 |
| mgonzalez | ADMINISTRADOR | 0 | 0 | 4 | 3 | 7 |
| jperez | ADMINISTRADOR | 0 | 0 | 3 | 1 | 4 |
| csosa | DEPOSITO | 2 | 2 | 0 | 0 | 4 |
| vlopez | ADMINISTRADOR | 0 | 0 | 3 | 1 | 4 |
| rmolina | DEPOSITO | 1 | 2 | 0 | 0 | 3 |
| mbenitez | SOPORTE | 0 | 0 | 0 | 0 | 0 |
| dacosta | SOPORTE | 0 | 0 | 0 | 0 | 0 |
| nsilva | SOPORTE | 0 | 0 | 0 | 0 | 0 |

*Observación:* los usuarios de depósito registran pedidos y compras, los administradores emiten las facturas, y los de soporte no registran operaciones, lo que es coherente con su rol de solo consulta. Ante igual total, se ordena por código de usuario.

---
```sql
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
```
## 6 — Clientes que compraron productos de una categoría

### Necesidad de información

Obtener los clientes que compraron algún producto de una categoría dada (por defecto, "Audio"), por ejemplo para comunicarles novedades o accesorios relacionados.

**Reglas de negocio relacionadas:** solo las ventas confirmadas y pagadas cuentan; cada producto pertenece a una única categoría.

### Estrategia SQL

IN con **subconsultas anidadas en cuatro niveles**: categoría → productos de esa categoría → pedidos que los incluyen → clientes de esos pedidos (solo ventas). Como IN evalúa pertenencia, cada cliente aparece una sola vez aunque haya comprado la categoría en varios pedidos. El nombre de la categoría se toma de "@categoria".

### Resultado esperado

Con @categoria = 'Audio':

| Cliente | Ciudad | Provincia |
|---|---|---|
| Martín Romero | Corrientes | CORRIENTES |
| Joaquín Fernández | Santa Fe | SANTA FE |
| Agustina Ríos | Salta | SALTA |

Martín Romero compró productos de Audio en dos pedidos (el 2 y el 12) y aparece una sola vez.

---
```sql
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
```
## 7 — Productos en promoción vigente

### Necesidad de información

Listar los productos alcanzados por alguna promoción vigente en una fecha dada, con el mayor descuento y la mayor cantidad de cuotas disponibles, para mostrarlos en la tienda o en una campaña.

**Reglas del modelo relacionadas:** una promoción tiene fecha de inicio y de fin, y puede aplicarse a varios productos; un producto puede estar en varias promociones, y una promoción puede ofrecer descuento, cuotas o ambos.

### Estrategia SQL

EXISTS con una subconsulta que une 'promocion' y 'promocion_producto' y verifica que '@fecha' esté entre el inicio y el fin de alguna promoción del producto. Dos subconsultas escalares en el SELECT (MAX del descuento y MAX de las cuotas) resumen lo que ofrece cada producto cuando participa en más de una promoción. MAX ignora los valores nulos, por lo que una promoción solo en cuotas no anula el descuento de otra. Para consultar la fecha de hoy se reemplaza el valor de '@fecha' por 'GETDATE()'.

### Resultado esperado

Con @fecha = '2026-10-10' (vigentes: Línea Blanca en cuotas, Liquidación Accesorios y Día de la Madre):

| Producto | Precio de lista | Mayor descuento % | Máx. cuotas |
|---|---|---|---|
| Heladera 300L | 396.694,21 | — | 12 |
| Funda Notebook | 6.611,57 | 35,00 | — |
| Lavarropas automático 8kg | 520.661,16 | — | 12 |
| Microondas 25L | 140.495,87 | 15,00 | 12 |

El Microondas está en dos promociones vigentes (cuotas de Línea Blanca y 15 % del Día de la Madre).

---
```sql
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
```
## 8 — Proveedores sin compras recibidas

### Necesidad de información

Detectar los proveedores dados de alta que todavía no concretaron ninguna compra, para depurar el listado o decidir si se los activa.

**Reglas de negocio relacionadas:** el vínculo entre proveedor y producto surge de las compras realizadas; solo las compras recibidas son efectivas; un proveedor puede existir en el catálogo sin tener compras.

### Estrategia SQL

NOT EXISTS con subconsulta correlacionada sobre 'compra' en estado 'recibida'. Se prefiere a 'NOT IN' porque 'NOT IN' devuelve un resultado vacío si la subconsulta contiene algún 'NULL'. Una subconsulta escalar en el 'SELECT' cuenta las compras registradas en cualquier estado, para explicar por qué cada proveedor aparece en el resultado.

### Resultado esperado

| Proveedor | Provincia | Compras registradas |
|---|---|---|
| Distribuidora Litoral S.A. | CORRIENTES | 1 |
| Tecnología del Norte S.R.L. | CHACO | 0 |
| Distribuidora Andina S.R.L. | MENDOZA | 1 |

Distribuidora Litoral tiene una compra pendiente y Distribuidora Andina una cancelada; Tecnología del Norte nunca compró.

---
```sql
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
```
## 9 — Pedido de mayor importe

### Necesidad de información

Identificar la venta más grande registrada, con su cliente y fecha.

**Reglas de negocio relacionadas:** el monto de un pedido no se almacena; se calcula a partir de los renglones del detalle (cantidad por precio unitario de venta).

### Estrategia SQL

Una tabla derivada calcula el importe de cada pedido (SUM sobre 'detalle_pedido'). En el WHERE, el importe debe ser igual a (SELECT MAX(...)), una **subconsulta escalar no correlacionada** que a su vez calcula el máximo sobre otra tabla derivada limitada a las ventas. Si hubiera dos pedidos con el mismo importe máximo, ambos se listarían.

### Resultado esperado

| Pedido | Cliente | Fecha | Importe |
|---|---|---|---|
| 4 | Tomás Benítez | 2026-07-20 21:10 | 858.000,00 |

---
```sql
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
```
## 10 — Productos a reponer

### Necesidad de información

Obtener los productos con poco stock que además se vendieron, para priorizar su reposición con proveedores.

**Reglas de negocio relacionadas:** el stock se almacena como valor del producto y baja con cada venta confirmada; solo las ventas confirmadas y pagadas cuentan.

### Estrategia SQL

En el WHERE se combinan dos subconsultas: una escalar (AVG del stock de todos los productos, que se compara con el stock del producto) y un EXISTS correlacionado que exige al menos una venta. En el SELECT, dos subconsultas escalares correlacionadas informan las unidades vendidas y la fecha de la última venta. El promedio se calcula con el stock convertido a decimal para no perder los decimales.

### Resultado esperado

El stock promedio es 17,1 unidades. Quedan 6 productos por debajo:

| Producto | Categoría | Stock | Unidades vendidas | Última venta |
|---|---|---|---|---|
| Lavarropas automático 8kg | Línea blanca | 5 | 1 | 2026-09-05 19:30 |
| Heladera 300L | Línea blanca | 6 | 1 | 2026-07-03 09:05 |
| Notebook 15.6" Core i5 | Notebooks | 8 | 1 | 2026-07-20 21:10 |
| Impresora multifunción | Informática | 10 | 1 | 2026-08-18 12:00 |
| Smart TV 50" | Televisores | 12 | 2 | 2026-09-26 20:15 |
| Microondas 25L | Pequeños electrodomésticos | 15 | 1 | 2026-09-18 11:45 |

---
```sql
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
```
## 11 — Productos más caros que todos los de una categoría

### Necesidad de información

Encontrar los productos cuyo precio de lista supera al de **todos** los productos de una categoría de referencia (por defecto, 'Línea blanca'), por ejemplo para analizar el posicionamiento de precios.

**Reglas de negocio relacionadas:** cada producto pertenece a una única categoría; el precio de lista se gestiona en valor neto.

### Estrategia SQL

El operador '> ALL' compara el precio del producto contra **cada uno** de los precios devueltos por la subconsulta (los productos de la categoría de @categoria_ref); es verdadero solo si es mayor que todos. Es equivalente a comparar con el máximo de la categoría. Atención: si el nombre de la categoría no existe, la subconsulta queda vacía y '> ALL resulta verdadero para todos los productos.

### Resultado esperado

Con @categoria_ref = 'Línea blanca' (el producto más caro de esa categoría es el Lavarropas, de 520.661,16):

| Producto | Categoría | Precio de lista |
|---|---|---|
| Notebook 15.6" Core i5 | Notebooks | 769.230,77 |


---
```sql
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
```
## 12 — Último pedido de cada cliente

### Necesidad de información

Conocer el estado del último pedido de cada cliente, sea cual fuere su resultado, para hacer seguimiento de los que no se concretaron.

**Reglas de negocio relacionadas:** un pedido puede estar pendiente, confirmado o cancelado, y su estado de pago es independiente (pendiente, aprobado o rechazado).

### Estrategia SQL

Subconsulta escalar **correlacionada** con `MAX(fecha_pedido)` en el `WHERE`: para cada pedido se busca la fecha más reciente entre los pedidos del mismo cliente y se conserva solo el que coincide. Si un cliente tuviera dos pedidos con exactamente la misma fecha y hora, ambos se mostrarían.

### Resultado esperado

| Cliente | Pedido | Fecha | Estado | Estado de pago |
|---|---|---|---|---|
| Martín Romero | 12 | 2026-09-29 10:40 | confirmado | aprobado |
| Lucía Gómez | 11 | 2026-09-28 17:50 | cancelado | rechazado |
| Federico Molina | 10 | 2026-09-27 13:05 | pendiente | pendiente |
| Agustina Ríos | 9 | 2026-09-26 20:15 | confirmado | aprobado |
| Nicolás Vera | 8 | 2026-09-18 11:45 | confirmado | aprobado |
| Camila Ortiz | 7 | 2026-09-05 19:30 | confirmado | aprobado |
| Joaquín Fernández | 6 | 2026-08-18 12:00 | confirmado | aprobado |
| Valentina Díaz | 5 | 2026-08-02 16:25 | confirmado | aprobado |
| Tomás Benítez | 4 | 2026-07-20 21:10 | confirmado | aprobado |
| Sofía Acosta | 3 | 2026-07-03 09:05 | confirmado | aprobado |

Se obtiene una fila por cliente. Los casos para hacer seguimiento son Lucía Gómez (pago rechazado) y Federico Molina (pedido pendiente).

---
```sql
SELECT
    cl.cod_cliente, cl.nombre + ' ' + cl.apellido AS cliente, p.cod_pedido, p.fecha_pedido,
    p.estado, p.estado_pago
FROM pedido p
INNER JOIN cliente cl ON cl.cod_cliente = p.cod_cliente
WHERE p.fecha_pedido = (SELECT MAX(p2.fecha_pedido)
                        FROM pedido p2
                        WHERE p2.cod_cliente = p.cod_cliente)
ORDER BY p.fecha_pedido DESC;
```
## 13 — Facturas por encima del promedio de su tipo

### Necesidad de información

Detectar las facturas de mayor importe que el promedio de su propio tipo de comprobante (A, B o C), para analizar la composición de la facturación.

**Reglas de negocio relacionadas:** los comprobantes son de tipo A, B o C; el total de cada factura se fija al emitirla.

### Estrategia SQL

Subconsulta escalar **correlacionada** con AVG(total) en el WHERE: para cada factura se calcula el promedio de las facturas de su mismo 'tipo_comprobante' y se conserva la que lo supera. La misma subconsulta, redondeada, se repite en el SELECT para mostrar el promedio contra el que se comparó.

### Resultado esperado

| Factura | Tipo | Nº comprobante | Total | Promedio del tipo |
|---|---|---|---|---|
| 3 | A | 0001-00000003 | 479.999,99 | 365.000,00 |
| 4 | B | 0001-00000004 | 858.000,00 | 367.231,25 |
| 7 | B | 0001-00000007 | 630.000,00 | 367.231,25 |
| 5 | B | 0001-00000005 | 500.000,00 | 367.231,25 |
| 9 | B | 0001-00000009 | 405.000,01 | 367.231,25 |

Los importes del promedio pueden diferir en ±0,01 según el redondeo del motor.
```sql
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
```

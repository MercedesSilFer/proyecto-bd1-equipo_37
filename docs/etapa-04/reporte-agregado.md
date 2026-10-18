# Reporte agregado de ventas por categoría

**Archivo:** [reporte_agregado.sql](../../sql/consultas/reporte_agregado.sql)

Se desarrollan 2 consultas que informan el total de ventas por categoría de producto en un rango de fechas. El reporte se arma por categoría y no por vendedor porque en el modelo no existe el rol vendedor: en el e-commerce el pedido lo genera el cliente directamente (RN.12). El rango se indica en las variables `@fecha_desde` y `@fecha_hasta` (ambas fechas incluidas).

| Consulta | Necesidad | Técnica |
|---|---|---|
| 1 | Ventas por categoría | INNER JOIN de 4 tablas + GROUP BY + COUNT y SUM |
| 2 | Ventas por categoría principal | LEFT JOIN de categoria consigo misma + COALESCE + GROUP BY |

---

## 1 — Ventas por categoría

### Necesidad de información

Conocer, para un período determinado, cuántas ventas incluyeron productos de cada categoría, cuántas unidades se vendieron y cuál fue el importe vendido (con IVA y neto), para comparar qué categorías generan más ingresos.

**Reglas de negocio relacionadas:** solo se consideran ventas los pedidos confirmados con pago aprobado (RN.05); cada producto pertenece a una única categoría (RN.06); el importe se calcula con el precio congelado en el detalle del pedido (RN.03, RN.10).

### Estrategia SQL

Une "pedido", "detalle_pedido", "producto" y "categoria" (4 tablas) y agrupa por categoría con GROUP BY. Por cada grupo se calculan:

- **cant_ventas** = `COUNT(DISTINCT cod_pedido)`: cuenta pedidos distintos, para que un pedido con dos productos de la misma categoría se cuente una sola vez.
- **unidades_vendidas** = `SUM(cantidad)`.
- **total_vendido** = `SUM(cantidad × precio_unitario_venta)`, con IVA incluido (RN.19).
- **total_neto** = `SUM(cantidad × precio_unitario_venta − iva_monto)`, sin IVA.

El filtro de fechas usa `fecha_pedido >= @fecha_desde AND fecha_pedido < DATEADD(DAY, 1, @fecha_hasta)`. Como "fecha_pedido" es DATETIME, comparar con `<= @fecha_hasta` dejaría afuera los pedidos de ese último día posteriores a las 00:00; sumando un día y usando `<` se incluye el día completo.

### Resultado esperado

Con `@fecha_desde = '2026-07-01'` y `@fecha_hasta = '2026-09-30'` (8 ventas: pedidos 3 a 9 y 12):

| Categoría | Ventas | Unidades | Total vendido | Total neto |
|---|---|---|---|---|
| Línea blanca | 2 | 2 | 1.109.999,99 | 917.355,37 |
| Notebooks | 1 | 1 | 850.000,00 | 769.230,77 |
| Celulares | 1 | 1 | 500.000,00 | 413.223,14 |
| Televisores | 1 | 1 | 350.000,00 | 289.256,20 |
| Informática | 1 | 1 | 225.000,00 | 185.950,41 |
| Pequeños electrodomésticos | 1 | 1 | 170.000,00 | 140.495,87 |
| Audio | 3 | 3 | 105.000,01 | 86.776,87 |
| Accesorios | 3 | 4 | 23.600,00 | 19.504,13 |

*Observación:* la suma de "total_vendido" de todas las categorías (3.333.600,00) coincide con el total de las 8 ventas del período. En cambio, la suma de "cant_ventas" (13) es mayor que 8, porque un mismo pedido con productos de distintas categorías se cuenta en cada una (por ejemplo, el pedido 4 incluye una notebook y una funda).

---
```sql
DECLARE @fecha_desde DATE = '2026-07-01';
DECLARE @fecha_hasta DATE = '2026-09-30';

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
  AND p.fecha_pedido <  DATEADD(DAY, 1, @fecha_hasta)   --incluye todo el dia @fecha_hasta
GROUP BY cat.cod_categoria, cat.nombre
ORDER BY total_vendido DESC;
```

## 2 — Ventas por categoría principal

### Necesidad de información

Obtener el mismo reporte a nivel de categoría principal, sumando cada subcategoría dentro de su categoría padre (por ejemplo, Audio y Televisores dentro de Electrónica), para tener una vista más resumida del negocio.

**Reglas de negocio relacionadas:** las categorías se organizan en una jerarquía de un nivel mediante "cod_categoria_padre" (ver restricciones-integridad.md); se mantiene el mismo criterio de venta que en la consulta 1.

### Estrategia SQL

Además de las 4 tablas de la consulta 1, se une "categoria" **consigo misma** (alias "padre") mediante `LEFT JOIN padre ON padre.cod_categoria = cat.cod_categoria_padre`:

- Si la categoría del producto es una subcategoría (por ejemplo, Audio), el LEFT JOIN trae su padre (Electrónica).
- Si es una categoría de primer nivel (por ejemplo, Celulares), no tiene padre y las columnas de "padre" quedan en NULL. Por eso se usa LEFT JOIN y no INNER JOIN: con INNER JOIN esos productos quedarían afuera del reporte.
- `COALESCE(padre.nombre, cat.nombre)` devuelve el nombre del padre si existe, y si no, el de la propia categoría. Se agrupa por ese valor.

### Resultado esperado

Con el mismo rango (`'2026-07-01'` a `'2026-09-30'`):

| Categoría principal | Ventas | Unidades | Total vendido | Total neto |
|---|---|---|---|---|
| Electrodomésticos | 3 | 3 | 1.279.999,99 | 1.057.851,24 |
| Informática | 2 | 2 | 1.075.000,00 | 955.181,18 |
| Celulares | 1 | 1 | 500.000,00 | 413.223,14 |
| Electrónica | 3 | 4 | 455.000,01 | 376.033,07 |
| Accesorios | 3 | 4 | 23.600,00 | 19.504,13 |

*Observación:* Electrónica suma Televisores (350.000,00) y Audio (105.000,01). Tiene 3 ventas y no 4 (1 + 3), porque el pedido 9 incluye un televisor y un parlante y COUNT(DISTINCT) lo cuenta una sola vez. El total general sigue siendo 3.333.600,00.

---
```sql
DECLARE @fecha_desde DATE = '2026-07-01';
DECLARE @fecha_hasta DATE = '2026-09-30';

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
```
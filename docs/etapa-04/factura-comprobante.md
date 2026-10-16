# Factura / Comprobante de venta

**Archivo:** [factura_comprobante.sql](../../sql/consultas/factura_comprobante.sql)

Se desarrollan 2 consultas que, juntas, reproducen el comprobante de una venta: el encabezado (datos fiscales, cliente, pedido y totales) y el detalle (un renglón por producto con su subtotal y el total acumulado). Ambas reciben el pedido a consultar en la variable `@cod_pedido`.

| Consulta | Necesidad | Técnica |
|---|---|---|
| 1 | Encabezado del comprobante | INNER JOIN de 5 tablas + subconsulta escalar de control |
| 2 | Detalle del comprobante | INNER JOIN + columnas calculadas + SUM() OVER |

---

## 1 — Encabezado del comprobante

### Necesidad de información

Obtener en una sola fila todos los datos que se imprimen en la cabecera de la factura de un pedido: tipo y número de comprobante, CAE, datos fiscales y nombre del cliente, domicilio de entrega, método de pago, usuario que la emitió y los totales.

**Reglas de negocio relacionadas:** todo pedido confirmado y pagado genera un único comprobante (RN.17); los datos fiscales del cliente se registran solo en la factura (RN.18); toda factura queda asociada al usuario que la emitió (RN.21).

### Estrategia SQL

Une "factura", "pedido", "cliente", "metodo_pago" y "usuario" (5 tablas). El nombre del cliente no se guarda en la factura, se obtiene siguiendo la relación factura → pedido → cliente (decisión de diseño 5). El número de comprobante se arma con el formato fiscal `PPPP-NNNNNNNN` (punto de venta y número completados con ceros).

Como control, una **subconsulta escalar** recalcula el total desde "detalle_pedido" (cantidad × precio_unitario_venta) en la columna "total_calculado", que debe coincidir con el total registrado en la factura.

### Resultado esperado

Con `@cod_pedido = 4`:

| Campo | Valor |
|---|---|
| Comprobante | B 0001-00000004 |
| Fecha de emisión | 2026-07-20 |
| CAE / Vto. | 75432100000054 / 2026-07-30 |
| Cliente | Tomás Benítez — Consumidor Final — DNI 40221334 |
| Domicilio de entrega | Av. Mitre 2100, Posadas, MISIONES (3300) |
| Pedido / Método de pago | 4 (2026-07-20 21:10) / MODO |
| Emitida por | mgonzalez |
| Subtotal (neto) | 775.842,34 |
| IVA | 82.157,66 |
| **Total** | **858.000,00** |
| Total calculado desde el detalle | 858.000,00 |

Con `@cod_pedido = 3` se obtiene la factura A 0001-00000003 de Sofía Acosta (Responsable Inscripto, CUIT 27-31456789-4) por $ 479.999,99. Si el pedido no tiene factura (por ejemplo, el 10, que está pendiente), la consulta no devuelve filas.

---
```sql
DECLARE @cod_pedido INT = 4;

SELECT
    f.tipo_comprobante,
    RIGHT('0000'     + CAST(f.punto_venta AS VARCHAR(4)), 4) + '-' +
    RIGHT('00000000' + CAST(f.numero      AS VARCHAR(8)), 8)  AS nro_comprobante,
    f.fecha_emision, f.cae, f.fecha_vto_cae,
    c.nombre + ' ' + c.apellido                               AS cliente,
    f.razon_social, f.cond_iva_cliente, f.tipo_documento_cliente, f.nro_documento_cliente,
    p.calle + ' ' + p.numero + ', ' + p.ciudad + ', ' + p.provincia
        + ' (' + p.cod_postal + ')'                           AS domicilio_entrega,
    p.cod_pedido, p.fecha_pedido, mp.nombre                   AS metodo_pago,
    u.nombre_usuario                                          AS emitida_por,
    f.subtotal, f.iva_total, f.total,
    (SELECT SUM(dp.cantidad * dp.precio_unitario_venta)
     FROM detalle_pedido dp
     WHERE dp.cod_pedido = p.cod_pedido)                      AS total_calculado
FROM factura f
INNER JOIN pedido      p  ON p.cod_pedido       = f.cod_pedido
INNER JOIN cliente     c  ON c.cod_cliente      = p.cod_cliente
INNER JOIN metodo_pago mp ON mp.cod_metodo_pago = p.cod_metodo_pago
INNER JOIN usuario     u  ON u.cod_usuario      = f.cod_usuario
WHERE f.cod_pedido = @cod_pedido;
```

## 2 — Detalle del comprobante

### Necesidad de información

Listar los renglones de la factura con el producto, la cantidad, el precio unitario y la alícuota aplicada, calculando el subtotal de cada renglón (separando neto e IVA) y el total acumulado hasta llegar al total del comprobante.

**Reglas de negocio relacionadas:** el precio unitario y la alícuota quedan congelados en el detalle al confirmarse la venta (RN.03, RN.28); el monto total no se almacena en el pedido, se calcula a partir de sus renglones (RN.10).

### Estrategia SQL

Une "factura", "detalle_pedido" y "producto" (3 tablas). Por cada renglón se calculan:

- **subtotal_renglon** = cantidad × precio_unitario_venta (con IVA incluido, RN.19).
- **neto_renglon** = subtotal_renglon − iva_monto.
- **total_acumulado** = `SUM(...) OVER (ORDER BY item ROWS UNBOUNDED PRECEDING)`, una función de ventana que suma el renglón actual con todos los anteriores sin agrupar las filas, de modo que el último renglón muestra el total del comprobante.

### Resultado esperado

Con `@cod_pedido = 4` (dos productos con alícuotas distintas):

| Ítem | Producto | Cant. | Precio unit. | Alícuota | Subtotal | Neto | IVA | Total acumulado |
|---|---|---|---|---|---|---|---|---|
| 1 | Notebook 15.6" Core i5 | 1 | 850.000,00 | 10,50 | 850.000,00 | 769.230,77 | 80.769,23 | 850.000,00 |
| 2 | Funda Notebook | 1 | 8.000,00 | 21,00 | 8.000,00 | 6.611,57 | 1.388,43 | **858.000,00** |

*Observación:* la suma de los netos (775.842,34) y de los IVA (82.157,66) coincide con el subtotal y el IVA del encabezado, y el total acumulado del último renglón coincide con el total de la factura.

---
```sql
DECLARE @cod_pedido INT = 4;

SELECT
    dp.item,
    pr.cod_producto,
    pr.nombre                                                 AS producto,
    dp.cantidad,
    dp.precio_unitario_venta,
    dp.alicuota_iva,
    dp.cantidad * dp.precio_unitario_venta                    AS subtotal_renglon,
    dp.cantidad * dp.precio_unitario_venta - dp.iva_monto     AS neto_renglon,
    dp.iva_monto                                              AS iva_renglon,
    SUM(dp.cantidad * dp.precio_unitario_venta)
        OVER (ORDER BY dp.item ROWS UNBOUNDED PRECEDING)      AS total_acumulado
FROM factura f
INNER JOIN detalle_pedido dp ON dp.cod_pedido   = f.cod_pedido
INNER JOIN producto       pr ON pr.cod_producto = dp.cod_producto
WHERE f.cod_pedido = @cod_pedido
ORDER BY dp.item;
```

# Consultas y Casos de Uso

Se detalla el resumen de las necesidades de información que resuelve el sistema SmartHome Store mediante consultas SQL, quién las utiliza y en qué archivo se encuentra cada una. El detalle de cada consulta (necesidad, estrategia SQL y resultado esperado) está en su propio archivo.

## Criterios comunes

 **Venta:** pedido con estado 'confirmado' y estado_pago 'aprobado'. Los pedidos pendientes, cancelados o con pago rechazado no se consideran ventas.
**Compra válida:** compra en estado 'recibida' (las pendientes y canceladas no modifican stock ni se computan como compras efectivas).
 **Precios:** 'precio_unitario_venta' incluye IVA; 'iva_monto' es el IVA total de la linea. El neto de una linea es 'cantidad × precio_unitario_venta − iva_monto'.
 
## Casos de uso

| Código | Caso de uso | Actor | Archivo SQL | Documento |
|---|---|---|---|---|
| CU-01 | Identificar los clientes de mayor valor (compran por encima del promedio) | Administrador | `consulta_avanzada.sql` (1) | [consulta-avanzada.md](consulta-avanzada.md) |
| CU-02 | Detectar productos con margen bajo respecto de su costo de compra | Administrador | `consulta_avanzada.sql` (2) | [consulta-avanzada.md](consulta-avanzada.md) |
| CU-03 | Identificar los proveedores con mayor volumen de compras | Administrador, Depósito | `consulta_avanzada.sql` (3) | [consulta-avanzada.md](consulta-avanzada.md) |
| CU-04 | Identificar clientes registrados que todavía no concretaron una compra | Administrador | `consulta_avanzada.sql` (4) | [consulta-avanzada.md](consulta-avanzada.md) |
| CU-05 | Controlar la actividad de cada usuario interno según su rol | Administrador | `consulta_avanzada.sql` (5) | [consulta-avanzada.md](consulta-avanzada.md) |
| CU-06 | Obtener los clientes que compraron productos de una categoría | Administrador | `consulta_avanzada.sql` (6) | [consulta-avanzada.md](consulta-avanzada.md) |
| CU-07 | Listar los productos en promoción vigente en una fecha | Administrador | `consulta_avanzada.sql` (7) | [consulta-avanzada.md](consulta-avanzada.md) |
| CU-08 | Identificar proveedores que todavía no concretaron compras | Administrador, Depósito | `consulta_avanzada.sql` (8) | [consulta-avanzada.md](consulta-avanzada.md) |
| CU-09 | Conocer la venta de mayor importe | Administrador | `consulta_avanzada.sql` (9) | [consulta-avanzada.md](consulta-avanzada.md) |
| CU-10 | Detectar productos con poco stock que tienen ventas (reposición) | Administrador, Depósito | `consulta_avanzada.sql` (10) | [consulta-avanzada.md](consulta-avanzada.md) |
| CU-11 | Comparar el precio de los productos contra toda una categoría | Administrador | `consulta_avanzada.sql` (11) | [consulta-avanzada.md](consulta-avanzada.md) |
| CU-12 | Ver el estado del último pedido de cada cliente | Administrador, Soporte | `consulta_avanzada.sql` (12) | [consulta-avanzada.md](consulta-avanzada.md) |
| CU-13 | Detectar facturas que superan el promedio de su tipo de comprobante | Administrador | `consulta_avanzada.sql` (13) | [consulta-avanzada.md](consulta-avanzada.md) |
| CU-14 | Emitir el comprobante de una venta (encabezado y detalle con subtotales y total acumulado) | Administrador | `factura_comprobante.sql` (1 y 2) | [factura-comprobante.md](factura-comprobante.md) |
| CU-15 | Conocer el total vendido por categoría de producto en un período | Administrador | `reporte_agregado.sql` (1 y 2) | [reporte-agregado.md](reporte-agregado.md) |

*Los permisos definitivos por rol se establecen en la Etapa V (Seguridad).*

Los resultados esperados que figuran en cada documento corresponden a los datos de prueba cargados en el paso 2.

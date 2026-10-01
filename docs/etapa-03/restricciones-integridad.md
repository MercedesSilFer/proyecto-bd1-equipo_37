# Restricciones de Integridad

## 1. Restricciones por tabla

### cliente
- **PRIMARY KEY:** cod_cliente (autogenerada con IDENTITY).
- **UNIQUE:** email, no puede haber dos clientes con el mismo email.
- **CHECK:**
  - activo IN (0,1),  solo admite baja lógica booleana.
  - email LIKE '%_@__%.__%', valida formato mínimo de email (usuario, arroba, dominio, punto, extensión de al menos 2 caracteres).
  - provincia restringido a las 24 provincias/jurisdicciones oficiales de la República Argentina, almacenada en mayúsculas.
- **DEFAULT:** activo = 1, fecha_registro = CAST(GETDATE() AS DATE)`.

### usuario
- **PRIMARY KEY:** cod_usuario.
- **UNIQUE:** nombre_usuario.
- **CHECK:**
  - rol restringido a 'DEPOSITO', 'ADMINISTRADOR', 'SOPORTE', almacenado en mayúsculas.
  - estado IN (0,1).
- **DEFAULT:** estado = 1.

### categoria
- **PRIMARY KEY:** cod_categoria.
- **UNIQUE:** combinación (nombre, cod_categoria_padre) — evita nombres duplicados dentro del mismo nivel jerárquico.
- **FOREIGN KEY:** cod_categoria_padre → categoria.cod_categoria (autorreferencia, para jerarquía de un nivel).
- **CHECK:** activo IN (0,1).
- **DEFAULT:** activo = 1.

### producto
- **PRIMARY KEY:** cod_producto.
- **FOREIGN KEY:** cod_categoria → categoria.cod_categoria.
- **CHECK:**
  - activo IN (0,1).
  - precio_lista > 0.
  - stock >= 0.
  - alicuota_iva BETWEEN 0 AND 100.
- **DEFAULT:** activo = 1.

### proveedor
- **PRIMARY KEY:** cod_proveedor.
- **UNIQUE:** cuit.
- **CHECK:**
  - cuit valida formato "XX-XXXXXXXX-X" (patrón numérico con guiones).
  - provincia restringido a las 24 provincias/jurisdicciones oficiales.
  - activo IN (0,1).
- **DEFAULT:** activo = 1.

### metodo_pago
- **PRIMARY KEY:** cod_metodo_pago.
- **UNIQUE:** nombre.

### pedido
- **PRIMARY KEY:** cod_pedido.
- **FOREIGN KEY:** cod_cliente → cliente, cod_metodo_pago → metodo_pago, cod_usuario → usuario (opcional, NULL hasta que se asigna un responsable de gestión).
- **CHECK:**
  - estado IN ('pendiente', 'confirmado', 'cancelado').
  - estado_pago IN ('pendiente', 'aprobado', 'rechazado').
  - estado_envio IS NULL OR estado_envio IN ('pendiente', 'despachado', 'entregado')`.
  - fecha_pedido <= GETDATE(), no admite fecha futura.
  - estado_pago <> 'aprobado' OR ref_transaccion IS NOT NULL, garantiza que todo pago aprobado tenga su referencia de transacción registrada.
- **DEFAULT:** fecha_pedido = GETDATE(), estado = 'pendiente', estado_pago = 'pendiente'.

### compra
- **PRIMARY KEY:** cod_compra.
- **FOREIGN KEY:** cod_proveedor → proveedor, cod_usuario → usuario.
- **CHECK:**
  - estado IN ('pendiente', 'recibida', 'cancelada').
  - fecha <= GETDATE().
- **DEFAULT:** estado = 'pendiente', fecha = GETDATE().

### auditoria
- **PRIMARY KEY:** cod_auditoria.
- **FOREIGN KEY:** cod_usuario → usuario.
- **CHECK:** operacion IN ('INSERT', 'UPDATE', 'DELETE').
- **DEFAULT:** fecha = GETDATE().

### factura
- **PRIMARY KEY:** cod_factura.
- **FOREIGN KEY:** cod_pedido → pedido, cod_usuario → usuario.
- **UNIQUE:** combinación (punto_venta, numero), un mismo número de comprobante no puede repetirse dentro del mismo punto de venta.
- **CHECK:**
  - subtotal >= 0 AND iva_total >= 0 AND total >= 0.
  - tipo_comprobante IN ('A','B','C').
- **DEFAULT:** fecha_emision = CAST(GETDATE() AS DATE).

### detalle_pedido
- **PRIMARY KEY compuesta:** (cod_pedido, cod_producto).
- **FOREIGN KEY:** cod_pedido → pedido, cod_producto → producto.
- **CHECK:** cantidad > 0, precio_unitario_venta > 0.

### detalle_compra
- **PRIMARY KEY compuesta:** (cod_producto, cod_compra).
- **FOREIGN KEY:** cod_producto → producto, cod_compra → compra.
- **CHECK:** cantidad > 0, costo_unitario > 0.

## 2. Reglas de borrado y modificación (ON DELETE / ON UPDATE)

| # | Relación (FK) | ON DELETE | ON UPDATE | Justificación |
|---|---|---|---|---|
| 1 | categoria.cod_categoria_padre → categoria.cod_categoria | NO ACTION | NO ACTION | Autorreferencia: SQL Server no permite CASCADE en este caso por riesgo de ciclo infinito. Si una categoría tiene subcategorías, no puede borrarse ni modificarse su código sin antes reasignar o eliminar las hijas. |
| 2 | producto.cod_categoria → categoria.cod_categoria | NO ACTION | CASCADE | No se permite eliminar una categoría con productos asociados; se usa baja lógica (activo) en su lugar. |
| 3 | pedido.cod_cliente → cliente.cod_cliente | NO ACTION | CASCADE | Un cliente con pedidos no puede borrarse físicamente: se preserva el historial de ventas y datos fiscales. Se da de baja lógica (activo = 0). |
| 4 | pedido.cod_metodo_pago → metodo_pago.cod_metodo_pago | NO ACTION | CASCADE | No se puede eliminar un método de pago ya utilizado en algún pedido, para no perder la trazabilidad de cómo se abonó esa venta. |
| 5 | pedido.cod_usuario → usuario.cod_usuario | NO ACTION | CASCADE | No se puede eliminar un usuario interno que ya gestionó pedidos; se usa baja lógica (estado), preservando la trazabilidad de auditoría. |
| 6 | compra.cod_proveedor → proveedor.cod_proveedor | NO ACTION | CASCADE | No se puede eliminar un proveedor con historial de compras; se da de baja lógica si se deja de operar con él. |
| 7 | compra.cod_usuario → usuario.cod_usuario | NO ACTION | CASCADE | Protege la trazabilidad de qué usuario registró cada compra. |
| 8 | auditoria.cod_usuario → usuario.cod_usuario | NO ACTION | CASCADE | Un registro de auditoría nunca puede quedar sin el usuario responsable del cambio que audita. |
| 9 | factura.cod_pedido → pedido.cod_pedido | NO ACTION | CASCADE | Una factura, al ser un comprobante fiscal, no puede quedar sin su pedido de origen. Refuerza la inmutabilidad fiscal del comprobante. |
| 10 | factura.cod_usuario → usuario.cod_usuario | NO ACTION | CASCADE | Protege la trazabilidad de qué usuario emitió cada factura. |
| 11 | detalle_pedido.cod_pedido → pedido.cod_pedido | **CASCADE** | CASCADE | Relación de composición: una línea de detalle no tiene existencia propia sin su pedido. Si se elimina un pedido, sus líneas se eliminan junto con él. |
| 12 | detalle_pedido.cod_producto → producto.cod_producto | NO ACTION | CASCADE | No se puede eliminar un producto con ventas registradas; protege el historial de qué se vendió. |
| 13 | detalle_compra.cod_compra → compra.cod_compra | **CASCADE** | CASCADE | Relación de composición, mismo criterio que el caso 11: una línea de detalle de compra no existe sin su compra asociada. |
| 14 | detalle_compra.cod_producto → producto.cod_producto | NO ACTION | CASCADE | No se puede eliminar un producto con compras registradas; protege el historial de qué se compró. |

### Criterio general aplicado

- **`NO ACTION` en DELETE:** se aplica en toda relación hacia una entidad "maestra" con valor histórico o fiscal (cliente, usuario, producto, proveedor, metodo_pago, pedido). Impide el borrado físico y obliga a resolver la baja mediante los campos activo/estado ya definidos en esas tablas.
- **CASCADE en DELETE:** se aplica únicamente en las dos relaciones de composición real (detalle_pedido con pedido, detalle_compra con compra), donde el registro hijo no tiene sentido de existencia independiente del padre.
- **CASCADE en UPDATE:** se aplica de forma uniforme en todas las relaciones. Si bien las claves primarias son IDENTITY y no cambian en la operatoria normal, es la convención estándar recomendada, y no genera los conflictos de rutas múltiples que sí puede generar CASCADE en DELETE.
- **Excepción técnica:** la autorreferencia de categoria usa NO ACTION/NO ACTION en ambos casos, por ser la única opción que SQL Server permite en una relación de una tabla consigo misma.

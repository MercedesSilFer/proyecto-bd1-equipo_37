# Pruebas de Validación

Este documento reúne casos de prueba diseñados para verificar que las restricciones de integridad definidas en "restricciones-integridad.md" funcionan correctamente. Cada caso indica la operación a ejecutar, el resultado esperado y la restricción que lo garantiza.

## 1. Restricciones CHECK

| # | Caso de prueba | Resultado esperado | Restricción que actúa |
|---|---|---|---|
| 1 | Insertar un "cliente" con email = 'mercedessinarroba.com' (sin @) | Falla el INSERT | CK_cliente_email |
| 2 | Insertar un "cliente" con provincia = 'Buenos aires' (minúsculas) | Falla el INSERT | CK_cliente_provincia (exige mayúsculas) |
| 3 | Insertar un "cliente" con provincia = 'Texas' | Falla el INSERT | CK_cliente_provincia (fuera de la lista de provincias argentinas) |
| 4 | Insertar un "usuario con rol = 'vendedor' | Falla el INSERT | CK_usuario_rol (rol no contemplado en el modelo) |
| 5 | Insertar un "producto" con precio_lista = -100 | Falla el INSERT | CK_producto_precio_lista |
| 6 | Insertar un "producto" con stock = -5 | Falla el INSERT | CK_producto_stock |
| 7 | Insertar un "producto" con alicuota_iva = 150 | Falla el INSERT | CK_producto_alicuota (fuera del rango 0-100) |
| 8 | Insertar un "proveedor" con cuit = '301234567' (sin guiones ni dígito verificador) | Falla el INSERT | CK_proveedor_cuit |
| 9 | Insertar un "pedido" con estado = 'en_proceso' (valor no contemplado) | Falla el INSERT | CK_pedido_estado |
| 10 | Insertar un "pedido" con estado_pago = 'aprobado' y ref_transaccion = NULL | Falla el INSERT | CK_pedido_ref_transaccion |
| 11 | Insertar un "pedido" con fecha_pedido posterior a la fecha actual | Falla el INSERT | CK_pedido_fecha |
| 12 | Insertar una "compra" con fecha posterior a la fecha actual | Falla el INSERT | CK_compra_fecha |
| 13 | Insertar un "detalle_pedido" con cantidad = 0 | Falla el INSERT | CK_detalle_pedido_cantidad |
| 14 | Insertar una "factura" con tipo_comprobante = 'X' | Falla el INSERT | CK_factura_tipo_comprobante |
| 15 | Insertar una "factura" con total = -500 | Falla el INSERT | CK_factura_montos |

## 2. Restricciones UNIQUE

| # | Caso de prueba | Resultado esperado | Restricción que actúa |
|---|---|---|---|
| 16 | Insertar dos "cliente" con el mismo email | Falla el segundo INSERT | UQ_cliente_email |
| 17 | Insertar dos "usuario" con el mismo nombre_usuario | Falla el segundo INSERT | UQ_usuario_nombre_usuario |
| 18 | Insertar dos "proveedor" con el mismo cuit | Falla el segundo INSERT | UQ_proveedor_cuit |
| 19 | Insertar dos "factura" con el mismo punto_venta y numero | Falla el segundo INSERT | UQ_factura_pto_nro |
| 20 | Insertar dos "categoria" con el mismo nombre bajo el mismo cod_categoria_padre | Falla el segundo INSERT | UQ_categoria_nombre_padre |

## 3. Restricciones NOT NULL / valores por defecto

| # | Caso de prueba | Resultado esperado | Restricción que actúa |
|---|---|---|---|
| 21 | Insertar un "cliente" sin especificar activo | Se inserta con activo = 1 | DF_cliente_activo |
| 22 | Insertar un "pedido" sin especificar estado ni estado_pago | Se inserta con ambos en 'pendiente' | DF_pedido_estado, DF_pedido_estado_pago |
| 23 | Insertar un "cliente" sin "telefono" | Falla el INSERT | Columna "telefono NOT NULL" |
| 24 | Insertar un "pedido" sin "cod_usuario" | Se inserta correctamente ("cod_usuario" es NULL hasta la gestión de despacho) | Columna cod_usuario NULL |

## 4. Reglas de integridad referencial (FOREIGN KEY)

| # | Caso de prueba | Resultado esperado | Restricción que actúa |
|---|---|---|---|
| 25 | Insertar un "producto" con cod_categoria inexistente | Falla el INSERT | FK_producto_categoria |
| 26 | Insertar un "pedido" con cod_cliente inexistente | Falla el INSERT | FK_pedido_cliente |
| 27 | Insertar un "detalle_pedido" con cod_producto inexistente | Falla el INSERT | FK_detalle_pedido_producto |

## 5. Reglas de borrado (ON DELETE)

| # | Caso de prueba | Resultado esperado | Restricción que actúa |
|---|---|---|---|
| 28 | Intentar eliminar un "cliente que tiene al menos un pedido asociado | Falla el DELETE | FK_pedido_cliente con ON DELETE NO ACTION |
| 29 | Intentar eliminar un "producto" que tiene registros en detalle_pedido | Falla el DELETE | FK_detalle_pedido_producto con ON DELETE NO ACTION |
| 30 | Intentar eliminar una "categoria" que tiene subcategorías asociadas (cod_categoria_padre) | Falla el DELETE | FK_categoria_categoria_padre con ON DELETE NO ACTION |
| 31 | Eliminar un "pedido" de prueba sin factura asociada | Se elimina el pedido y, en cascada, sus líneas de detalle_pedido | FK_detalle_pedido_pedido con ON DELETE CASCADE |
| 32 | Eliminar una "compra" de prueba | Se elimina la compra y, en cascada, sus líneas de detalle_compra | FK_detalle_compra_compra con ON DELETE CASCADE |
| 33 | Intentar eliminar una "factura" existente | Falla el DELETE | FK_factura_pedido con ON DELETE NO ACTION (inmutabilidad fiscal) |

## Observación general

La mayoría de los casos de la sección 5 no representan operaciones habituales del sistema en producción: tanto "pedido" como "compra" cuentan con un estado 'cancelado'/'cancelada' pensado justamente para registrar una anulación sin necesidad de borrar el registro. Las reglas ON DELETE documentadas cubren el comportamiento del motor ante un escenario excepcional (por ejemplo, limpieza de datos de prueba), garantizando que, aun en ese caso, la integridad referencial del esquema se mantenga.

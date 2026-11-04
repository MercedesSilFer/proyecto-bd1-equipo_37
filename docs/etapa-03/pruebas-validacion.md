# Pruebas de Validación

Este documento reúne casos de prueba diseñados para verificar que las restricciones de integridad definidas en "restricciones-integridad.md" funcionan correctamente. Cada caso indica la operación a ejecutar, el resultado esperado y la restricción que lo garantiza.

## 1. Restricciones CHECK

| # | Caso de prueba | Resultado esperado | Restricción que actúa |
|---|---|---|---|
| 1 | Insertar un "cliente" con email = 'mercedessinarroba.com' (sin @) | Falla el INSERT | CK_cliente_email |
| 4 | Insertar un "usuario" con rol = 'vendedor' | Falla el INSERT | CK_usuario_rol (rol no contemplado en el modelo) |
| 5 | Insertar un "producto" con precio_lista = -100 | Falla el INSERT | CK_producto_precio_lista |
| 6 | Insertar un "producto" con stock = -5 | Falla el INSERT | CK_producto_stock |
| 7 | Insertar una "alicuota_iva" con porcentaje = -5 | Falla el INSERT | CK_alicuota_iva_porcentaje (fuera del rango 0-100) |
| 8 | Insertar un "proveedor" con cuit = '301234567' (sin guiones ni dígito verificador) | Falla el INSERT | CK_proveedor_cuit |
| 9 | Insertar un "pedido" con estado = 'en_proceso' (valor no contemplado) | Falla el INSERT | CK_pedido_estado |
| 10 | Insertar un "pedido" con estado_pago = 'aprobado' y ref_transaccion = NULL | Falla el INSERT | CK_pedido_ref_transaccion |
| 11 | Insertar un "pedido" con fecha_pedido posterior a la fecha actual | Falla el INSERT | CK_pedido_fecha |
| 12 | Insertar una "compra" con fecha posterior a la fecha actual | Falla el INSERT | CK_compra_fecha |
| 13 | Insertar un "detalle_pedido" con cantidad = 0 | Falla el INSERT | CK_detalle_pedido_cantidad |
| 14 | Insertar una "factura" con tipo_comprobante = 'X' | Falla el INSERT | CK_factura_tipo_comprobante |
| 15 | Insertar una "factura" con total = -500 | Falla el INSERT | CK_factura_montos |
| 42 | Insertar un "proveedor" con email = 'proveedorsinarroba.com' (sin @) | Falla el INSERT | CK_proveedor_email |
| 46 | Insertar una "promocion" con porcentaje_descuento = 0 y nro_cuotas = 1 | Falla el INSERT | CK_promocion_beneficio |

## 2. Restricciones UNIQUE

| # | Caso de prueba | Resultado esperado | Restricción que actúa |
|---|---|---|---|
| 16 | Insertar dos "cliente" con el mismo email | Falla el segundo INSERT | UQ_cliente_email |
| 17 | Insertar dos "usuario" con el mismo nombre_usuario | Falla el segundo INSERT | UQ_usuario_nombre_usuario |
| 18 | Insertar dos "proveedor" con el mismo cuit | Falla el segundo INSERT | UQ_proveedor_cuit |
| 41 | Insertar dos "proveedor" con el mismo email | Falla el segundo INSERT | UQ_proveedor_email |
| 19 | Insertar dos "factura" con el mismo punto_venta y numero | Falla el segundo INSERT | UQ_factura_pto_nro |
| 20 | Insertar dos "categoria" con el mismo nombre bajo el mismo cod_categoria_padre | Falla el segundo INSERT | UQ_categoria_nombre_padre |
| 34 | Insertar dos "factura" para el mismo cod_pedido | Falla el segundo INSERT | UQ_factura_pedido (un único comprobante por pedido, RN.17) |
| 2 | Insertar dos "localidad" con el mismo nombre y la misma provincia | Falla el segundo INSERT | UQ_localidad_nombre_provincia |
| 35 | Insertar dos "localidad" con el mismo nombre en provincias distintas | Se insertan las dos | UQ_localidad_nombre_provincia (la unicidad es por nombre y provincia) |

## 3. Restricciones NOT NULL / valores por defecto

| # | Caso de prueba | Resultado esperado | Restricción que actúa |
|---|---|---|---|
| 21 | Insertar un "cliente" sin especificar activo | Se inserta con activo = 1 | DF_cliente_activo |
| 22 | Insertar un "pedido" sin especificar estado ni estado_pago | Se inserta con ambos en 'pendiente' | DF_pedido_estado, DF_pedido_estado_pago |
| 23 | Insertar un "cliente" sin "telefono" | Falla el INSERT | Columna "telefono NOT NULL" |
| 47 | Insertar un "producto" sin "descripcion" | Falla el INSERT | Columna "descripcion NOT NULL" |
| 48 | Insertar una "compra" sin "nro_comprobante_prov" | Se inserta con el valor 'S/N' | DF_compra_nro_comprobante_prov |
| 52 | Insertar una fila en "auditoria" sin "usuario_bd" | Se inserta con el usuario de la sesión | DF_auditoria_usuario_bd |
| 24 | Insertar un "pedido" sin "cod_usuario" | Se inserta correctamente ("cod_usuario" es NULL hasta la gestión de despacho) | Columna cod_usuario NULL |

## 4. Reglas de integridad referencial (FOREIGN KEY)

| # | Caso de prueba | Resultado esperado | Restricción que actúa |
|---|---|---|---|
| 25 | Insertar un "producto" con cod_categoria inexistente | Falla el INSERT | FK_producto_categoria |
| 26 | Insertar un "pedido" con cod_cliente inexistente | Falla el INSERT | FK_pedido_cliente |
| 27 | Insertar un "detalle_pedido" con cod_producto inexistente | Falla el INSERT | FK_detalle_pedido_producto |
| 3 | Insertar una "direccion" con cod_cliente inexistente | Falla el INSERT | FK_direccion_cliente |
| 38 | Insertar una "direccion" con cod_localidad inexistente | Falla el INSERT | FK_direccion_localidad |
| 39 | Insertar una "direccion" sin cod_postal | Falla el INSERT | Columna "cod_postal NOT NULL" |
| 43 | Insertar una "direccion" sin cliente ni proveedor, o con los dos | Falla el INSERT | CK_direccion_titular |
| 44 | Insertar una segunda "direccion" principal para el mismo cliente | Falla el INSERT | UQ_direccion_principal_cliente |
| 45 | Insertar una segunda "direccion" no principal para el mismo cliente | Se inserta correctamente | Un cliente puede tener varias direcciones |
| 49 | Insertar la primera "direccion" de un cliente sin indicar principal | Queda como principal | trg_direccion_principal |
| 50 | Eliminar la "direccion" principal de un cliente con otra dirección | La más reciente pasa a ser la principal | trg_direccion_principal |
| 51 | Eliminar la única "direccion" de un cliente | Se elimina, y el cliente queda sin direcciones | Un cliente puede no tener direcciones |
| 36 | Insertar una "localidad" con cod_provincia inexistente | Falla el INSERT | FK_localidad_provincia |

## 5. Reglas de borrado (ON DELETE)

| # | Caso de prueba | Resultado esperado | Restricción que actúa |
|---|---|---|---|
| 28 | Intentar eliminar un "cliente" que tiene al menos un pedido asociado | Falla el DELETE | FK_pedido_cliente con ON DELETE NO ACTION |
| 29 | Intentar eliminar un "producto" que tiene registros en detalle_pedido | Falla el DELETE | FK_detalle_pedido_producto con ON DELETE NO ACTION |
| 30 | Intentar eliminar una "categoria" que tiene subcategorías asociadas (cod_categoria_padre) | Falla el DELETE | FK_categoria_categoria_padre con ON DELETE NO ACTION |
| 31 | Eliminar un "pedido" de prueba sin factura asociada | Se elimina el pedido y, en cascada, sus líneas de detalle_pedido | FK_detalle_pedido_pedido con ON DELETE CASCADE |
| 32 | Eliminar una "compra" de prueba | Se elimina la compra y, en cascada, sus líneas de detalle_compra | FK_detalle_compra_compra con ON DELETE CASCADE |
| 33 | Intentar eliminar un "pedido" que tiene factura asociada | Falla el DELETE | FK_factura_pedido con ON DELETE NO ACTION (inmutabilidad fiscal) |
| 37 | Intentar eliminar una "localidad" usada en una dirección | Falla el DELETE | FK_direccion_localidad con ON DELETE NO ACTION |
| 40 | Eliminar un "cliente" de prueba sin pedidos | Se elimina el cliente y, en cascada, sus direcciones | FK_direccion_cliente con ON DELETE CASCADE |

## Resultados

Los 52 casos se ejecutaron el 03/11/2026 sobre una base recién creada con `crear_bd.sql` y `cargar_datos.sql`. Todos dieron el resultado esperado, y en los casos que deben fallar actuó la restricción indicada.

## Observación general

La mayoría de los casos de la sección 5 no representan operaciones habituales del sistema en producción: tanto "pedido" como "compra" cuentan con un estado 'cancelado'/'cancelada' pensado justamente para registrar una anulación sin necesidad de borrar el registro. Las reglas ON DELETE documentadas cubren el comportamiento del motor ante un escenario excepcional (por ejemplo, limpieza de datos de prueba), garantizando que, aun en ese caso, la integridad referencial del esquema se mantenga.

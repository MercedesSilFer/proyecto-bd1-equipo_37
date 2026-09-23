# Decisiones de diseño – Etapa II

En este documento se registran las decisiones técnicas tomadas al armar el DER, al pasarlo al modelo relacional y durante la normalización, junto con el motivo por el que se descartaron algunas alternativas.

## 1. Cardinalidad opcional entre producto/proveedor y compra

Se dejó la cardinalidad (0, N) en las relaciones producto–compra y proveedor–compra, en vez de obligar a que exista al menos una compra. El administrador da de alta productos y proveedores en el catálogo antes de que el depósito registre cualquier compra, así que es normal que un producto o un proveedor esté cargado sin haberse comprado todavía.

## 2. Atributos agregados a compra

A compra se le agregaron los atributos monto_total (derivado), estado, cod_usuario (FK) y nro_comprobante_prov, para que tenga la misma estructura funcional que pedido.

## 3. Registro del usuario en factura y pedido

Se agregó cod_usuario como FK en factura, para saber quién emitió el comprobante, y en pedido, para saber quién gestionó el despacho desde el depósito. Esto se apoya en las reglas de negocio RN.21 y RN.22.

## 4. Datos fiscales del cliente en la factura

En lugar de un campo fijo para el CUIT, se usan tipo_documento_cliente y nro_documento_cliente, los dos opcionales. Así se cubren los tres casos que se dan en la práctica: responsable inscripto o monotributista con CUIT, consumidor final con DNI y consumidor final sin documento. razon_social también es opcional y solo se completa cuando es distinta del nombre del cliente.

## 5. Nombre y demás datos del cliente en la factura

Los datos fiscales (CUIT y razón social) se guardan en la factura, pero el nombre y el resto de los datos del cliente no. Esos se consultan al momento de generar el comprobante, siguiendo la relación factura → pedido → cliente.

## 6. Localidad y provincia como texto

Se consideró pasar localidad y provincia a tablas de catálogo, tanto para evitar errores de carga (mayúsculas, tildes) como para eliminar la dependencia transitiva que afecta la 3FN. Finalmente se descartó para no sumar complejidad al modelo. Queda asentado acá porque fue una decisión tomada a propósito y no un descuido en la normalización.

## 7. Domicilio como columnas directas, sin historial versionado

Se evaluó modelar el domicilio del cliente en una entidad "domicilio" versionada, para evitar que un cambio de dirección afecte a pedidos ya despachados y evitar datos duplicados (en tabla domicilio y tabla pedido) referenciando a dicha tabla. Se descartó la opción por el bajo volumen de pedidos esperados para un mismo cliente: la ganancia de evitar duplicación no justifica la complejidad adicional de crear nueva entidad domicilio. En su lugar, "pedido" guarda las columnas de dirección directamente, copiadas al momento de confirmarse (se aplica el mismo criterio que "precio_unitario_venta" en detalle_venta). El nivel de atomicidad de los datos de domicilio guardados en pedido permite optimizar las consultas realizadas sobre estos datos y mediante aplicación se obliga al cliente a rellenar campos específicos para cada dato evitando olvidos.

## 8. Precio de venta con IVA incluido; precio de lista en neto

"producto.precio_lista" se registra en valor neto (sin IVA), de acuerdo a cómo se administran los precios internamente. El precio final que ve el cliente y que se congela en "detalle_pedido.precio_unitario_venta" incluye el IVA, esto coincide con la práctica habitual de un comercio minorista, donde el precio exhibido es el que efectivamente se paga.

## 9. Alícuota de IVA en Producto y en DetallePedido

"producto.alicuota_iva" refleja la alícuota vigente aplicable al producto (ya que ésta puede variar según su clasificación fiscal, entre categorías de productos). "detallePedido.alicuota_iva" es una copia histórica de esa alícuota al momento de la venta, se justifica no porque varíe entre productos, sino porque las alícuotas pueden modificarse en el tiempo (por ejemplo por decreto); un pedido ya facturado no debe verse afectado por cambios normativos posteriores.



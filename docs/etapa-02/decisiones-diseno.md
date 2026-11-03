# Decisiones de diseño – Etapa II

En este documento se registran las decisiones técnicas tomadas al armar el DER, al pasarlo al modelo relacional y durante la normalización, junto con el motivo por el que se descartaron algunas alternativas.

## 1. Cardinalidad opcional entre producto/proveedor y compra

Se dejó la cardinalidad (0, N) en las relaciones producto–compra y proveedor–compra, en vez de obligar a que exista al menos una compra. El administrador da de alta productos y proveedores en el catálogo antes de que el depósito registre cualquier compra, así que es normal que un producto o un proveedor esté cargado sin haberse comprado todavía.

## 2. Atributos agregados a compra

A compra se le agregaron los atributos monto_total (derivado: no se guarda, se calcula desde el detalle), estado, cod_usuario (FK) y nro_comprobante_prov, para que tenga la misma estructura funcional que pedido.

## 3. Registro del usuario en factura y pedido

Se agregó cod_usuario como FK en factura, para saber quién emitió el comprobante, y en pedido, para saber quién gestionó el despacho desde el depósito. Esto se apoya en las reglas de negocio RN.21 y RN.22.

## 4. Datos fiscales del cliente en la factura

En lugar de un campo fijo para el CUIT, se usan tipo_documento_cliente y nro_documento_cliente, los dos opcionales. Así se cubren los tres casos que se dan en la práctica: responsable inscripto o monotributista con CUIT, consumidor final con DNI y consumidor final sin documento. razon_social también es opcional y solo se completa cuando es distinta del nombre del cliente.

## 5. Nombre y demás datos del cliente en la factura

Los datos fiscales (CUIT y razón social) se guardan en la factura, pero el nombre y el resto de los datos del cliente no. Esos se consultan al momento de generar el comprobante, siguiendo la relación factura → pedido → cliente.

## 6. Localidad y provincia como catálogos

En `cliente` y `proveedor`, guardar ciudad y provincia como texto generaba una dependencia transitiva: el cliente determina su localidad y la localidad determina su provincia. Para cumplir la 3FN se crearon las tablas `provincia` y `localidad`, y la dirección de `cliente` y `proveedor` referencia a `localidad` (ver decisión 7). Esto también evita errores de carga (mayúsculas, tildes) y reemplaza la lista de provincias que estaba repetida en dos restricciones CHECK.

La unicidad de `localidad` es por nombre y provincia, porque hay nombres repetidos: en los datos de prueba, "Buenos Aires" figura tanto en la Ciudad Autónoma de Buenos Aires como en la provincia de Buenos Aires.

`cod_postal` queda en `direccion` y no en `localidad`, porque una localidad puede tener varios códigos postales y un mismo código puede abarcar varias localidades, así que ninguno de los dos determina al otro.

`pedido` conserva ciudad y provincia como texto, sin referenciar al catálogo: es una copia histórica de la dirección usada en esa venta (ver decisión 7 y RN.04), y no debe cambiar si después se modifica el catálogo.

## 7. Varias direcciones por cliente o proveedor, sin historial versionado

`calle`, `numero`, `cod_postal` y la localidad se agrupan en la entidad `direccion`. Un cliente o un proveedor puede tener varias direcciones (RN.04), así que la clave foránea va en `direccion`, que tiene `cod_cliente` y `cod_proveedor`. Las dos columnas admiten nulos porque cada dirección pertenece a uno solo de los dos, y `CK_direccion_titular` exige que se complete exactamente una. Si se elimina el titular, sus direcciones se eliminan en cascada.

La columna `principal` indica la dirección que el sistema propone al armar un pedido, y dos índices únicos filtrados impiden que un titular tenga más de una. El DER exige al menos una dirección por cliente; una clave foránea no puede garantizarlo, porque el cliente se crea antes que su dirección, así que ese control queda en la aplicación. El procedimiento de venta rechaza a un cliente sin dirección (error 50007). Las consultas toman solo la dirección principal, para no repetir un cliente que tenga varias.

Se evaluó además versionar la dirección, para evitar que un cambio de dirección afecte a pedidos ya despachados y evitar datos duplicados (en tabla direccion y tabla pedido) referenciando a dicha tabla. Se descartó la opción por el bajo volumen de pedidos esperados para un mismo cliente: la ganancia de evitar duplicación no justifica la complejidad adicional de mantener versiones de cada dirección. En su lugar, "pedido" guarda las columnas de dirección directamente, copiadas al momento de confirmarse (se aplica el mismo criterio que "precio_unitario_venta" en detalle_pedido). El nivel de atomicidad de los datos de domicilio guardados en pedido permite optimizar las consultas realizadas sobre estos datos y mediante aplicación se obliga al cliente a rellenar campos específicos para cada dato evitando olvidos.

## 8. Precio de venta con IVA incluido; precio de lista en neto

"producto.precio_lista" se registra en valor neto (sin IVA), de acuerdo a cómo se administran los precios internamente. El precio final que ve el cliente y que se congela en "detalle_pedido.precio_unitario_venta" incluye el IVA, esto coincide con la práctica habitual de un comercio minorista, donde el precio exhibido es el que efectivamente se paga.

## 9. Alícuota de IVA en Producto y en DetallePedido

"producto.cod_alicuota" referencia la alícuota vigente aplicable al producto en el catálogo alicuota_iva (ver decisión 13)(ya que ésta puede variar según su clasificación fiscal, entre categorías de productos). "detalle_pedido.alicuota_iva" es una copia histórica de esa alícuota al momento de la venta, se justifica no porque varíe entre productos, sino porque las alícuotas pueden modificarse en el tiempo (por ejemplo por decreto); un pedido ya facturado no debe verse afectado por cambios normativos posteriores.


## 10. Valor de la especificación en la relación y no en la entidad

`especificacion` funciona como catálogo con el nombre de cada característica (por ejemplo "Tamaño de pantalla"). El dato concreto de cada producto ("50 pulgadas") se guarda en `especificacion_producto.valor`, porque depende de la combinación producto + especificación. Así se evita repetir el nombre de la especificación en cada producto y se garantiza que se escriba siempre igual (nombre único).

## 11. URLs en lugar de archivos

`multimedia` y `slide` guardan la dirección del archivo alojado en un servidor de contenidos, no el archivo en sí. Esto mantiene la base liviana y permite cambiar el archivo sin modificar la estructura. Se exige que la URL comience con `https://`.

## 12. Precio con promoción

El descuento no modifica `producto.precio_lista`. Al confirmar la venta, el precio final con IVA y con el descuento de la promoción vigente queda congelado en `detalle_pedido.precio_unitario_venta` (mismo criterio que RN.03). Si hay varias promociones vigentes para un producto se aplica la de mayor descuento (RN.24). Esta regla involucra varias filas y no puede resolverse con un CHECK, por lo que se implementa en la Etapa V, con la función `fn_descuento_vigente`.

## 13. Catálogo de alícuotas de IVA

Las alícuotas se registran en la tabla `alicuota_iva` y cada producto la referencia mediante `cod_alicuota`. Si una norma modifica una alícuota, se actualiza una sola fila y todos los productos quedan al día. Como código se usa el que asigna ARCA a cada alícuota en la factura electrónica (3 = 0 %, 9 = 2,5 %, 8 = 5 %, 4 = 10,5 %, 5 = 21 %, 6 = 27 %), lo que facilita la integración con la facturación. `detalle_pedido.alicuota_iva` no referencia al catálogo: guarda una copia del porcentaje vigente al momento de la venta, para que los cambios posteriores no alteren ventas ni facturas ya emitidas (complementa la decisión 9).

## 14. Nombre y email del proveedor

`proveedor` guarda `razon_social`, que es el nombre legal, y además `nombre`, que es el nombre comercial con el que se lo identifica en la operatoria diaria. También guarda `email` como dato de contacto, único por proveedor y con el mismo control de formato que el email del cliente. Los dos son obligatorios.

## 15. Atributos obligatorios con valor por defecto

En `producto` y `promocion`, `descripcion` es obligatoria, porque se muestra en la tienda. En `promocion`, un beneficio que no se ofrece se guarda como valor neutro en lugar de nulo: `porcentaje_descuento` = 0 y `nro_cuotas` = 1, y `CK_promocion_beneficio` exige al menos un descuento mayor a 0 o más de una cuota (RN.23). En `compra`, `nro_comprobante_prov` vale `'S/N'` hasta que el proveedor entrega el comprobante.

`auditoria.valor_anterior` y `auditoria.valor_nuevo` siguen admitiendo nulos: un `INSERT` no tiene valor anterior y un `DELETE` no tiene valor nuevo, y no hay un valor neutro que represente esa ausencia sin confundirse con un dato auditado.

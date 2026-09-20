# Reglas de Negocio

**RN.01:** Cada cliente debe registrarse para poder comprar en la tienda online, con nombre, contraseña, dirección, ciudad, provincia, código postal y email. A cada cliente se le asigna un identificador único y el email debe ser único por cada cliente.

**RN.02:** Cada cliente puede realizar ninguno, uno o muchos pedidos, pero cada pedido pertenece a un único cliente.

**RN.03:** El precio unitario del producto se registra en el detalle del pedido al momento de confirmarse la venta y no puede modificarse con posterioridad, independientemente de cambios posteriores en el precio de lista del producto.

**RN.04:** Cada cliente tiene una sola dirección registrada; al momento de generar un pedido, el sistema debe proponer esa dirección y el cliente puede confirmarla o modificarla para ese pedido puntual. La dirección efectivamente usada queda registrada en el propio pedido (no se actualiza retroactivamente si el cliente cambia su dirección general después).

**RN.05:** Un pedido se registra con un código identificador único y se abona con un único método de pago válido previamente registrado (no se admiten pagos parciales ni combinados); el pago queda en estado "pendiente", "aprobado" o "rechazado" según la confirmación de la pasarela de pago.

**RN.06:** Cada producto tiene un código identificador y pertenece a una única categoría previamente definida.

**RN.07:** Un producto puede ser adquirido a varios proveedores (estando ambos, producto y proveedor, previamente registrados) a través de distintas compras; el vínculo proveedor-producto surge de las compras realizadas, no de un catálogo previo de habilitación.

**RN.08:** Historial de costos de compra: el costo unitario del producto al momento de la compra queda registrado en el detalle de la compra.

**RN.09:** El stock de un producto se almacena como un valor asociado a cada producto y se actualiza automáticamente al confirmarse cada compra (entradas o incrementos) o pedido (salidas por ventas o decrementos).

**RN.10:** El monto total de un pedido no se almacena como un valor fijo, se calcula a partir del precio unitario de cada producto al momento de la venta y la correspondiente cantidad vendida.

**RN.11:** Un pedido no puede confirmarse si el stock calculado del producto es insuficiente.

**RN.12:** Cada operación interna del sistema se realiza a través de un usuario con credenciales únicas y rol asignado previamente: depósito, administrador o soporte. No existe el rol vendedor (en e-commerce el pedido lo genera el cliente directamente, sin intervención de un vendedor).

**RN.13:** El rol depósito gestiona las compras a proveedores y confirma el despacho de pedidos (lo que dispara la salida de stock); el rol administrador gestiona el catálogo (productos, categorías, proveedores, precios), la administración de usuarios (creación de cuentas), y tiene acceso de solo lectura a la auditoría; el rol soporte puede consultar el estado de pedidos y envíos, sin permisos sobre catálogo ni compras.

**RN.14:** Los cambios sobre datos sensibles (precios, stock, pedidos, compras, facturación) quedan registrados en la auditoría, identificando el usuario responsable, la operación realizada y la fecha.

**RN.15:** El pedido registra los datos de envío, y este solo se realiza una vez que el pago del pedido está aprobado.

**RN.16:** Los pedidos, compras y altas de clientes se registran con fecha actual.

**RN.17:** Todo pedido confirmado y pagado genera un único comprobante de facturación total; no se admite facturación parcial de un pedido.

**RN.18:** Los datos de condición de IVA y CUIT no se almacenan como atributos permanentes del cliente; se solicitan al momento de generar el pedido (o de emitir la factura) y quedan registrados únicamente en el comprobante fiscal emitido.

**RN.19:** El precio de lista de un producto se gestiona en valor neto (sin IVA). El precio final con IVA incluido, que se muestra al cliente y se congela en el detalle del pedido al momento de confirmarse la venta, se calcula aplicando la alícuota de IVA vigente del producto sobre ese precio neto.

**RN.20:** Toda compra a proveedor se registra en estado "pendiente" y debe confirmarse explícitamente para que se refleje el incremento de stock correspondiente en el catálogo de productos.

**RN.21:** Toda factura queda asociada al usuario que la emitió, para su trazabilidad en la auditoría.

**RN.22:** Al confirmar el despacho de un pedido, el sistema registra qué usuario del rol depósito realizó esa gestión.

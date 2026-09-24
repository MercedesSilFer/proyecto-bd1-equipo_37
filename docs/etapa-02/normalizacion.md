# Proceso de Normalización

## 1. Fundamentos

Una **dependencia funcional** (DF) X->Y indica que el valor de los atributos en X determina de forma única el valor de los atributos en Y; X es el *determinante* e Y el *dependiente*. Sobre esta base se distinguen:

 **Dependencia completa**: Y depende de todo el conjunto de atributos X, no de una parte.

 **Dependencia parcial**: un atributo no clave depende funcionalmente de solo una parte de una clave compuesta, en lugar de la clave completa.

 **Dependencia transitiva**: un atributo no clave depende de otro atributo no clave, que a su vez depende de la clave primaria.

Un esquema sin normalizar produce **anomalías**: de inserción (no se puede registrar un producto nuevo sin que exista al menos un pedido que lo incluya), de actualización (si el email de un cliente cambia, habría que corregirlo en cada línea de pedido donde aparece) y de borrado (eliminar el único pedido de un cliente borraría también sus datos de contacto). La normalización elimina estas anomalías descomponiendo la tabla inicial según sus dependencias funcionales.

## 2. Tabla inicial obtenida de planilla original del negocio (sin normalizar)

| Cód. Pedido | Fecha | Cód. Cliente | Nombre y Apellido | Email | Dirección | Método Pago | Estado Pago | Ref. Transacción | Cód. Producto | Nombre Producto | Categoría | Precio Unitario Venta | Cantidad |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 5001 | 5/9/2024 | 101 | Marcelo López | marcelo51@gmail.com | Calle Madariaga 2145, Corrientes Capital, CP 3400 | Tarjeta Crédito | Aprobado | TX-88231 | 3786 | Smart TV 50" | Electrónica | 350000 | 1 |
| 5001 | 5/9/2024 | 101 | Marcelo López | marcelo51@gmail.com | Calle Madariaga 2145, Corrientes Capital, CP 3400 | Tarjeta Crédito | Aprobado | TX-88231 | 4011 | Auriculares BT | Electrónica | 25000 | 2 |
| 5002 | 6/9/2024 | 107 | Silvia Gauna | sgauna@gmail.com | Av. Edison 306, Resistencia, Chaco, CP H3500 | Transferencia | Aprobado | TX-88232 | 5794 | Heladera 300L | Electrodomésticos | 480000 | 1 |
| 5003 | 7/9/2024 | 110 | María Gómez | mgomez@gmail.com | Chubut 3580, Posadas, Misiones, CP N3301 | Tarjeta Débito | Pendiente | TX-88233 | 4011 | Auriculares BT | Electrónica | 25000 | 2 |
| 5003 | 7/9/2024 | 110 | María Gómez | mgomez@gmail.com | Chubut 3580, Posadas, Misiones, CP N3301 | Tarjeta Débito | Pendiente | TX-88233 | 3141 | Funda Notebook | Accesorios | 8000 | 2 |

Se observa redundancia: los datos del cliente se repiten en cada línea de producto del mismo pedido, y el nombre/categoría del producto se repetiría en cualquier otro pedido que lo incluya.

### Dependencias funcionales identificadas

 cod_pedido -> fecha, cod_cliente, metodo_pago, estado_pago, ref_transaccion

 cod_cliente -> nombre_apellido, email, dirección

 cod_producto -> nombre_producto, categoria

 (cod_pedido, cod_producto) -> precio_unitario, cantidad (dependencia completa: solo la combinación de ambos determina estos valores)

## 3. Primera Forma Normal (1FN)

Una relación está en 1FN si y solo si cada celda de la tabla contiene un solo valor, todos sus atributos son atómicos (indivisibles), no existen grupos repetitivos de atributos y cada tabla tiene un identificador único (PK).

Se procede eliminando el grupo repetitivo (varios productos por pedido en la misma fila) separando el detalle en una tabla propia, y se descompone el atributo compuesto dirección en sus componentes atómicos (calle, numero, ciudad, provincia, cod_postal).

**pedido**

| cod_pedido | fecha | cod_cliente | nombre_apellido | email | calle | numero | ciudad | provincia | cod_postal | metodo_pago | estado_pago | ref_transaccion |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 5001 | 5/9/2024 | 101 | Marcelo López | marcelo51@gmail.com | Madariaga | 2145 | Capital | Corrientes | 3400 | Tarjeta Crédito | Aprobado | TX-88231 |
| 5002 | 6/9/2024 | 107 | Silvia Gauna | sgauna@gmail.com | Av. Edison | 306 | Resistencia | Chaco | H3500 | Transferencia | Aprobado | TX-88232 |
| 5003 | 7/9/2024 | 110 | María Gómez | mgomez@gmail.com | Chubut | 3580 | Posadas | Misiones | N3301 | Tarjeta Débito | Pendiente | TX-88233 |

**detalle_pedido**

| cod_pedido | cod_producto | nombre_producto | categoria | precio_unitario | cantidad |
|---|---|---|---|---|---|
| 5001 | 3786 | Smart TV 50" | Electrónica | 350000 | 1 |
| 5001 | 4011 | Auriculares BT | Electrónica | 25000 | 2 |
| 5002 | 5794 | Heladera 300L | Electrodomésticos | 480000 | 1 |
| 5003 | 4011 | Auriculares BT | Electrónica | 25000 | 2 |
| 5003 | 3141 | Funda Notebook | Accesorios | 8000 | 2 |

Ambas tablas cumplen 1FN: valores atómicos, clave identificada ("cod_pedido" en pedido; "cod_pedido + cod_producto" en detalle_pedido), sin grupos repetitivos.

## 4. Segunda Forma Normal (2FN)

Una relación está en 2FN si está en 1FN y todos sus atributos no clave tienen una dependencia funcional completa de la clave primaria; es decir, no debe existir ninguna dependencia funcional parcial en la que un subconjunto de la clave primaria determine un atributo no clave.

"pedido" no cambia (su clave es simple, no aplica dependencia parcial). En "detalle_pedido", la clave es compuesta: se detecta que "nombre_producto" y "categoria" dependen únicamente de "cod_producto", una parte de la clave, no de la combinación completa. Es una **dependencia parcial**, por lo que se extraen a una tabla producto.

**detalle_pedido (2FN)**

| cod_pedido | cod_producto | precio_unitario_venta | cantidad |
|---|---|---|---|
| 5001 | 3786 | 350000 | 1 |
| 5001 | 4011 | 25000 | 2 |
| 5002 | 5794 | 480000 | 1 |
| 5003 | 4011 | 25000 | 2 |
| 5003 | 3141 | 8000 | 2 |

**producto**

| cod_producto | nombre_producto | categoria |
|---|---|---|
| 3786 | Smart TV 50" | Electrónica |
| 4011 | Auriculares BT | Electrónica |
| 5794 | Heladera 300L | Electrodomésticos |
| 3141 | Funda Notebook | Accesorios |

"precio_unitario" y "cantidad" sí dependen de la clave completa (esa combinación puntual de pedido y producto), por lo que permanecen en "detalle_pedido".

## 5. Tercera Forma Normal (3FN)

Una relación está en 3FN si está en 2FN y no contiene dependencias funcionales transitivas; es decir, ningún atributo no clave depende de otro atributo no clave que, a su vez, dependa de la clave primaria.

En "pedido", los atributos "nombre_apellido", "email", "calle", "numero", "ciudad", "provincia" y "cod_postal" dependen de "cod_cliente", que a su vez depende de "cod_pedido": "cod_pedido -> cod_cliente → nombre_apellido". Es una **dependencia transitiva**, por lo que se extraen a una tabla "cliente".

**pedido (3FN)**

| cod_pedido | fecha | cod_cliente | metodo_pago | estado_pago | ref_transaccion |
|---|---|---|---|---|---|
| 5001 | 5/9/2024 | 101 | Tarjeta Crédito | Aprobado | TX-88231 |
| 5002 | 6/9/2024 | 107 | Transferencia | Aprobado | TX-88232 |
| 5003 | 7/9/2024 | 110 | Tarjeta Débito | Pendiente | TX-88233 |

**cliente**

| cod_cliente | nombre_apellido | email | calle | numero | ciudad | provincia | cod_postal |
|---|---|---|---|---|---|---|---|
| 101 | Marcelo López | marcelo51@gmail.com | Madariaga | 2145 | Capital | Corrientes | 3400 |
| 107 | Silvia Gauna | sgauna@gmail.com | Av. Edison | 306 | Resistencia | Chaco | H3500 |
| 110 | María Gómez | mgomez@gmail.com | Chubut | 3580 | Posadas | Misiones | N3301 |

"detalle_pedido" y "producto" no sufren cambios en este paso: ya no tienen dependencias transitivas (cada atributo depende directamente de su clave).

Con esto, "pedido", "detalle_pedido", "producto" y "cliente" alcanzan 3FN.

Los atributos que a simple vista podrían parecer una dependencia transitiva sin resolver ("precio_unitario_venta" en "detalle_pedido", "alicuota_iva" que se agregará en el modelo final también en "detalle_pedido", los datos de dirección de envío en el pedido, los datos fiscales del cliente en factura), son atributos históricos: son valores capturados en un momento del proceso y guardados por decisión de modelado, no como referencias a la entidad de origen (ver decisiones-diseno.md).

## 6. Normalización del proceso de compras a proveedores

Se aplica el mismo procedimiento sobre la planilla que el negocio usaba para registrar las compras a proveedores (ver descripcion-caso.md).

### 6.1 Tabla inicial obtenida de planilla de compras (sin normalizar)

| Cód. Compra | Fecha | Estado | Nro. Comprobante Prov. | Cód. Proveedor | Razón Social | CUIT | Dirección Proveedor | Cód. Usuario | Usuario | Rol | Cód. Producto | Nombre Producto | Costo Unitario | Cantidad |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 201 | 2/9/2024 | Confirmada | 0003-00012458 | 12 | Distribuidora Norte S.A. | 30-71234567-8 | Av. Independencia 1850, Corrientes Capital | 3 | lramirez | Depósito | 3786 | Smart TV 50" | 260000 | 5 |
| 201 | 2/9/2024 | Confirmada | 0003-00012458 | 12 | Distribuidora Norte S.A. | 30-71234567-8 | Av. Independencia 1850, Corrientes Capital | 3 | lramirez | Depósito | 4011 | Auriculares BT | 15000 | 10 |
| 202 | 3/9/2024 | Confirmada | 0001-00004521 | 15 | ElectroHogar Litoral S.R.L. | 30-70987654-3 | Av. Sarmiento 1200, Resistencia, Chaco | 3 | lramirez | Depósito | 5794 | Heladera 300L | 360000 | 3 |
| 203 | 8/9/2024 | Pendiente | — | 15 | ElectroHogar Litoral S.R.L. | 30-70987654-3 | Av. Sarmiento 1200, Resistencia, Chaco | 4 | mfernandez | Depósito | 4011 | Auriculares BT | 15500 | 20 |
| 203 | 8/9/2024 | Pendiente | — | 15 | ElectroHogar Litoral S.R.L. | 30-70987654-3 | Av. Sarmiento 1200, Resistencia, Chaco | 4 | mfernandez | Depósito | 3141 | Funda Notebook | 4500 | 15 |

Se observa la misma redundancia que en las ventas: los datos del proveedor y del usuario que registró la compra se repiten en cada línea de producto, y el nombre del producto se repite en cada compra que lo incluye. Esto produce las mismas anomalías: no se puede dar de alta un proveedor que todavía no tenga compras (inserción), si un proveedor cambia de domicilio hay que corregirlo en cada línea donde aparece (actualización), y al eliminar la única compra hecha a un proveedor se pierden sus datos (borrado).

### 6.2 Dependencias funcionales identificadas

 cod_compra -> fecha, estado, nro_comprobante_prov, cod_proveedor, cod_usuario

 cod_proveedor -> razon_social, cuit, calle, numero, ciudad, provincia

 cuit -> cod_proveedor (el CUIT también identifica al proveedor: es una clave candidata)

 cod_usuario -> nombre_usuario, rol

 cod_producto -> nombre_producto

 (cod_compra, cod_producto) -> costo_unitario, cantidad (dependencia completa: solo la combinación de ambos determina estos valores)

"costo_unitario" no depende solo de "cod_producto": el producto 4011 se compró a $15000 en la compra 201 y a $15500 en la compra 203. El costo lo determina la compra puntual (RN.08).

### 6.3 Primera Forma Normal (1FN)

Se elimina el grupo repetitivo (varios productos por compra en la misma fila) separando el detalle en una tabla propia, y se descompone la dirección del proveedor en sus componentes atómicos (calle, numero, ciudad, provincia).

**compra**

| cod_compra | fecha | estado | nro_comprobante_prov | cod_proveedor | razon_social | cuit | calle | numero | ciudad | provincia | cod_usuario | nombre_usuario | rol |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 201 | 2/9/2024 | Confirmada | 0003-00012458 | 12 | Distribuidora Norte S.A. | 30-71234567-8 | Av. Independencia | 1850 | Capital | Corrientes | 3 | lramirez | Depósito |
| 202 | 3/9/2024 | Confirmada | 0001-00004521 | 15 | ElectroHogar Litoral S.R.L. | 30-70987654-3 | Av. Sarmiento | 1200 | Resistencia | Chaco | 3 | lramirez | Depósito |
| 203 | 8/9/2024 | Pendiente | NULL | 15 | ElectroHogar Litoral S.R.L. | 30-70987654-3 | Av. Sarmiento | 1200 | Resistencia | Chaco | 4 | mfernandez | Depósito |

**detalle_compra**

| cod_compra | cod_producto | nombre_producto | costo_unitario | cantidad |
|---|---|---|---|---|
| 201 | 3786 | Smart TV 50" | 260000 | 5 |
| 201 | 4011 | Auriculares BT | 15000 | 10 |
| 202 | 5794 | Heladera 300L | 360000 | 3 |
| 203 | 4011 | Auriculares BT | 15500 | 20 |
| 203 | 3141 | Funda Notebook | 4500 | 15 |

Ambas tablas cumplen 1FN: valores atómicos, clave identificada ("cod_compra" en compra; "cod_compra + cod_producto" en detalle_compra), sin grupos repetitivos.

### 6.4 Segunda Forma Normal (2FN)

"compra" no cambia (su clave es simple, no aplica dependencia parcial). En "detalle_compra", la clave es compuesta y "nombre_producto" depende únicamente de "cod_producto", una parte de la clave. Es una **dependencia parcial**, por lo que se extrae a la tabla producto.

**detalle_compra (2FN)**

| cod_compra | cod_producto | costo_unitario | cantidad |
|---|---|---|---|
| 201 | 3786 | 260000 | 5 |
| 201 | 4011 | 15000 | 10 |
| 202 | 5794 | 360000 | 3 |
| 203 | 4011 | 15500 | 20 |
| 203 | 3141 | 4500 | 15 |

**producto**

| cod_producto | nombre_producto |
|---|---|
| 3786 | Smart TV 50" |
| 4011 | Auriculares BT |
| 5794 | Heladera 300L |
| 3141 | Funda Notebook |

Corresponde a la misma tabla "producto" obtenida en la normalización de las ventas (sección 4), que además incluye la categoría: ventas y compras comparten el catálogo de productos.

"costo_unitario" y "cantidad" dependen de la clave completa, por lo que permanecen en "detalle_compra".

### 6.5 Tercera Forma Normal (3FN)

En "compra" hay dos **dependencias transitivas**:

- "razon_social", "cuit", "calle", "numero", "ciudad" y "provincia" dependen de "cod_proveedor", que a su vez depende de "cod_compra": cod_compra -> cod_proveedor -> razon_social. Se extraen a una tabla "proveedor".
- "nombre_usuario" y "rol" dependen de "cod_usuario", que a su vez depende de "cod_compra": cod_compra -> cod_usuario -> nombre_usuario. Se extraen a una tabla "usuario".

**compra (3FN)**

| cod_compra | fecha | estado | nro_comprobante_prov | cod_proveedor | cod_usuario |
|---|---|---|---|---|---|
| 201 | 2/9/2024 | Confirmada | 0003-00012458 | 12 | 3 |
| 202 | 3/9/2024 | Confirmada | 0001-00004521 | 15 | 3 |
| 203 | 8/9/2024 | Pendiente | NULL | 15 | 4 |

**proveedor**

| cod_proveedor | razon_social | cuit | calle | numero | ciudad | provincia |
|---|---|---|---|---|---|---|
| 12 | Distribuidora Norte S.A. | 30-71234567-8 | Av. Independencia | 1850 | Capital | Corrientes |
| 15 | ElectroHogar Litoral S.R.L. | 30-70987654-3 | Av. Sarmiento | 1200 | Resistencia | Chaco |

**usuario**

| cod_usuario | nombre_usuario | rol |
|---|---|---|
| 3 | lramirez | Depósito |
| 4 | mfernandez | Depósito |

En "proveedor", "cuit" es clave candidata (cuit -> cod_proveedor), así que no genera una dependencia transitiva: se mantiene en la tabla con restricción de unicidad (UQ).

"detalle_compra" y "producto" no sufren cambios en este paso: cada atributo depende directamente de su clave.

Con esto, "compra", "detalle_compra", "proveedor", "usuario" y "producto" alcanzan 3FN y coinciden con las tablas del modelo relacional (ver modelo-relacional.md).

"costo_unitario" en "detalle_compra" es un atributo histórico: guarda el costo pactado en esa compra y no se actualiza si el proveedor cambia sus precios después (RN.08). El monto total de la compra no se almacena: se calcula a partir de "costo_unitario" y "cantidad" de cada línea, igual que el total del pedido (RN.10).

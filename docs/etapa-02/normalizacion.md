# Proceso de Normalización

## 1. Fundamentos

Una **dependencia funcional** (DF) X->Y indica que el valor de los atributos en X determina de forma única el valor de los atributos en Y; X es el *determinante* e Y el *dependiente*. Sobre esta base se distinguen:

 **Dependencia completa**: Y depende de todo el conjunto de atributos X, no de una parte.

 **Dependencia parcial**: un atributo no clave depende funcionalmente de solo una parte de una clave compuesta, en lugar de la clave completa.

 **Dependencia transitiva**: un atributo no clave depende de otro atributo no clave, que a su vez depende de la clave primaria.

Un esquema sin normalizar produce **anomalías**: de inserción (no se puede registrar un producto nuevo sin que exista al menos un pedido que lo incluya), de actualización (si el email de un cliente cambia, habría que corregirlo en cada línea de pedido donde aparece) y de borrado (eliminar el único pedido de un cliente borraría también sus datos de contacto). La normalización elimina estas anomalías descomponiendo la tabla inicial según sus dependencias funcionales.

## 2. Tabla inicial obtenida de planilla original del negocio (sin normalizar)

| Cód. Pedido | Fecha | Cód. Cliente | Nombre y Apellido | Email | Dirección | Método Pago | Estado Pago | Ref. Transacción | Cód. Producto | Nombre Producto | Categoría | Precio Unitario | Cantidad |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 5001 | 5/9/2024 | 101 | Marcelo López | marcelo51@gmail.com | Calle Madariaga 2145, Corrientes Capital, CP 3400 | Tarjeta Crédito | Aprobado | TX-88231 | 3786 | Smart TV 50" | Electrónica | 350000 | 1 |
| 5001 | 5/9/2024 | 101 | Marcelo López | marcelo51@gmail.com | Calle Madariaga 2145, Corrientes Capital, CP 3400 | Tarjeta Crédito | Aprobado | TX-88231 | 4011 | Auriculares BT | Electrónica | 25000 | 2 |
| 5002 | 6/9/2024 | 107 | Silvia Gauna | sgauna@gmail.com | Av. Edison 306, Resistencia, Chaco, CP H3500 | Transferencia | Aprobado | TX-88232 | 5794 | Heladera 300L | Electrodomésticos | 480000 | 1 |
| 5003 | 7/9/2024 | 110 | María Gómez | mgomez@gmail.com | Chubut 3580, Posadas, Misiones, CP N3301 | Tarjeta Débito | Pendiente | TX-88233 | 4011 | Auriculares BT | Electrónica | 25000 | 2 |
| 5003 | 7/9/2024 | 110 | María Gómez | mgomez@gmail.com | Chubut 3580, Posadas, Misiones, CP N3301 | Tarjeta Débito | Pendiente | TX-88233 | 3141 | Funda Notebook | Accesorios | 8000 | 2 |

Se observa redundancia: los datos del cliente se repiten en cada línea de producto del mismo pedido, y el nombre/categoría del producto se repetiría en cualquier otro pedido que lo incluya.

### Dependencias funcionales identificadas

 cod_pedido -> fecha, cod_cliente, metodo_pago, estado_pago, ref_transaccion

 cod_cliente -> nombre_apellido, email, calle, numero, ciudad, provincia, cod_postal

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

Ambas tablas cumplen 1FN: valores atómicos, clave identificada (`cod_pedido` en pedido; `cod_pedido + cod_producto` en detalle_pedido), sin grupos repetitivos.

## 4. Segunda Forma Normal (2FN)

Una relación está en 2FN si está en 1FN y todos sus atributos no clave tienen una dependencia funcional completa de la clave primaria; es decir, no debe existir ninguna dependencia funcional parcial en la que un subconjunto de la clave primaria determine un atributo no clave.

pedido no cambia (su clave es simple, no aplica dependencia parcial). En detalle_pedido, la clave es compuesta: se detecta que nombre_producto y categoria dependen únicamente de cod_producto, una parte de la clave, no de la combinación completa. Es una **dependencia parcial**, por lo que se extraen a una tabla producto.

**detalle_pedido (2FN)**

| cod_pedido | cod_producto | precio_unitario | cantidad |
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

precio_unitario y cantidad sí dependen de la clave completa (esa combinación puntual de pedido y producto), por lo que permanecen en detalle_pedido.


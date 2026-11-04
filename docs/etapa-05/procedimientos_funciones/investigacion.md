# Procedimientos y funciones almacenadas
 
**Base de datos:** `smarthome_store` (SQL Server)
**Script:** [scripts.sql](scripts.sql) · **Capturas:** carpeta [evidencias](evidencias/)
 
---
 
## 1. Definición y objetivo
 
Un **procedimiento almacenado** es un programa SQL que se guarda dentro de la base de datos y puede hacer varias operaciones seguidas (insertar, actualizar, validar). Se ejecuta con `EXEC`.
 
Una **función** recibe parámetros y devuelve un valor (o una tabla). A diferencia del procedimiento, se puede usar dentro de un `SELECT`.
 
**Objetivo en nuestro proyecto:** que la lógica de la venta quede escrita una sola vez en la base de datos, en lugar de repetirse en cada consulta o en cada programa que use la base.
 
## 2. Ventajas y aplicaciones
 
- Reutilizan la lógica: la misma regla se usa en muchos lugares.
- Centralizan las reglas de negocio: si una regla cambia, se cambia en un solo lugar.
- Evitan que cada usuario tenga que ejecutar varias consultas a mano (y equivocarse).
- Facilitan la seguridad: se puede dar permiso para ejecutar un procedimiento sin dar permiso sobre las tablas (se usa en el tema Seguridad).
## 3. Implementación en SQL Server
 
| Objeto | Tipo | Qué hace |
|---|---|---|
| `tipo_items_pedido` | Tipo tabla | Permite pasar al procedimiento la lista de productos y cantidades de una venta |
| `fn_descuento_vigente(cod_producto, fecha)` | Función | Devuelve el mayor descuento de las promociones vigentes del producto en esa fecha (0 si no hay) |
| `fn_precio_final(cod_producto, fecha)` | Función | Devuelve el precio con IVA y con el descuento vigente |
| `fn_total_pedido(cod_pedido)` | Función | Devuelve el total de un pedido sumando su detalle |
| `sp_registrar_venta_completa` | Procedimiento | Registra pedido, detalle y descuenta stock en una sola operación |
| `fn_stock_disponible(cod_producto)` | Función escalar | Devuelve las unidades disponibles de un producto activo (0 si no existe o está inactivo) |
| `fn_pedidos_cliente(cod_cliente)` | Función de tabla en línea | Devuelve los pedidos de un cliente (fecha, estado, estado de pago) con su monto calculado |
| `usp_producto_insertar` | Procedimiento | Da de alta un producto validando nombre, categoría, alícuota y descripción |
| `usp_producto_modificar` | Procedimiento | Modifica los datos de un producto validando categoría, alícuota y descripción |
| `usp_producto_eliminar` | Procedimiento | Elimina un producto: baja física si no tiene historial, baja lógica si ya fue vendido o comprado |

Las funciones de la tabla se usan de dos formas distintas: `fn_descuento_vigente`, `fn_precio_final`, `fn_total_pedido` y `fn_stock_disponible` son **escalares** (devuelven un valor y se usan dentro de un `SELECT`), mientras que `fn_pedidos_cliente` es de **tabla en línea** (devuelve un conjunto de filas y se usa como si fuera una tabla, en el `FROM` o con `CROSS APPLY`).
 
## 4. Caso concreto aplicado a SmartHome Store
 
**Reglas de negocio que se implementan:**
 
- **RN.19 y RN.28:** el precio de lista es neto; el precio final se calcula sumando la alícuota de IVA del producto.
- **RN.24:** si un producto tiene más de una promoción vigente, se aplica la de mayor descuento. Las promociones que solo dan cuotas no son descuento.
- **RN.03:** el precio, la alícuota y el IVA se copian en `detalle_pedido` y no cambian después.
- **RN.10:** el total del pedido no se guarda; se calcula (`fn_total_pedido`).
- **RN.11:** un pedido no se confirma si el stock es insuficiente.
- **RN.09:** al confirmarse el pedido, el stock baja.
- **RN.06:** `usp_producto_insertar` exige que la categoría del producto exista y esté activa.
- **RN.28:** `usp_producto_insertar` y `usp_producto_modificar` exigen que la alícuota exista en el catálogo.
- **RN.09 y RN.11:** `fn_stock_disponible` informa el stock con el que se decide si un pedido puede confirmarse.
- **RN.10:** `fn_pedidos_cliente` calcula el monto de cada pedido desde el detalle, sin guardarlo.
- **RN.03 y RN.19:** modificar el precio de lista con `usp_producto_modificar` no cambia los pedidos ya registrados, porque el precio quedó copiado en `detalle_pedido`.
- **RN.14:** los cambios de precio y stock hechos por `usp_producto_modificar` quedan registrados por el trigger de auditoría.
- **RN.04 y RN.16:** el pedido usa la dirección principal del cliente, u otra de las suyas indicada en `@cod_direccion`, y la fecha actual. El procedimiento todavía no permite escribir una dirección solo para ese pedido, como prevé RN.04.

**Qué hace `sp_registrar_venta_completa`:**
 
1. Valida cliente activo, dirección, método de pago, referencia de pago y productos.
2. Verifica el stock de todos los productos.
3. Inserta el pedido (confirmado y con pago aprobado).
4. Inserta el detalle con el precio final de `fn_precio_final`.
5. Descuenta el stock.
Todo ocurre dentro de una transacción: si algo falla, no queda nada guardado.

**Qué hacen los procedimientos del catálogo de productos:**

- **`usp_producto_insertar`:** valida que el nombre no esté vacío, que la categoría exista y esté activa, que la alícuota exista y que la descripción no esté vacía (la columna `descripcion` es `NOT NULL`). Si todo está bien inserta el producto y devuelve el código generado en el parámetro de salida `@cod_producto`. Las restricciones `CHECK` de la tabla (precio mayor a 0, stock mayor o igual a 0) actúan como última barrera.
- **`usp_producto_modificar`:** valida que el producto, la categoría y la alícuota existan y que la descripción no esté vacía, y actualiza todos los datos del producto, incluida la baja o reactivación con `@activo`.
- **`usp_producto_eliminar`:** un producto con historial (en `detalle_pedido` o `detalle_compra`) no puede borrarse sin perder trazabilidad, y las claves foráneas de la base ya lo impiden. Por eso el procedimiento decide solo: si el producto no tiene historial hace un `DELETE` físico y devuelve `ELIMINADO`; si lo tiene, hace una baja lógica (`activo = 0`) y devuelve `BAJA_LOGICA`. Las promociones, multimedia y especificaciones del producto se borran en cascada.
 
**Errores propios que devuelve:**
 
| Código | Motivo |
|---|---|
| 50001 | Cliente inexistente o inactivo |
| 50002 | Método de pago inexistente |
| 50003 | La venta no tiene productos |
| 50004 | Producto inexistente o inactivo |
| 50005 | Stock insuficiente |
| 50006 | Falta la referencia de la transacción de pago |
| 50007 | La dirección no existe o no es del cliente |
| 50101 | `usp_producto_insertar`: el nombre del producto es obligatorio |
| 50102 | `usp_producto_insertar`: la categoría no existe o está inactiva |
| 50103 | `usp_producto_insertar`: la alícuota de IVA no existe |
| 50104 | `usp_producto_insertar`: la descripción es obligatoria |
| 50111 | `usp_producto_modificar`: el producto no existe |
| 50112 | `usp_producto_modificar`: la categoría no existe |
| 50113 | `usp_producto_modificar`: la alícuota de IVA no existe |
| 50114 | `usp_producto_modificar`: la descripción es obligatoria |
| 50121 | `usp_producto_eliminar`: el producto no existe |

Los códigos 50101 en adelante no se superponen con los 50001 a 50007 de `sp_registrar_venta_completa`. Además de estos errores propios, la base devuelve el error 547 cuando se viola un `CHECK` (por ejemplo, un precio negativo).
 
## 5. Demostración y resultados
 
Las pruebas están en las partes 2 y 4 de [scripts.sql](scripts.sql), y la comparación de eficiencia en la parte 5. El resultado esperado se calculó a partir de `cargar_datos.sql`. La columna **Obtenido** indica si el resultado de la captura coincide con el esperado.
 
| Prueba | Caso | Resultado esperado | Obtenido | Captura |
|---|---|---|---|---|
| A1 | Descuento y precio final al 20/09/2026 | Producto 4: descuento 35 % y precio 5200,00; el resto sin descuento | Sí | `01_funciones_precio.png` |
| A2 | Total de los pedidos 1, 2 y 9 | 245.000,00 / 89.250,00 / 405.000,01 | Sí | `02_total_pedido.png` |
| A3 | Función contra precios ya guardados | 0 filas | Sí | `03_control_precios.png` |
| B1 | Venta correcta (2 auriculares + 1 funda) | Pedido creado, total 58.000,00, stock 40→38 y 30→29 | Sí | `04_venta_correcta.png` |
| B2 | Stock insuficiente (6 lavarropas, hay 5) | Error 50005, sin pedido nuevo, stock sin cambios | Sí | `05_stock_insuficiente.png` |
| B3 | Cliente inexistente | Error 50001 | Sí | `06_cliente_inexistente.png` |
 
Pruebas de las funciones y procedimientos complementarios (parte 4 del script). El resultado esperado se calculó a partir de `cargar_datos.sql`.

| Prueba | Caso | Resultado esperado | Obtenido | Captura |
|---|---|---|---|---|
| C1 | Stock disponible de todo el catálogo | Coincide con `stock` en cada producto activo (producto 1 → 12, producto 2 → 40, producto 3 → 6); un producto inactivo da 0 | Sí | `C1_prueba.png` |
| C2 | Pedidos del cliente 2 con `fn_pedidos_cliente` | Pedido 2 → 89.250,00 y pedido 12 → 30.200,00 | Sí | `C2_prueba.png` |
| C3 | La función de tabla con `CROSS APPLY` sobre todos los clientes | Solo pedidos confirmados y con pago aprobado; los pedidos 10 (pendiente) y 11 (cancelado) no aparecen | Sí | `C3_prueba.png` |
| C4 | Casos límite: producto, pedido y cliente inexistentes | Precio `NULL`, stock 0, total 0,00 y 0 pedidos | Sí | `C4_prueba.png` |
| D1 | Alta de 5 productos con `INSERT` directo (lote `LOTE-A`) | 5 filas nuevas | Sí | `D1_prueba.png` |
| D2 | Alta de los mismos 5 productos con `usp_producto_insertar` (lote `LOTE-P`) | 5 filas nuevas y verificación de equivalencia con `iguales = 1` | Sí | `D2_prueba.png` |
| D3 | Modificar un producto con `usp_producto_modificar` | Precio de lista +10 % y stock −3 | Sí | `D3_prueba.png` |
| D4 | Eliminar un producto sin historial | Resultado `ELIMINADO` y 0 filas restantes | Sí | `D4_prueba.png` |
| D5 | Eliminar un producto con historial (dentro de una transacción que se deshace) | Resultado `BAJA_LOGICA`, `activo = 0` y, tras el `ROLLBACK`, `activo = 1` | Sí | `D5_prueba.png` |
| D6 | Casos de error de los procedimientos | Errores 50121, 50102 y 547 (precio negativo) | Sí | `D6_prueba.png` |

Notas:
 
- La prueba B1 se ejecuta dentro de una transacción que se deshace al final, para no modificar los datos de prueba de las etapas anteriores. Por eso se muestra el stock "antes", "después" y "tras el rollback".
- B1 espera 58.000,00 porque en la fecha de ejecución no hay promociones con descuento vigentes sobre esos productos. Si hubiera una, el precio y el total serían menores.
- D1 y D2 crean productos reales (`LOTE-A` y `LOTE-P`) que no se deshacen, por eso se ejecutan una sola vez. D3 y D4 trabajan sobre los productos `LOTE-P`, y D5 usa una transacción con `ROLLBACK` para no dejar inactivo un producto del catálogo original.
- Si la parte 2 se ejecuta después de D1 y D2, el listado de A1 incluye también los productos `LOTE-*`; el resultado esperado de A1 no cambia.

### Conclusiones de las pruebas complementarias

- **C1:** `fn_stock_disponible` devuelve para cada producto activo el mismo valor que la columna `stock` (producto 1 → 12, producto 2 → 40, producto 3 → 6). La función no agrega lógica propia al stock; solo la expone y devuelve 0 para productos inexistentes o inactivos.
- **C2:** `fn_pedidos_cliente(2)` devuelve el pedido 2 con 89.250,00 y el pedido 12 con 30.200,00, que coinciden con la suma del detalle (RN.10). El monto se calcula al consultar, no se guarda.
- **C3:** al usar la función de tabla con `CROSS APPLY` sobre todos los clientes aparecen 10 pedidos confirmados y con pago aprobado (1 a 9 y 12). Los pedidos 10 (pendiente) y 11 (cancelado) no aparecen. Esto muestra que una función de tabla en línea se comporta como una tabla más dentro de una consulta.
- **C4:** con datos inexistentes las funciones no fallan: `fn_precio_final` devuelve `NULL`, `fn_stock_disponible` devuelve 0, `fn_total_pedido` devuelve 0,00 y `fn_pedidos_cliente` devuelve 0 filas.
- **D1 y D2:** el alta con `INSERT` directo (productos 11 a 15) y con `usp_producto_insertar` (productos 16 a 20) produce los mismos datos: la verificación de equivalencia dio `iguales = 1` en los 5 pares. La diferencia es que el procedimiento valida antes de insertar.
- **D3:** `usp_producto_modificar` actualizó el producto 16: el precio pasó de 33.057,85 a 36.363,64 (+10 %) y el stock de 25 a 22. Por RN.03 este cambio no afecta a los pedidos ya registrados.
- **D4:** el producto 20 no tenía historial, por eso `usp_producto_eliminar` hizo un `DELETE` físico (`ELIMINADO`) y no quedaron filas.
- **D5:** el producto 1 ya fue vendido, por eso el procedimiento no lo borró: hizo una baja lógica (`BAJA_LOGICA`, `activo = 0`). Tras el `ROLLBACK` volvió a `activo = 1`, así que el catálogo original no se modificó.
- **D6:** los tres casos de error respondieron como se esperaba: producto inexistente → 50121, categoría inexistente → 50102, y precio negativo → 547, que lo frena la restricción `CHECK` de la tabla y no el procedimiento. Esto confirma que las validaciones del procedimiento y las restricciones de la tabla se complementan.

## 6. Comparación de eficiencia: operaciones directas vs. procedimientos y funciones

La parte 5 de [scripts.sql](scripts.sql) mide el tiempo de cada alternativa. Todo el banco de pruebas corre dentro de una transacción que se deshace, así que no deja datos (al final se restablece el contador `IDENTITY` de `producto`). Los tiempos se guardan en una variable de tabla, que el `ROLLBACK` no afecta. Se recomienda ejecutarlo **dos veces** y registrar la segunda, porque la primera incluye el costo de compilar los planes.

| Prueba | Qué compara | Repeticiones | Tiempo (ms) |
|---|---|---|---|
| A | `INSERT` directo en un bucle | 2.000 | 55 |
| B | `EXEC usp_producto_insertar` en un bucle (con sus validaciones) | 2.000 | 156 |
| C | Un solo `INSERT ... SELECT` (operación por conjuntos) | 2.000 | 300 |
| D | Monto de los pedidos con la función escalar `fn_total_pedido` | 240.000 | 11 |
| E | Monto de los pedidos con una subconsulta directa (`CROSS APPLY`) | 240.000 | 57 |

Los tiempos corresponden a la segunda ejecución (`prueba_eficiencia2.png`). La primera (`prueba_eficiencia1.png`) dio A = 55, B = 177, C = 326, D = 18 y E = 57 ms: fue algo más lenta en B, C y D, como se esperaba por el costo de compilar los planes.

Lo que muestran los resultados:

- **A contra B:** el procedimiento tardó 156 ms contra 55 ms del `INSERT` directo, unas 2,8 veces más. La diferencia (alrededor de 0,05 ms por alta) es el costo de la llamada y de las tres validaciones. En números absolutos es muy pequeña y a cambio las reglas quedan centralizadas y no dependen de quien escribe la consulta.
- **C:** el `INSERT ... SELECT` tardó 300 ms, más que A y B, lo contrario de lo esperado para una operación por conjuntos. Una explicación probable es que el tiempo no está en el `INSERT` sino en generar los 2.000 números con el producto cruzado de `sys.all_objects`, que se mide junto con él. Con este volumen, entonces, la prueba no permite concluir que la operación por conjuntos sea más lenta o más rápida que el bucle.
- **D contra E:** la función escalar `fn_total_pedido` tardó 11 ms contra 57 ms de la subconsulta con `CROSS APPLY`. Es el resultado opuesto a la advertencia habitual de que las funciones escalares son lentas, que se cumple cuando la función se ejecuta fila por fila. Una explicación probable es que SQL Server (desde 2019) expande ("inline") las funciones escalares simples como esta, de modo que se ejecuta como una consulta más.

**Conclusión:** con 2.000 altas o 240.000 cálculos las diferencias son de milisegundos, así que el uso de procedimientos y funciones no se justifica por velocidad sino por centralizar las reglas, evitar errores y poder dar permisos sin acceso a las tablas. El procedimiento tiene un pequeño costo de validación (B contra A), y la función escalar no resultó un problema de rendimiento en este caso. Los resultados de C y de D contra E dependen de cómo se armó la prueba y de la versión de SQL Server.

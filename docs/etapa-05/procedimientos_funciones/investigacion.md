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
 
## 4. Caso concreto aplicado a SmartHome Store
 
**Reglas de negocio que se implementan:**
 
- **RN.19 y RN.28:** el precio de lista es neto; el precio final se calcula sumando la alícuota de IVA del producto.
- **RN.24:** si un producto tiene más de una promoción vigente, se aplica la de mayor descuento. Las promociones que solo dan cuotas no son descuento.
- **RN.03:** el precio, la alícuota y el IVA se copian en `detalle_pedido` y no cambian después.
- **RN.10:** el total del pedido no se guarda; se calcula (`fn_total_pedido`).
- **RN.11:** un pedido no se confirma si el stock es insuficiente.
- **RN.09:** al confirmarse el pedido, el stock baja.
- **RN.04 y RN.16:** el pedido usa la dirección principal del cliente, u otra de las suyas indicada en `@cod_direccion`, y la fecha actual. El procedimiento todavía no permite escribir una dirección solo para ese pedido, como prevé RN.04.

**Qué hace `sp_registrar_venta_completa`:**
 
1. Valida cliente activo, dirección, método de pago, referencia de pago y productos.
2. Verifica el stock de todos los productos.
3. Inserta el pedido (confirmado y con pago aprobado).
4. Inserta el detalle con el precio final de `fn_precio_final`.
5. Descuenta el stock.
Todo ocurre dentro de una transacción: si algo falla, no queda nada guardado.
 
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
 
## 5. Demostración y resultados
 
Las pruebas están en la parte 2 de [scripts.sql](scripts.sql). El resultado esperado se calculó a partir de `cargar_datos.sql`. La columna **Obtenido** indica si el resultado de la captura coincide con el esperado.
 
| Prueba | Caso | Resultado esperado | Obtenido | Captura |
|---|---|---|---|---|
| A1 | Descuento y precio final al 20/09/2026 | Producto 4: descuento 35 % y precio 5200,00; el resto sin descuento | Sí | `01_funciones_precio.png` |
| A2 | Total de los pedidos 1, 2 y 9 | 245.000,00 / 89.250,00 / 405.000,01 | Sí | `02_total_pedido.png` |
| A3 | Función contra precios ya guardados | 0 filas | Sí | `03_control_precios.png` |
| B1 | Venta correcta (2 auriculares + 1 funda) | Pedido creado, total 58.000,00, stock 40→38 y 30→29 | Sí | `04_venta_correcta.png` |
| B2 | Stock insuficiente (6 lavarropas, hay 5) | Error 50005, sin pedido nuevo, stock sin cambios | Sí | `05_stock_insuficiente.png` |
| B3 | Cliente inexistente | Error 50001 | Sí | `06_cliente_inexistente.png` |
 
Notas:
 
- La prueba B1 se ejecuta dentro de una transacción que se deshace al final, para no modificar los datos de prueba de las etapas anteriores. Por eso se muestra el stock "antes", "después" y "tras el rollback".
- B1 espera 58.000,00 porque en la fecha de ejecución no hay promociones con descuento vigentes sobre esos productos. Si hubiera una, el precio y el total serían menores.

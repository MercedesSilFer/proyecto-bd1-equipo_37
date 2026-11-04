# Transacciones

**Base de datos:** `smarthome_store` (SQL Server)
**Script:** [scripts.sql](scripts.sql) · **Capturas:** carpeta [evidencias](evidencias/)

---

## 1. Definición y objetivo

Una **transacción** es una unidad de trabajo que se ejecuta completa o no se ejecuta. Agrupa varias sentencias SQL (insertar, actualizar, borrar) para que la base pase de un estado consistente a otro, sin dejar resultados a medias.

**Objetivo en nuestro proyecto:** que una venta no quede incompleta. Si se guarda el pedido pero falla el detalle o el descuento de stock, todo se revierte.

**ACID aplicado a la venta:**

| Propiedad | En SmartHome Store |
|---|---|
| Atomicidad | Pedido + detalle + stock, todo o nada |
| Consistencia | No se vende sin stock (RN.11); se cumplen CHECK y FK |
| Aislamiento | El procedimiento bloquea las filas de los productos (`UPDLOCK, HOLDLOCK`) hasta terminar la venta; no se probó con dos sesiones simultáneas |
| Durabilidad | Después del `COMMIT`, la venta persiste |

## 2. Ventajas y aplicaciones

- Garantizan que un conjunto de operaciones se aplique entero o no se aplique.
- Evitan datos inconsistentes (pedido sin detalle, stock descontado sin venta).
- Protegen el stock ante ventas simultáneas.
- Permiten revertir una operación fallida sin limpiar a mano.
- Sin transacción, un error a mitad de camino deja datos a medias: por ejemplo, un pedido sin detalle (se muestra en T10).

## 3. Implementación en SQL Server

| Elemento | Qué hace |
|---|---|
| `BEGIN TRANSACTION` | Abre la transacción |
| `COMMIT TRANSACTION` | Confirma y hace persistentes los cambios |
| `ROLLBACK TRANSACTION` | Revierte todo lo hecho desde el `BEGIN` |
| `SAVE TRANSACTION nombre` | Crea un punto de guardado |
| `ROLLBACK TRANSACTION nombre` | Vuelve solo hasta ese punto |
| `@@TRANCOUNT` | Cantidad de transacciones abiertas (0 = ninguna) |
| `@@ROWCOUNT` | Cantidad de filas afectadas por la última sentencia; sirve para detectar que un `UPDATE` no encontró filas (por ejemplo, por stock insuficiente) |
| `XACT_STATE()` | Estado de la transacción: 1 (se puede confirmar o revertir), 0 (no hay transacción) y −1 (condenada: solo admite un `ROLLBACK` total) |
| `SET XACT_ABORT ON` | Ante un error, aborta la transacción |
| `TRY...CATCH` + `THROW` | Captura el error, revierte y lo relanza |

**Patrón usado:**

```sql
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;
        ...
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
```

**Transacciones anidadas.** SQL Server lleva la cuenta con `@@TRANCOUNT`:

- Cada `BEGIN TRANSACTION` suma 1 y cada `COMMIT` resta 1. El `COMMIT` de una transacción interna **no confirma nada**: los cambios se hacen permanentes recién cuando el contador llega a 0.
- Un `ROLLBACK` sin nombre de punto de guardado **deshace todo** y deja el contador en 0, aunque haya transacciones internas abiertas.
- `SAVE TRANSACTION` permite deshacer solo una parte y seguir con el resto.

Un procedimiento transaccional puede llamarse con o sin una transacción abierta por quien lo llama, y hay dos formas de resolverlo:

| Enfoque | Cómo funciona | Si falla dentro de la transacción del llamador |
|---|---|---|
| `XACT_ABORT ON` + `@tran_propia` (`sp_registrar_venta_completa`, `sp_cancelar_pedido`) | Abre su transacción solo si no hay una abierta; si la hay, no abre otra | El error aborta toda la transacción del llamador, que debe revertirla completa (según la documentación de SQL Server; no se probó) |
| `SAVE TRANSACTION` (`usp_confirmar_compra`) | Si ya hay una transacción abierta, crea un punto de guardado y vuelve hasta ahí ante un error | Se deshace solo la parte del procedimiento y el llamador puede seguir (se muestra en T16) |

## 4. Caso concreto aplicado a SmartHome Store

**Reglas de negocio que se implementan:**

- **RN.03:** el precio, la alícuota y el IVA se copian en el detalle y no cambian después.
- **RN.09:** el stock baja al confirmarse la venta.
- **RN.11:** no se vende si el stock es insuficiente.
- **RN.30:** al cancelar un pedido confirmado, el stock se repone en la misma transacción (`sp_cancelar_pedido`).
- **RN.10:** el total se calcula desde el detalle.
- **RN.20 y RN.09:** una compra nace pendiente y solo al confirmarla (`usp_confirmar_compra`) pasa a recibida y sube el stock, todo en la misma transacción.
- **RN.04 y RN.16:** el pedido usa la dirección principal del cliente, u otra de las suyas indicada en `@cod_direccion`, y la fecha actual. El procedimiento todavía no permite escribir una dirección solo para ese pedido, como prevé RN.04.

**Qué se prueba en cada bloque:**

1. **T1:** una venta con `COMMIT`; el pedido y el stock quedan confirmados.
2. **T2:** una venta sin stock; el procedimiento lanza el error 50005 y se revierte todo.
3. **T3:** un pedido, un detalle válido y un detalle inválido; el `CHECK` falla y no queda nada.
4. **T4:** un punto de guardado; se revierte el detalle pero no el pedido.
5. **T5:** el procedimiento dentro de una transacción del llamador; no confirma por su cuenta.
6. **T6:** la cancelación de un pedido; el estado y el stock cambian juntos, y se rechaza la de un pedido facturado o despachado.
7. **T7:** Escrito en T-SQL explícito (pedido, detalle y stock); termina en `COMMIT`.
8. **T8:** la misma operación con un error provocado después del primer `INSERT`; el `CATCH` revierte todo.
9. **T9:** la misma operación con stock insuficiente; el `UPDATE` no encuentra filas, lanza el error 50211 y se revierten los dos `INSERT`.
10. **T10:** contraste: el mismo error **sin transacción** deja un pedido sin detalle (datos inconsistentes).
11. **T11:** transacciones anidadas: el `COMMIT` interno solo resta 1 a `@@TRANCOUNT` y el `ROLLBACK` externo deshace todo.
12. **T12:** un `ROLLBACK` dentro de la transacción interna deshace también la externa y deja el contador en 0.
13. **T13:** punto de guardado: se deshace una parte, la transacción sigue abierta y el resto se confirma.
14. **T14:** `usp_confirmar_compra` confirma una compra pendiente: cambia el estado y sube el stock.
15. **T15:** `usp_confirmar_compra` rechaza compras ya recibidas, canceladas o inexistentes sin dejar transacciones abiertas.
16. **T16:** `usp_confirmar_compra` dentro de una transacción externa: un error deshace solo su parte y la transacción del llamador sigue vigente.

**Errores que se controlan:**

| Código | Motivo |
|---|---|
| 50005 | Stock insuficiente |
| 547 | Violación de un `CHECK` (cantidad = 0) |
| 50008 | Pedido inexistente |
| 50009 | El pedido ya está cancelado |
| 50010 | El pedido ya tiene factura |
| 50011 | El pedido ya fue despachado o entregado |
| 50211 | Stock insuficiente en la transacción escrita en T-SQL explícito (T7 a T9) |
| 50221 | `usp_confirmar_compra`: la compra no existe o no está pendiente |
| 50299 | Error provocado a propósito para probar el `ROLLBACK` (T8 y T10) |

## 5. Demostración y resultados

Las pruebas están en [scripts.sql](scripts.sql). La columna **Obtenido** indica si el resultado de la captura coincide con el esperado.

| Prueba | Caso | Resultado esperado | Obtenido | Captura |
|---|---|---|---|---|
| T1 | Venta con `COMMIT` | Stock 40→39; total 25.000,00; la limpieza lo devuelve a 40 | Sí | `01_commit_venta.png` |
| T2 | Stock insuficiente | Error 50005; pedidos 12/12; stock 5; `@@TRANCOUNT` 0 | Sí | `02_rollback_error.png` |
| T3 | Atomicidad | Error 547; pedidos 12/12; detalles 18/18 | Sí | `03_atomicidad.png` |
| T4 | Punto de guardado | Detalle 1→0 con el pedido vivo; tras el rollback total, 0 | Sí | `04_savepoint.png` |
| T5 | Transacción del llamador | `tran_count` 1 y stock 39; tras el rollback, 40 y 0 | Sí | `05_transaccion_llamador.png` |
| T6 | Cancelación de un pedido | Confirmado: stock 40→39→40; pendiente: stock sin cambios; errores 50008 a 50011 | Sí | `06_cancelacion_pedido.png` |

Notas:

- T1 crea un pedido y lo elimina al final, para no alterar los datos de las etapas anteriores.
- T2, T3 y T4 terminan en `ROLLBACK`.
- La evidencia de T6 es la salida de `sqlcmd` sobre una base temporal recién cargada, no una captura de SSMS. Sus pruebas que modifican datos se revierten.
- La cancelación no reintegra el pago: el reintegro corresponde a la pasarela, que queda fuera del alcance. El pedido deja de contar como venta porque ya no está confirmado.
- El permiso que impide cambiar `estado` con un `UPDATE` directo está en [01_permisos_estado_pedido.sql](../../../sql/tecnico/seguridad/01_permisos_estado_pedido.sql).
- T5 demuestra que el procedimiento respeta la transacción del llamador (`@tran_propia`).
- Al terminar, la base queda con 12 pedidos y 18 detalles.

## 6. Transacciones anidadas y pruebas adicionales

Estas pruebas (T7 a T16) están en la parte 2 de [scripts.sql](scripts.sql).  Usan `fn_precio_final` y la dirección principal del cliente, igual que `sp_registrar_venta_completa`. 

| Prueba | Caso | Resultado esperado | Obtenido | Captura |
|---|---|---|---|---|
| T7 | Transacción explícita con `COMMIT` (pedido, detalle y stock) | Pedidos 12→13, líneas 18→19, stock del producto 2: 40→39; tras la limpieza, 12, 18 y 40 | Sí | `07_tx_explicita_commit.png` |
| T8 | Error provocado después del primer `INSERT` | Error 50299; pedidos 12, líneas 18 y stock 40, antes y después | Sí | `08_tx_explicita_error.png` y `08_tx_explicita_error_Mensajes.png` |
| T9 | Stock insuficiente (9999 unidades) en T-SQL explícito | Error 50211; pedidos 12, líneas 18 y stock 40, antes y después | Sí | `09_tx_explicita_stock.png` y `09_tx_explicita_stock_Mensajes.png` |
| T10 | Contraste: el mismo error sin transacción | Pedidos 12→13 con un pedido huérfano (sin detalle), líneas 18 y stock 40; tras la limpieza, 12 pedidos | Sí | `10_sin_transaccion.png` y `10_sin_transaccion_Mensajes.png` |
| T11 | `COMMIT` interno + `ROLLBACK` externo | `@@TRANCOUNT` 0, 1, 2, 1 y 0; filas `DEMO-ANIDADA-1` = 0 | Sí | `11_anidada_commit_rollback.png` y `11_anidada_commit_rollback_Mensajes.png` |
| T12 | `ROLLBACK` dentro de la transacción interna | `@@TRANCOUNT` 0 tras el `ROLLBACK` interno; filas `DEMO-ANIDADA-2` = 0 | Sí | `12_anidada_rollback_interno.png` y `12_anidada_rollback_interno_Mensajes.png` |
| T13 | Punto de guardado: se deshace una parte y se confirma el resto | `@@TRANCOUNT` 1 tras el `ROLLBACK` al punto; después del `COMMIT` queda solo `DEMO-SP-A` | Sí | `13_punto_recuperacion.png` y `13_punto_recuperacion_Mensajes.png` |
| T14 | `usp_confirmar_compra` sobre la compra 9 (pendiente) | Estado pendiente→recibida; stock del producto 1: 12→17 y del 9: 15→20; tras el `ROLLBACK`, vuelve a pendiente, 12 y 15 | Sí | `14_confirmar_compra.png` |
| T15 | `usp_confirmar_compra` con compras que no se pueden confirmar | Tres errores 50221 (compras 1, 10 y 999), `@@TRANCOUNT` 0 y estados sin cambios (1 recibida, 9 pendiente, 10 cancelada) | Sí | `15_confirmar_compra_errores.png` |
| T16 | `usp_confirmar_compra` dentro de una transacción externa | Tras la confirmación rechazada: `@@TRANCOUNT` 1, estado de la transacción 1, compra 9 recibida y stock del producto 1 = 17; tras el `ROLLBACK` externo, pendiente y 12 | Sí | `16_confirmar_compra_anidada.png` y `16_confirmar_compra_anidada_Mensajes.png` |

Notas:

- T7 y T10 modifican datos y los eliminan al final (T7 repone el stock en otra transacción); T8, T9, T14 y T16 terminan en `ROLLBACK`, y T15 no modifica nada. Si una prueba se interrumpe a mitad de camino y quedan pedidos de prueba, se puede usar `99_limpieza_demo.sql`.
- T7 a T10 dejan el pedido confirmado con el pago aprobado y una referencia de transacción.
- Los resultados de los `PRINT` de T7 a T13 se ven en la pestaña **Mensajes**.
- T14 y T16 usan la compra 9, la única pendiente de la carga inicial; por eso se revierten al final.
- En T8, T9 y T10 la captura de **Mensajes** muestra el texto del error (el `PRINT` usa `ERROR_MESSAGE()`), no su número. Los textos coinciden con los de los errores 50299 (T8 y T10) y 50211 (T9).
- T16 se ejecutó con `XACT_ABORT OFF` en la sesión (el script lo indica al empezar), así que demuestra el comportamiento de `SAVE TRANSACTION`. No prueba, en cambio, qué pasa con `XACT_ABORT ON` ni que el `SET XACT_ABORT OFF` dentro de `usp_confirmar_compra` proteja el caso en que la sesión lo tenga activado.

## 7. Conclusiones

- **La transacción evita datos a medias:** con el mismo error, T8 no deja nada y T10 deja un pedido sin detalle.
- **Un `COMMIT` interno no confirma nada:** solo baja `@@TRANCOUNT`. Los cambios se hacen permanentes con el `COMMIT` más externo.
- **Un `ROLLBACK` sin nombre deshace todo:** aunque esté en una transacción interna, revierte también la externa y deja `@@TRANCOUNT` en 0.
- **Para deshacer una parte hace falta un punto de recuperación:** con `SAVE TRANSACTION` se revierte solo lo posterior a ese punto, sin cerrar la transacción.
- **Un procedimiento tiene que respetar la transacción de quien lo llama:** por eso solo abren una si no hay otra abierta (T5 y T16).
- **Hay dos formas de respetarla:** con `XACT_ABORT ON`, un error aborta toda la transacción del llamador (`sp_registrar_venta_completa`, `sp_cancelar_pedido`; es el comportamiento que describe la documentación y no se probó); con `SAVE TRANSACTION`, el procedimiento deshace solo su parte y el llamador puede seguir (`usp_confirmar_compra`, T16, probado).
- **El aislamiento entre sesiones sigue sin probarse:** las pruebas corren en una sola sesión, así que el bloqueo por `UPDLOCK` y `HOLDLOCK` no quedó demostrado con dos ventas simultáneas.


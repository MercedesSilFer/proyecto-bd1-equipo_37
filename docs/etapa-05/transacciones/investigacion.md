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

## 3. Implementación en SQL Server

| Elemento | Qué hace |
|---|---|
| `BEGIN TRANSACTION` | Abre la transacción |
| `COMMIT TRANSACTION` | Confirma y hace persistentes los cambios |
| `ROLLBACK TRANSACTION` | Revierte todo lo hecho desde el `BEGIN` |
| `SAVE TRANSACTION nombre` | Crea un punto de guardado |
| `ROLLBACK TRANSACTION nombre` | Vuelve solo hasta ese punto |
| `@@TRANCOUNT` | Cantidad de transacciones abiertas (0 = ninguna) |
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

## 4. Caso concreto aplicado a SmartHome Store

**Reglas de negocio que se implementan:**

- **RN.03:** el precio, la alícuota y el IVA se copian en el detalle y no cambian después.
- **RN.09:** el stock baja al confirmarse la venta.
- **RN.11:** no se vende si el stock es insuficiente.
- **RN.30:** al cancelar un pedido confirmado, el stock se repone en la misma transacción (`sp_cancelar_pedido`).
- **RN.10:** el total se calcula desde el detalle.
- **RN.04 y RN.16:** el pedido usa la dirección principal del cliente, u otra de las suyas indicada en `@cod_direccion`, y la fecha actual. El procedimiento todavía no permite escribir una dirección solo para ese pedido, como prevé RN.04.

**Qué se prueba en cada bloque:**

1. **T1:** una venta con `COMMIT`; el pedido y el stock quedan confirmados.
2. **T2:** una venta sin stock; el procedimiento lanza el error 50005 y se revierte todo.
3. **T3:** un pedido, un detalle válido y un detalle inválido; el `CHECK` falla y no queda nada.
4. **T4:** un punto de guardado; se revierte el detalle pero no el pedido.
5. **T5:** el procedimiento dentro de una transacción del llamador; no confirma por su cuenta.
6. **T6:** la cancelación de un pedido; el estado y el stock cambian juntos, y se rechaza la de un pedido facturado o despachado.

**Errores que se controlan:**

| Código | Motivo |
|---|---|
| 50005 | Stock insuficiente |
| 547 | Violación de un `CHECK` (cantidad = 0) |
| 50008 | Pedido inexistente |
| 50009 | El pedido ya está cancelado |
| 50010 | El pedido ya tiene factura |
| 50011 | El pedido ya fue despachado o entregado |

## 5. Demostración y resultados

Las pruebas están en [scripts.sql](scripts.sql). La columna **Obtenido** indica si el resultado de la captura coincide con el esperado.

| Prueba | Caso | Resultado esperado | Obtenido | Captura |
|---|---|---|---|---|
| T1 | Venta con `COMMIT` | Stock 40→39; total 25.000,00; la limpieza lo devuelve a 40 | Sí | `01_commit_venta.png` |
| T2 | Stock insuficiente | Error 50005; pedidos 12/12; stock 5; `@@TRANCOUNT` 0 | Sí | `02_rollback_error.png` |
| T3 | Atomicidad | Error 547; pedidos 12/12; detalles 18/18 | Sí | `03_atomicidad.png` |
| T4 | Punto de guardado | Detalle 1→0 con el pedido vivo; tras el rollback total, 0 | Sí | `04_savepoint.png` |
| T5 | Transacción del llamador | `tran_count` 1 y stock 39; tras el rollback, 40 y 0 | Sí | `05_transaccion_llamador.png` |
| T6 | Cancelación de un pedido | Confirmado: stock 40→39→40; pendiente: stock sin cambios; errores 50008 a 50011 | Sí | Falta |

Notas:

- T1 crea un pedido y lo elimina al final, para no alterar los datos de las etapas anteriores.
- T2, T3 y T4 terminan en `ROLLBACK`.
- T6 se verificó ejecutando el script, y falta su captura. Sus pruebas que modifican datos se revierten.
- La cancelación no reintegra el pago: el reintegro corresponde a la pasarela, que queda fuera del alcance. El pedido deja de contar como venta porque ya no está confirmado.
- T5 demuestra que el procedimiento respeta la transacción del llamador (`@tran_propia`).
- Al terminar, la base queda con 12 pedidos y 18 detalles.
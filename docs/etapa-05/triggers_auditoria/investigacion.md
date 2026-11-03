# Triggers y auditoría

**Base de datos:** `smarthome_store` (SQL Server)
**Script:** [scripts.sql](scripts.sql) · **Capturas:** carpeta [evidencias](evidencias/)

---

## 1. Definición y objetivo

Un **trigger** (disparador) es un bloque de código que el motor ejecuta automáticamente cuando ocurre un `INSERT`, un `UPDATE` o un `DELETE` sobre una tabla. No lo llama la aplicación: se dispara solo.

Sirve para reglas que no se pueden escribir con `CHECK` o `FOREIGN KEY`, y para dejar rastro de los cambios.

**Objetivo en nuestro proyecto (RN.14):** que todo cambio sobre datos sensibles (precios, stock, pedidos, compras y facturación) quede registrado en `auditoria` con el usuario responsable, la operación y la fecha.

## 2. Ventajas y aplicaciones

- La regla vive en la base: no depende de que cada aplicación se acuerde de auditar.
- Se ejecuta en la misma transacción que la sentencia: si la auditoría falla, el cambio también se revierte.
- También se dispara con un `UPDATE` hecho a mano en SSMS, aunque quien tenga permisos puede apagarlo con `DISABLE TRIGGER`.
- Guarda el valor anterior y el nuevo, algo que un `CHECK` no puede hacer.

Cuidados:

- Agregan trabajo a cada sentencia; conviene que sean cortos y sin cursores.
- La lógica queda "escondida": quien mira el `UPDATE` no ve el trigger.
- Un trigger mal escrito puede entrar en recursión o bloquear filas de más.

## 3. Implementación en SQL Server

| Elemento | Qué hace |
|---|---|
| `AFTER` (o `FOR`) | Se ejecuta después de la sentencia, dentro de la misma transacción |
| `INSTEAD OF` | Reemplaza la sentencia; se usa en vistas y validaciones |
| `inserted` | Filas nuevas (`INSERT` y `UPDATE`) |
| `deleted` | Filas anteriores (`DELETE` y `UPDATE`) |
| `UPDATE(columna)` | Indica si la columna apareció en el `SET` |
| `TRIGGER_NESTLEVEL()` | Nivel de anidamiento del trigger |
| `DISABLE` / `ENABLE TRIGGER` | Apaga o prende un trigger |

**Sintaxis:**

```sql
CREATE OR ALTER TRIGGER dbo.trg_ejemplo
ON dbo.tabla
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.auditoria (entidad, operacion, registro_id, valor_anterior, valor_nuevo, cod_usuario)
    SELECT 'tabla',
           CASE WHEN d.id IS NULL THEN 'INSERT'
                WHEN i.id IS NULL THEN 'DELETE'
                ELSE 'UPDATE' END,
           COALESCE(i.id, d.id),
           ...
    FROM inserted i
    FULL OUTER JOIN deleted d ON d.id = i.id;
END;
```

Ideas clave:

- Un trigger se ejecuta **una vez por sentencia**, no por fila. Por eso se trabaja con `inserted` y `deleted` en conjunto (`FULL OUTER JOIN`) y nunca con cursores.
- En un `UPDATE`, `inserted` tiene los valores nuevos y `deleted` los anteriores; en un `INSERT` solo hay `inserted`; en un `DELETE` solo `deleted`.
- `UPDATE(columna)` devuelve verdadero aunque el valor no haya cambiado. Para auditar solo cambios reales conviene comparar: `i.stock <> d.stock`.
- Un trigger puede llamar a otro (anidamiento) y, con la opción `RECURSIVE_TRIGGERS`, llamarse a sí mismo. `TRIGGER_NESTLEVEL()` permite cortar la cadena.
- Si el trigger hace `ROLLBACK` o falla, la sentencia también se revierte: el cambio y su auditoría son atómicos.

## 4. Caso concreto aplicado a SmartHome Store

**Reglas de negocio que se implementan:**

- **RN.14:** precios, stock, pedidos, compras y facturación quedan auditados con usuario, operación y fecha.
- **RN.21:** la factura queda asociada al usuario que la emitió; el trigger deja además el registro de la emisión.

| Trigger | Tabla | Qué registra | Cuándo |
|---|---|---|---|
| `trg_producto_auditoria` | `producto` | `precio_lista` y `stock` | `INSERT`, `DELETE` y `UPDATE` cuando alguno cambia |
| `trg_pedido_auditoria` | `pedido` | `estado`, `estado_pago`, `estado_envio` | `INSERT`, `DELETE` y `UPDATE` cuando alguno cambia |
| `trg_compra_auditoria` | `compra` | `estado` | `INSERT`, `DELETE` y `UPDATE` cuando cambia |
| `trg_factura_auditoria` | `factura` | tipo, número y total | `INSERT`, `DELETE` y cualquier `UPDATE` |

**Usuario responsable:** `auditoria.cod_usuario` es `INT NOT NULL` con FK a `usuario`, pero el login de SQL Server (`SUSER_SNAME()`) es texto y no coincide con ese código. Por eso el código viaja en `SESSION_CONTEXT`, que la aplicación fija al iniciar sesión:

```sql
EXEC sys.sp_set_session_context @key = N'cod_usuario', @value = 3;
```

Si la sesión no lo fijó, el trigger usa el usuario 1 (`mgonzalez`, administrador) como usuario del sistema, para que la auditoría no falle por ese motivo. Limitación: en ese caso el cambio queda a nombre de ese usuario aunque lo haya hecho otra persona, y la tabla no guarda el login de la base de datos.

**Formato de los valores:** texto corto con los campos que cambiaron, por ejemplo `precio_lista=20661.16; stock=40`. La fecha la completa el `DEFAULT GETDATE()` de la tabla.

**Por qué no hay recursión:** ningún trigger escribe en una tabla que tenga otro trigger; el único destino es `auditoria`. El control `TRIGGER_NESTLEVEL()` queda igual como protección.

## 5. Demostración y resultados

Las pruebas están en la parte 2 de [scripts.sql](scripts.sql). La columna **Obtenido** indica si el resultado de la captura coincide con el esperado.

| Prueba | Caso | Resultado esperado | Obtenido | Captura |
|---|---|---|---|---|
| A0 | Triggers creados | 4 triggers, `AFTER`, habilitados | Sí | `01_triggers_creados.png` |
| A1 | `UPDATE` de stock | 1 fila: anterior `stock=40`, nuevo `stock=39`, usuario 3; tras la limpieza, stock 40 y 10 filas | Sí | `02_auditoria_stock.png` |
| A2 | `INSERT` + `DELETE` de producto | 2 filas: `INSERT` con anterior `NULL` y `DELETE` con nuevo `NULL`, usuario 9 | Sí | `03_auditoria_insert_delete.png` |
| A3 | Venta con el procedimiento | 2 filas (pedido `INSERT` y producto `UPDATE`), usuario 4; tras el `ROLLBACK`, 10 filas y stock 40 | Sí | `04_auditoria_venta.png` |
| A4 | Usuario inexistente (999) | Error 547 (FK); stock 40; auditoría 10 | Sí | `05_auditoria_error.png` |
| A5 | `UPDATE` de los 10 productos | 10 filas en una sola sentencia; tras la limpieza, 10 filas | Sí | `06_auditoria_masiva.png` |

Notas:

- A1, A2 y A5 revierten el cambio y borran las filas de auditoría que generaron.
- A3 hace `ROLLBACK`: la auditoría desaparece con la venta, porque es transaccional.
- A4: el `UPDATE` se ejecuta, pero el trigger no puede insertar en `auditoria` (FK) y el cambio se revierte: si la auditoría falla, el cambio no se aplica.
- Al terminar, `auditoria` vuelve a 10 filas y el stock queda como en la Etapa IV.
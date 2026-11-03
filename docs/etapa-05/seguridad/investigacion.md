# Manejo de permisos a nivel de usuarios de base de datos

**Base de datos:** `smarthome_store` (SQL Server)
**Scripts:** [sql/tecnico/seguridad](../../../sql/tecnico/seguridad/)

---

## 1. Definición y objetivo

Los **permisos** definen qué puede hacer cada usuario sobre cada objeto de la base. Un **rol** agrupa permisos para asignarlos a varios usuarios de una sola vez.

**Objetivo en nuestro proyecto:** que cada usuario tenga solo los permisos que necesita, y que las operaciones sensibles, como vender o cancelar un pedido, pasen por los procedimientos en lugar de modificar las tablas directamente.

## 2. Ventajas y aplicaciones

- Limitan el daño de un error o de una cuenta comprometida.
- Permiten ofrecer una operación sin abrir las tablas: el usuario ejecuta el procedimiento, pero no puede escribir en ellas.
- Con roles, cambiar los permisos de un grupo se hace en un solo lugar.

## 3. Implementación en SQL Server

| Elemento | Qué hace |
|---|---|
| Inicio de sesión (`LOGIN`) | Identidad a nivel del servidor; permite conectarse |
| Usuario (`USER`) | Identidad dentro de una base, asociada a un inicio de sesión |
| `db_owner` | Rol fijo con control total sobre la base |
| `db_datareader` | Rol fijo que permite leer todas las tablas |
| `CREATE ROLE` | Crea un rol propio |
| `GRANT` | Otorga un permiso |
| `DENY` | Niega un permiso, aunque otro rol lo otorgue |
| `EXECUTE AS` / `REVERT` | Ejecuta como otro usuario y vuelve al original |

**Modo de autenticación:** el modo mixto admite cuentas de Windows y de SQL Server. Es una configuración del servidor, no de la base, y cambiarla requiere reiniciar el servicio. Se consulta con `SELECT SERVERPROPERTY('IsIntegratedSecurityOnly')`: 0 es mixto y 1 es solo Windows.

**Encadenamiento de propiedad:** si un procedimiento y las tablas que usa tienen el mismo dueño, SQL Server solo verifica el permiso para ejecutar el procedimiento. Por eso un usuario sin permiso de escritura puede insertar a través de él. Como la venta recibe un tipo tabla, también hace falta `GRANT EXECUTE ON TYPE`.

## 4. Caso concreto aplicado a SmartHome Store

| Script | Qué hace |
|---|---|
| [01_permisos_estado_pedido.sql](../../../sql/tecnico/seguridad/01_permisos_estado_pedido.sql) | `rol_aplicacion`: solo puede cambiar el estado de un pedido con los procedimientos, para que el stock cambie junto con el estado |
| [02_usuarios_y_roles.sql](../../../sql/tecnico/seguridad/02_usuarios_y_roles.sql) | Los casos prácticos de usuarios y de roles |
| [99_limpieza_usuarios.sql](../../../sql/tecnico/seguridad/99_limpieza_usuarios.sql) | Elimina los usuarios, el rol y los inicios de sesión de la demostración |

| Usuario | Permisos |
|---|---|
| `smarthome_admin` | Administrador de la base (`db_owner`) |
| `smarthome_lectura` | Solo lectura (`db_datareader`), y ejecución de `sp_registrar_venta_completa` |
| `smarthome_con_rol` | Miembro de `rol_lectura_producto`, que solo puede leer `producto` |
| `smarthome_sin_rol` | Ningún permiso sobre las tablas |

## 5. Demostración y resultados

Las pruebas del script se ejecutaron con `sqlcmd` sobre una base temporal, con `EXECUTE AS LOGIN`, que aplica los permisos de cada usuario sin importar el modo de autenticación. Los cambios se revierten.

| Prueba | Caso | Resultado esperado | Obtenido |
|---|---|---|---|
| U1 | `INSERT` directo con `smarthome_admin` | Se inserta 1 fila | Sí |
| U2 | `SELECT` con `smarthome_lectura` | Lee los 12 pedidos | Sí |
| U3 | `INSERT` directo con `smarthome_lectura` | Error 229 | Sí |
| U4 | `INSERT` con el procedimiento y `smarthome_lectura` | Pedido creado y stock 40→39 | Sí |
| U5 | `UPDATE` directo con `smarthome_lectura` | Error 229 | Sí |
| R1 | `SELECT` de `producto` con `smarthome_con_rol` | Lee los 10 productos | Sí |
| R2 | `SELECT` de `producto` con `smarthome_sin_rol` | Error 229 | Sí |
| R3 | `SELECT` de `pedido` con `smarthome_con_rol` | Error 229: el rol no alcanza a esa tabla | Sí |
| S1 | `UPDATE` de `pedido.estado` con `usuario_aplicacion` | Error 230 | Sí |
| S3 | Venta y cancelación con procedimientos y `usuario_aplicacion` | Pedido cancelado y stock 40 | Sí |

**Modo de autenticación:** el servidor estaba en modo solo Windows (`IsIntegratedSecurityOnly` = 1). Se activó el modo mixto desde las propiedades del servidor en SSMS y se reinició el servicio, con lo que el valor pasó a 0.

Después se repitieron las pruebas principales iniciando sesión de verdad con `sqlcmd -U`:

| Usuario | Operación | Resultado |
|---|---|---|
| `smarthome_lectura` | Lee `pedido` | Lee los 12 pedidos |
| `smarthome_lectura` | `INSERT` directo en `pedido` | Error 229 |
| `smarthome_lectura` | Venta con el procedimiento | Pedido confirmado |
| `smarthome_admin` | `INSERT` directo en `pedido` | Se inserta 1 fila |
| `smarthome_con_rol` | Lee `producto` | Lee los 10 productos |
| `smarthome_sin_rol` | Lee `producto` | Error 229 |
| `smarthome_lectura` con contraseña incorrecta | Inicio de sesión | Rechazado |

## 6. Conclusiones

- **Un permiso sobre el procedimiento no abre la tabla:** `smarthome_lectura` no puede insertar en `pedido`, pero sí registrar una venta con el procedimiento, que además valida los datos y mantiene el stock.
- **Los roles evitan repetir permisos:** alcanza con sumar un usuario a `rol_lectura_producto` para que pueda leer. La diferencia entre R1 y R2 es solo esa pertenencia.
- **Los permisos se aplican objeto por objeto:** el mismo usuario que lee `producto` no puede leer `pedido` (R3).
- **`DENY` no alcanza a todos:** `dbo` y los miembros de `sysadmin` no quedan alcanzados. Por eso la aplicación no debería conectarse con esas cuentas.
- **Las contraseñas de los scripts son solo para la demostración:** en un sistema real no deberían estar en el repositorio.

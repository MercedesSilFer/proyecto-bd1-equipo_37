-- =============================================================
-- ETAPA V - Seguridad: permisos sobre el estado del pedido
-- La aplicación solo puede cambiar el estado de un pedido a través
-- de los procedimientos, para que el stock cambie junto con el estado.
-- Requiere los scripts de procedimientos_funciones y transacciones.
--
-- Limitación: dbo y sysadmin no quedan alcanzados por DENY.
-- =============================================================

USE smarthome_store;
GO

IF DATABASE_PRINCIPAL_ID('rol_aplicacion') IS NULL
    CREATE ROLE rol_aplicacion;
GO

IF DATABASE_PRINCIPAL_ID('usuario_aplicacion') IS NULL
    CREATE USER usuario_aplicacion WITHOUT LOGIN;
GO

ALTER ROLE rol_aplicacion ADD MEMBER usuario_aplicacion;
GO

GRANT SELECT ON dbo.pedido TO rol_aplicacion;
GRANT UPDATE ON dbo.pedido (estado_envio, fecha_envio, transportista, fecha_entrega, nro_seguimiento, cod_usuario) TO rol_aplicacion;
DENY UPDATE ON dbo.pedido (estado) TO rol_aplicacion;
GRANT EXECUTE ON dbo.sp_registrar_venta_completa TO rol_aplicacion;
GRANT EXECUTE ON dbo.sp_cancelar_pedido TO rol_aplicacion;
GRANT EXECUTE ON TYPE::dbo.tipo_items_pedido TO rol_aplicacion;
GO

-- S1. UPDATE directo del estado. Esperado: error 230 y estado sin cambios.
EXECUTE AS USER = 'usuario_aplicacion';

BEGIN TRY
    UPDATE dbo.pedido SET estado = 'cancelado' WHERE cod_pedido = 10;
END TRY
BEGIN CATCH
    SELECT 'S1' AS prueba, ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;

REVERT;

SELECT 'S1' AS prueba, cod_pedido, estado FROM dbo.pedido WHERE cod_pedido = 10;
GO

-- S2. Datos de envío, permitidos. Esperado: 1 fila; se revierte.
BEGIN TRANSACTION;

EXECUTE AS USER = 'usuario_aplicacion';
UPDATE dbo.pedido SET transportista = 'Prueba' WHERE cod_pedido = 10;
SELECT 'S2' AS prueba, @@ROWCOUNT AS filas;
REVERT;

ROLLBACK TRANSACTION;
GO

-- S3. Venta y cancelación con los procedimientos, sin permisos sobre producto.
-- Esperado: pedido cancelado y stock 40; se revierte.
BEGIN TRANSACTION;

EXECUTE AS USER = 'usuario_aplicacion';

DECLARE @items dbo.tipo_items_pedido;
DECLARE @nuevo INT;

INSERT INTO @items (cod_producto, cantidad) VALUES (2, 1);

EXEC dbo.sp_registrar_venta_completa
     @cod_cliente     = 1,
     @cod_metodo_pago = 1,
     @ref_transaccion = 'TX-S3',
     @items           = @items,
     @cod_pedido      = @nuevo OUTPUT;

EXEC dbo.sp_cancelar_pedido @cod_pedido = @nuevo;

SELECT 'S3' AS prueba, estado FROM dbo.pedido WHERE cod_pedido = @nuevo;

REVERT;

SELECT 'S3' AS prueba, cod_producto, stock FROM dbo.producto WHERE cod_producto = 2;

ROLLBACK TRANSACTION;
GO

-- S4. Lectura y escritura directa de producto. Esperado: error 229.
EXECUTE AS USER = 'usuario_aplicacion';

BEGIN TRY
    UPDATE dbo.producto SET stock = stock + 1 WHERE cod_producto = 2;
END TRY
BEGIN CATCH
    SELECT 'S4' AS prueba, ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;

REVERT;
GO

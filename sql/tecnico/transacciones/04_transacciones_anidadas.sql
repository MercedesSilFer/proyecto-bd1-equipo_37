-- =====================================================================
-- Etapa V - Transacciones anidadas y puntos de recuperación
-- SmartHome Store (equipo 37) - SQL Server
--
-- Conceptos que se demuestran (el contador @@TRANCOUNT es la clave):
--   1) COMMIT de una transacción interna no confirma nada: solo resta 1.
--   2) ROLLBACK (sin nombre de punto de recuperación) deshace TODO y deja
--      @@TRANCOUNT en 0, aunque haya transacciones internas.
--   3) SAVE TRANSACTION permite deshacer solo una parte.
--   4) Un procedimiento transaccional puede usarse dentro de otra transacción.
-- Las pruebas 1 a 3 usan la tabla categoria con nombres "DEMO-..." que se
-- eliminan al final. Requiere usp_registrar_venta (01_...) para la prueba 4.
-- =====================================================================
USE smarthome_store;
GO
SET NOCOUNT ON;

-- ---- 1) COMMIT interno + ROLLBACK externo ------------------------------
PRINT '--- 1) COMMIT interno + ROLLBACK externo';
PRINT 'Contador al inicio: ' + CAST(@@TRANCOUNT AS VARCHAR(3));            -- 0
BEGIN TRANSACTION externa;
    PRINT 'Después de BEGIN externa: ' + CAST(@@TRANCOUNT AS VARCHAR(3)); -- 1
    BEGIN TRANSACTION interna;
        PRINT 'Después de BEGIN interna: ' + CAST(@@TRANCOUNT AS VARCHAR(3)); -- 2
        INSERT INTO dbo.categoria (nombre) VALUES ('DEMO-ANIDADA-1');
    COMMIT TRANSACTION interna;
    PRINT 'Después de COMMIT interna: ' + CAST(@@TRANCOUNT AS VARCHAR(3)); -- 1 (todavía no es permanente)
ROLLBACK TRANSACTION externa;
PRINT 'Después de ROLLBACK externa: ' + CAST(@@TRANCOUNT AS VARCHAR(3));  -- 0
SELECT COUNT(*) AS filas_DEMO_ANIDADA_1_esperado_0
FROM dbo.categoria WHERE nombre = 'DEMO-ANIDADA-1';

-- ---- 2) ROLLBACK interno deshace todo ----------------------------------
PRINT '--- 2) ROLLBACK dentro de la transacción interna';
BEGIN TRANSACTION;
    BEGIN TRANSACTION;
        INSERT INTO dbo.categoria (nombre) VALUES ('DEMO-ANIDADA-2');
    ROLLBACK TRANSACTION;   -- deshace TODO, también la transacción externa
PRINT 'Contador después del ROLLBACK interno: ' + CAST(@@TRANCOUNT AS VARCHAR(3)); -- 0
SELECT COUNT(*) AS filas_DEMO_ANIDADA_2_esperado_0
FROM dbo.categoria WHERE nombre = 'DEMO-ANIDADA-2';

-- ---- 3) Punto de recuperación (SAVE TRANSACTION) -----------------------
PRINT '--- 3) Punto de recuperación';
BEGIN TRANSACTION;
    INSERT INTO dbo.categoria (nombre) VALUES ('DEMO-SP-A');
    SAVE TRANSACTION punto_1;
    INSERT INTO dbo.categoria (nombre) VALUES ('DEMO-SP-B');
    ROLLBACK TRANSACTION punto_1;   -- solo se deshace DEMO-SP-B
    PRINT 'Contador después de ROLLBACK al punto: ' + CAST(@@TRANCOUNT AS VARCHAR(3)); -- 1: la transacción sigue abierta
COMMIT TRANSACTION;
SELECT nombre, 'esperado: solo DEMO-SP-A' AS nota
FROM dbo.categoria WHERE nombre IN ('DEMO-SP-A', 'DEMO-SP-B');
GO

-- ---- 4) Procedimiento transaccional dentro de una transacción externa --
DECLARE @pedido INT;
DECLARE @stock_antes INT = (SELECT stock FROM dbo.producto WHERE cod_producto = 2);

PRINT '--- 4) usp_registrar_venta dentro de una transacción externa';
BEGIN TRANSACTION;
    EXEC dbo.usp_registrar_venta @cod_cliente = 1, @cod_metodo_pago = 1,
         @cod_producto = 2, @cantidad = 1, @cod_pedido = @pedido OUTPUT;
    SELECT 'Dentro de la transacción' AS momento, @pedido AS pedido_creado,
           (SELECT stock FROM dbo.producto WHERE cod_producto = 2) AS stock;

    -- Un error de negocio dentro del procedimiento revierte solo su parte
    BEGIN TRY
        EXEC dbo.usp_registrar_venta @cod_cliente = 1, @cod_metodo_pago = 1,
             @cod_producto = 2, @cantidad = 99999, @cod_pedido = @pedido OUTPUT;
    END TRY
    BEGIN CATCH
        PRINT 'Venta rechazada: ' + ERROR_MESSAGE();
    END CATCH;
    SELECT 'Tras la venta rechazada (la primera sigue vigente)' AS momento,
           @@TRANCOUNT AS contador, XACT_STATE() AS estado_transaccion;
ROLLBACK TRANSACTION;   -- el llamador decide descartar todo

SELECT 'Después del ROLLBACK externo' AS momento, @stock_antes AS stock_antes,
       (SELECT stock FROM dbo.producto WHERE cod_producto = 2) AS stock_despues;
GO

-- ---- Limpieza de las categorías de demostración ------------------------
DELETE FROM dbo.categoria WHERE nombre LIKE 'DEMO-%';
GO

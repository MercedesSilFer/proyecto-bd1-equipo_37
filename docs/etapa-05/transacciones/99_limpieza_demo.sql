-- Transacciones: limpieza de emergencia de los datos de demostracion
-- SmartHome Store (equipo 37) - SQL Server
--
-- Las pruebas T7 y T10 de scripts.sql ya eliminan sus propios datos. Este
-- script es una red de seguridad: sirve si una prueba se interrumpio a mitad
-- de camino y quedaron pedidos de prueba.
--
-- CUIDADO: elimina TODOS los pedidos con codigo >= @desde que no tengan
-- factura. Los pedidos originales de la carga inicial son 1 a 12, asi que
-- @desde = 13 solo alcanza a los creados despues. Ajustar si hace falta.
-- Devuelve al stock las unidades de los pedidos CONFIRMADOS que se borran
-- (un pedido pendiente no desconto stock y uno cancelado ya lo repuso).

USE smarthome_store;
GO
SET NOCOUNT ON;

DECLARE @desde INT = 13;

BEGIN TRY
    BEGIN TRANSACTION;

        -- Se devuelve el stock de los renglones que van a borrarse. Se suma
        -- por producto: un UPDATE ... FROM aplica una sola fila por producto,
        -- asi que si varios pedidos llevan el mismo producto hay que agruparlos.
        UPDATE p
        SET p.stock = p.stock + x.cantidad
        FROM dbo.producto p
        INNER JOIN (SELECT d.cod_producto, SUM(d.cantidad) AS cantidad
                    FROM dbo.detalle_pedido d
                    INNER JOIN dbo.pedido pe ON pe.cod_pedido = d.cod_pedido
                    WHERE pe.cod_pedido >= @desde
                      AND pe.estado = 'confirmado'
                      AND NOT EXISTS (SELECT 1 FROM dbo.factura f WHERE f.cod_pedido = pe.cod_pedido)
                    GROUP BY d.cod_producto) x ON x.cod_producto = p.cod_producto;

        -- El detalle se elimina en cascada con el pedido
        DELETE FROM dbo.pedido
        WHERE cod_pedido >= @desde
          AND NOT EXISTS (SELECT 1 FROM dbo.factura f WHERE f.cod_pedido = pedido.cod_pedido);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;

-- Esperado con la carga inicial: 12 pedidos y 18 detalles
SELECT (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas;
GO

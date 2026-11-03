-- =====================================================================
-- Etapa V - Transacciones: limpieza de los datos de demostración
-- Elimina los pedidos creados por las pruebas A y D de 03_pruebas_transaccion.sql
-- y restituye el stock descontado. AJUSTAR @desde al primer código de pedido
-- creado por las pruebas (los pedidos originales de la carga inicial son 1 a 12).
-- =====================================================================
USE smarthome_store;
GO
SET NOCOUNT ON;

DECLARE @desde INT = 13;

-- Se devuelve el stock de los renglones que van a borrarse
UPDATE p
SET p.stock = p.stock + d.cantidad
FROM dbo.producto p
JOIN dbo.detalle_pedido d ON d.cod_producto = p.cod_producto
WHERE d.cod_pedido >= @desde
  AND NOT EXISTS (SELECT 1 FROM dbo.factura f WHERE f.cod_pedido = d.cod_pedido);

-- El detalle se elimina en cascada con el pedido
DELETE FROM dbo.pedido
WHERE cod_pedido >= @desde
  AND NOT EXISTS (SELECT 1 FROM dbo.factura f WHERE f.cod_pedido = pedido.cod_pedido);

SELECT (SELECT COUNT(*) FROM dbo.pedido) AS pedidos,
       (SELECT COUNT(*) FROM dbo.detalle_pedido) AS lineas;
GO

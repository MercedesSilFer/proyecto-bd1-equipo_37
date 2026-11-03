
-- Funciones almacenadas definidas por el usuario
-- fn_precio_con_iva           (escalar)  RN.19 / RN.28
-- fn_stock_disponible         (escalar)  RN.09 / RN.11
-- fn_monto_pedido             (escalar)  RN.10 (el monto no se almacena)
-- fn_mayor_descuento_vigente  (escalar)  RN.23 / RN.24
-- fn_pedidos_cliente          (tabla en línea)  consulta parametrizada
--
-- Cada CREATE OR ALTER va en su propio lote (GO) porque la instrucción
-- debe ser la primera del lote.

USE smarthome_store;
GO

-- Precio final con IVA incluido = precio de lista neto x (1 + alícuota/100)
CREATE OR ALTER FUNCTION dbo.fn_precio_con_iva (@cod_producto INT)
RETURNS DECIMAL(12, 2)
AS
BEGIN
    RETURN (SELECT ROUND(p.precio_lista * (1 + a.porcentaje / 100.0), 2)
            FROM dbo.producto p
            INNER JOIN dbo.alicuota_iva a ON a.cod_alicuota = p.cod_alicuota
            WHERE p.cod_producto = @cod_producto);
END;
GO

-- Unidades disponibles; 0 si el producto no existe o está inactivo
CREATE OR ALTER FUNCTION dbo.fn_stock_disponible (@cod_producto INT)
RETURNS INT
AS
BEGIN
    RETURN ISNULL((SELECT stock
                   FROM dbo.producto
                   WHERE cod_producto = @cod_producto AND activo = 1), 0);
END;
GO

-- Monto de un pedido = suma de cantidad x precio unitario de venta
CREATE OR ALTER FUNCTION dbo.fn_monto_pedido (@cod_pedido INT)
RETURNS DECIMAL(12, 2)
AS
BEGIN
    RETURN ISNULL((SELECT SUM(d.cantidad * d.precio_unitario_venta)
                   FROM dbo.detalle_pedido d
                   WHERE d.cod_pedido = @cod_pedido), 0);
END;
GO

-- Mayor porcentaje de descuento de las promociones vigentes en @fecha
-- (RN.24: si hay varias vigentes se aplica la de mayor descuento).
-- Una promoción solo en cuotas no tiene porcentaje: aporta 0.
CREATE OR ALTER FUNCTION dbo.fn_mayor_descuento_vigente (@cod_producto INT, @fecha DATETIME)
RETURNS DECIMAL(5, 2)
AS
BEGIN
    RETURN ISNULL((SELECT MAX(pm.porcentaje_descuento)
                   FROM dbo.promocion pm
                   INNER JOIN dbo.promocion_producto pp ON pp.cod_promocion = pm.cod_promocion
                   WHERE pp.cod_producto = @cod_producto
                     AND @fecha BETWEEN pm.fecha_inicio AND pm.fecha_fin), 0);
END;
GO

-- Pedidos de un cliente con su monto (función de tabla en línea)
CREATE OR ALTER FUNCTION dbo.fn_pedidos_cliente (@cod_cliente INT)
RETURNS TABLE
AS
RETURN
(
    SELECT p.cod_pedido,
           p.fecha_pedido,
           p.estado,
           p.estado_pago,
           ISNULL(SUM(d.cantidad * d.precio_unitario_venta), 0) AS monto
    FROM dbo.pedido p
    LEFT JOIN dbo.detalle_pedido d ON d.cod_pedido = p.cod_pedido
    WHERE p.cod_cliente = @cod_cliente
    GROUP BY p.cod_pedido, p.fecha_pedido, p.estado, p.estado_pago
);--Con LEFT JOIN, un pedido inconsistente aparece con monto 0.
GO

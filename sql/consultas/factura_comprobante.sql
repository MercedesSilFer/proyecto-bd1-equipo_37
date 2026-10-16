--Factura / Comprobante de venta

-- Consolida el encabezado y el detalle de la factura de un pedido.
-- Cambiar @cod_pedido por el pedido a consultar (ej. 1, 3, 8).
-- precio_unitario_venta incluye IVA; iva_monto es el IVA total del renglon.

USE smarthome_store;
GO

DECLARE @cod_pedido INT = 4;

--   1  Encabezado del comprobante
--      Datos fiscales de la factura, datos del cliente y del pedido, y totales.
--      Tablas: factura, pedido, cliente, metodo_pago, usuario
--      Tecnica: INNER JOIN de 5 tablas + subconsulta escalar que recalcula el total
--      desde el detalle para controlar que coincida con el total registrado.
-- ---------------------------------------------------------------
SELECT
    f.tipo_comprobante,
    RIGHT('0000'     + CAST(f.punto_venta AS VARCHAR(4)), 4) + '-' +
    RIGHT('00000000' + CAST(f.numero      AS VARCHAR(8)), 8)  AS nro_comprobante,
    f.fecha_emision, f.cae, f.fecha_vto_cae,
    c.nombre + ' ' + c.apellido                               AS cliente,
    f.razon_social, f.cond_iva_cliente, f.tipo_documento_cliente, f.nro_documento_cliente,
    p.calle + ' ' + p.numero + ', ' + p.ciudad + ', ' + p.provincia
        + ' (' + p.cod_postal + ')'                           AS domicilio_entrega,
    p.cod_pedido, p.fecha_pedido, mp.nombre                   AS metodo_pago,
    u.nombre_usuario                                          AS emitida_por,
    f.subtotal, f.iva_total, f.total,
    (SELECT SUM(dp.cantidad * dp.precio_unitario_venta)
     FROM detalle_pedido dp
     WHERE dp.cod_pedido = p.cod_pedido)                      AS total_calculado
FROM factura f
INNER JOIN pedido      p  ON p.cod_pedido       = f.cod_pedido
INNER JOIN cliente     c  ON c.cod_cliente      = p.cod_cliente
INNER JOIN metodo_pago mp ON mp.cod_metodo_pago = p.cod_metodo_pago
INNER JOIN usuario     u  ON u.cod_usuario      = f.cod_usuario
WHERE f.cod_pedido = @cod_pedido;

--   2  Detalle del comprobante
--      Un renglon por producto con subtotal, neto e IVA, y el total acumulado
--      renglon a renglon hasta llegar al total de la factura.
--      Tablas: factura, detalle_pedido, producto
--      Tecnica: INNER JOIN + columnas calculadas + SUM() OVER (ORDER BY item)
--      para el total acumulado.
-- ---------------------------------------------------------------
SELECT
    dp.item,
    pr.cod_producto,
    pr.nombre                                                 AS producto,
    dp.cantidad,
    dp.precio_unitario_venta,
    dp.alicuota_iva,
    dp.cantidad * dp.precio_unitario_venta                    AS subtotal_renglon,
    dp.cantidad * dp.precio_unitario_venta - dp.iva_monto     AS neto_renglon,
    dp.iva_monto                                              AS iva_renglon,
    SUM(dp.cantidad * dp.precio_unitario_venta)
        OVER (ORDER BY dp.item ROWS UNBOUNDED PRECEDING)      AS total_acumulado
FROM factura f
INNER JOIN detalle_pedido dp ON dp.cod_pedido   = f.cod_pedido
INNER JOIN producto       pr ON pr.cod_producto = dp.cod_producto
WHERE f.cod_pedido = @cod_pedido
ORDER BY dp.item;
GO

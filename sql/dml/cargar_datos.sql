-- =============================================================
-- DML: carga de datos de prueba – SmartHome Store (equipo 37)
-- Ejecutar DESPUÉS de sql/ddl/crear_bd.sql, sobre la base recién creada.
-- Los códigos se cargan explícitos (IDENTITY_INSERT) para que las FK
-- sean predecibles. Guardado en UTF-8 con BOM (acentos).
-- Excepción: alicuota_iva tiene 6 registros, que son todas las
-- alícuotas vigentes en Argentina.
-- =============================================================
USE smarthome_store;
GO

SET IDENTITY_INSERT cliente ON;
INSERT INTO cliente (cod_cliente, nombre, apellido, email, contrasena_hash, calle, numero, ciudad, provincia, cod_postal, fecha_registro, telefono) VALUES
(1, 'Lucía', 'Gómez', 'lucia.gomez@gmail.com', '$2b$12$luciagomezluciagomezluhashDePrueba0000000000000', 'Junín', '1234', 'Corrientes', 'CORRIENTES', '3400', '2026-03-10', '3794123456'),
(2, 'Martín', 'Romero', 'martin.romero@hotmail.com', '$2b$12$martinromeromartinromehashDePrueba0000000000000', 'Av. 3 de Abril', '850', 'Corrientes', 'CORRIENTES', '3400', '2026-04-02', '3794556677'),
(3, 'Sofía', 'Acosta', 'sofia.acosta@yahoo.com.ar', '$2b$12$sofiaacostasofiaacostahashDePrueba0000000000000', 'Av. Sarmiento', '560', 'Resistencia', 'CHACO', '3500', '2026-04-18', '3624332211'),
(4, 'Tomás', 'Benítez', 'tomas.benitez@gmail.com', '$2b$12$tomasbeniteztomasbenithashDePrueba0000000000000', 'Av. Mitre', '2100', 'Posadas', 'MISIONES', '3300', '2026-05-05', '3764445566'),
(5, 'Valentina', 'Díaz', 'valen.diaz@outlook.com', '$2b$12$valendiazvalendiazvalehashDePrueba0000000000000', 'Av. Corrientes', '3456', 'Buenos Aires', 'CIUDAD AUTÓNOMA DE BUENOS AIRES', '1193', '2026-05-20', '1145678901'),
(6, 'Joaquín', 'Fernández', 'joaquin.fernandez@gmail.com', '$2b$12$joaquinfernandezjoaquihashDePrueba0000000000000', 'Bv. Pellegrini', '1500', 'Santa Fe', 'SANTA FE', '3000', '2026-06-01', '3424123123'),
(7, 'Camila', 'Ortiz', 'camila.ortiz@gmail.com', '$2b$12$camilaortizcamilaortizhashDePrueba0000000000000', 'Av. Colón', '980', 'Córdoba', 'CÓRDOBA', '5000', '2026-06-14', '3514789456'),
(8, 'Nicolás', 'Vera', 'nicolas.vera@hotmail.com', '$2b$12$nicolasveranicolasverahashDePrueba0000000000000', '9 de Julio', '745', 'Formosa', 'FORMOSA', '3600', '2026-07-03', '3704112233'),
(9, 'Agustina', 'Ríos', 'agustina.rios@gmail.com', '$2b$12$agustinariosagustinarihashDePrueba0000000000000', 'Av. Belgrano', '1320', 'Salta', 'SALTA', '4400', '2026-07-22', '3874998877'),
(10, 'Federico', 'Molina', 'fede.molina@gmail.com', '$2b$12$fedemolinafedemolinafehashDePrueba0000000000000', 'San Martín', '415', 'Mendoza', 'MENDOZA', '5500', '2026-08-09', '2614556677');
SET IDENTITY_INSERT cliente OFF;
GO

SET IDENTITY_INSERT usuario ON;
INSERT INTO usuario (cod_usuario, nombre_usuario, contrasena_hash, rol) VALUES
(1, 'mgonzalez', '$2b$12$mgonzalezmgonzalezmgonhashDePrueba0000000000000', 'ADMINISTRADOR'),
(2, 'jperez', '$2b$12$jperezjperezjperezjperhashDePrueba0000000000000', 'ADMINISTRADOR'),
(3, 'lramirez', '$2b$12$lramirezlramirezlramirhashDePrueba0000000000000', 'DEPOSITO'),
(4, 'afernandez', '$2b$12$afernandezafernandezafhashDePrueba0000000000000', 'DEPOSITO'),
(5, 'csosa', '$2b$12$csosacsosacsosacsosacshashDePrueba0000000000000', 'DEPOSITO'),
(6, 'mbenitez', '$2b$12$mbenitezmbenitezmbenithashDePrueba0000000000000', 'SOPORTE'),
(7, 'dacosta', '$2b$12$dacostadacostadacostadhashDePrueba0000000000000', 'SOPORTE'),
(8, 'rmolina', '$2b$12$rmolinarmolinarmolinarhashDePrueba0000000000000', 'DEPOSITO'),
(9, 'vlopez', '$2b$12$vlopezvlopezvlopezvlophashDePrueba0000000000000', 'ADMINISTRADOR'),
(10, 'nsilva', '$2b$12$nsilvansilvansilvansilhashDePrueba0000000000000', 'SOPORTE');
SET IDENTITY_INSERT usuario OFF;
GO

SET IDENTITY_INSERT categoria ON;
INSERT INTO categoria (cod_categoria, nombre, cod_categoria_padre) VALUES
(1, 'Electrónica', NULL),
(2, 'Electrodomésticos', NULL),
(3, 'Accesorios', NULL),
(4, 'Informática', NULL),
(5, 'Celulares', NULL);
SET IDENTITY_INSERT categoria OFF;
GO

SET IDENTITY_INSERT categoria ON;
INSERT INTO categoria (cod_categoria, nombre, cod_categoria_padre) VALUES
(6, 'Televisores', 1),
(7, 'Audio', 1),
(8, 'Línea blanca', 2),
(9, 'Pequeños electrodomésticos', 2),
(10, 'Notebooks', 4);
SET IDENTITY_INSERT categoria OFF;
GO

INSERT INTO alicuota_iva (cod_alicuota, nombre, porcentaje) VALUES
(3, 'Cero', 0.00),
(9, 'Mínima', 2.50),
(8, 'Especial', 5.00),
(4, 'Reducida', 10.50),
(5, 'General', 21.00),
(6, 'Incrementada', 27.00);
GO

SET IDENTITY_INSERT producto ON;
INSERT INTO producto (cod_producto, nombre, descripcion, precio_lista, cod_alicuota, stock, cod_categoria) VALUES
(1, 'Smart TV 50"', 'Televisor LED 4K UHD de 50 pulgadas con sistema Smart, WiFi y Bluetooth.', 289256.20, 5, 12, 6),
(2, 'Auriculares BT', 'Auriculares inalámbricos over-ear con cancelación de ruido y micrófono.', 20661.16, 5, 40, 7),
(3, 'Heladera 300L', 'Heladera no frost de 300 litros con freezer superior.', 396694.21, 5, 6, 8),
(4, 'Funda Notebook', 'Funda acolchada para notebooks de hasta 15.6 pulgadas.', 6611.57, 5, 30, 3),
(5, 'Notebook 15.6" Core i5', 'Notebook con procesador Core i5, 16GB de RAM y SSD de 512GB.', 769230.77, 4, 8, 10),
(6, 'Celular 128GB', 'Smartphone de 6.5 pulgadas con 128GB de almacenamiento y cámara triple.', 413223.14, 5, 20, 5),
(7, 'Impresora multifunción', 'Impresora, escáner y copiadora con sistema de tinta continua y WiFi.', 185950.41, 5, 10, 4),
(8, 'Lavarropas automático 8kg', 'Lavarropas de carga frontal de 8kg con 15 programas de lavado.', 520661.16, 5, 5, 8),
(9, 'Microondas 25L', 'Microondas digital de 25 litros con grill y 10 niveles de potencia.', 140495.87, 5, 15, 9),
(10, 'Parlante BT portátil', 'Parlante portátil resistente al agua con 12 horas de autonomía.', 45454.55, 5, 25, 7);
SET IDENTITY_INSERT producto OFF;
GO

SET IDENTITY_INSERT proveedor ON;
INSERT INTO proveedor (cod_proveedor, razon_social, cuit, calle, numero, ciudad, provincia) VALUES
(1, 'Distribuidora Litoral S.A.', '30-71234567-8', 'Av. Maipú', '2200', 'Corrientes', 'CORRIENTES'),
(2, 'Tecnología del Norte S.R.L.', '30-70987654-3', 'Av. Alberdi', '1450', 'Resistencia', 'CHACO'),
(3, 'ElectroMayorista S.A.', '30-68765432-1', 'Av. Rivadavia', '8900', 'Buenos Aires', 'CIUDAD AUTÓNOMA DE BUENOS AIRES'),
(4, 'Frío Hogar S.A.', '30-71111222-5', 'Ruta 9 Km 695', 'S/N', 'Córdoba', 'CÓRDOBA'),
(5, 'Audio Pro Importaciones S.R.L.', '30-71555666-9', 'Av. San Martín', '3100', 'Rosario', 'SANTA FE'),
(6, 'Informática Central S.A.', '30-70444555-2', 'Av. Callao', '1020', 'Buenos Aires', 'CIUDAD AUTÓNOMA DE BUENOS AIRES'),
(7, 'Mobile World S.A.', '30-71888999-4', 'Av. Colón', '5200', 'Córdoba', 'CÓRDOBA'),
(8, 'Accesorios Tech S.R.L.', '30-71222333-6', 'Av. Uruguay', '1780', 'Posadas', 'MISIONES'),
(9, 'Línea Blanca Argentina S.A.', '30-69333444-7', 'Av. Belgrano', '4300', 'Buenos Aires', 'BUENOS AIRES'),
(10, 'Distribuidora Andina S.R.L.', '30-71777888-0', 'Av. Las Heras', '650', 'Mendoza', 'MENDOZA');
SET IDENTITY_INSERT proveedor OFF;
GO

SET IDENTITY_INSERT metodo_pago ON;
INSERT INTO metodo_pago (cod_metodo_pago, nombre) VALUES
(1, 'Tarjeta de crédito'),
(2, 'Tarjeta de débito'),
(3, 'Mercado Pago'),
(4, 'Transferencia bancaria'),
(5, 'MODO'),
(6, 'Cuenta DNI'),
(7, 'Naranja X'),
(8, 'Ualá'),
(9, 'Pago Fácil'),
(10, 'Rapipago');
SET IDENTITY_INSERT metodo_pago OFF;
GO

SET IDENTITY_INSERT pedido ON;
INSERT INTO pedido (cod_pedido, fecha_pedido, estado, estado_pago, ref_transaccion, calle, numero, ciudad, provincia, cod_postal, estado_envio, fecha_envio, transportista, fecha_entrega, nro_seguimiento, cod_cliente, cod_metodo_pago, cod_usuario) VALUES
(1, '2026-05-12T10:15:00', 'confirmado', 'aprobado', 'MP-88120451', 'Junín', '1234', 'Corrientes', 'CORRIENTES', '3400', 'entregado', '2026-05-13T09:00:00', 'Andreani', '2026-05-16', 'AND-000451201', 1, 3, 3),
(2, '2026-06-15T18:40:00', 'confirmado', 'aprobado', 'VISA-5521889', 'Av. 3 de Abril', '850', 'Corrientes', 'CORRIENTES', '3400', 'entregado', '2026-06-16T11:30:00', 'Correo Argentino', '2026-06-20', 'CA-783451120AR', 2, 1, 4),
(3, '2026-07-03T09:05:00', 'confirmado', 'aprobado', 'TRF-20260703-01', 'Av. Sarmiento', '560', 'Resistencia', 'CHACO', '3500', 'entregado', '2026-07-04T10:00:00', 'OCA', '2026-07-08', 'OCA-3345120', 3, 4, 3),
(4, '2026-07-20T21:10:00', 'confirmado', 'aprobado', 'MODO-7781230', 'Av. Mitre', '2100', 'Posadas', 'MISIONES', '3300', 'entregado', '2026-07-21T14:00:00', 'Andreani', '2026-07-25', 'AND-000458890', 4, 5, 5),
(5, '2026-08-02T16:25:00', 'confirmado', 'aprobado', 'VISA-5530117', 'Av. Corrientes', '3456', 'Buenos Aires', 'CIUDAD AUTÓNOMA DE BUENOS AIRES', '1193', 'entregado', '2026-08-03T09:45:00', 'Andreani', '2026-08-06', 'AND-000461377', 5, 1, 8),
(6, '2026-08-18T12:00:00', 'confirmado', 'aprobado', 'MP-88341209', 'Bv. Pellegrini', '1500', 'Santa Fe', 'SANTA FE', '3000', 'entregado', '2026-08-19T10:20:00', 'Correo Argentino', '2026-08-24', 'CA-790112345AR', 6, 3, 4),
(7, '2026-09-05T19:30:00', 'confirmado', 'aprobado', 'DEB-4410982', 'Av. Colón', '980', 'Córdoba', 'CÓRDOBA', '5000', 'entregado', '2026-09-07T09:00:00', 'OCA', '2026-09-11', 'OCA-3399871', 7, 2, 5),
(8, '2026-09-18T11:45:00', 'confirmado', 'aprobado', 'MP-88502217', '9 de Julio', '745', 'Formosa', 'FORMOSA', '3600', 'despachado', '2026-09-19T15:00:00', 'Andreani', NULL, 'AND-000470012', 8, 3, 3),
(9, '2026-09-26T20:15:00', 'confirmado', 'aprobado', 'NX-3341190', 'Av. Belgrano', '1320', 'Salta', 'SALTA', '4400', 'pendiente', NULL, NULL, NULL, NULL, 9, 7, NULL),
(10, '2026-09-27T13:05:00', 'pendiente', 'pendiente', NULL, 'San Martín', '415', 'Mendoza', 'MENDOZA', '5500', NULL, NULL, NULL, NULL, NULL, 10, 9, NULL),
(11, '2026-09-28T17:50:00', 'cancelado', 'rechazado', NULL, 'Junín', '1234', 'Corrientes', 'CORRIENTES', '3400', NULL, NULL, NULL, NULL, NULL, 1, 1, NULL),
(12, '2026-09-29T10:40:00', 'confirmado', 'aprobado', 'UALA-9981204', 'Av. 3 de Abril', '850', 'Corrientes', 'CORRIENTES', '3400', 'pendiente', NULL, NULL, NULL, NULL, 2, 8, NULL);
SET IDENTITY_INSERT pedido OFF;
GO

SET IDENTITY_INSERT compra ON;
INSERT INTO compra (cod_compra, fecha, estado, nro_comprobante_prov, cod_proveedor, cod_usuario) VALUES
(1, '2026-03-02T09:00:00', 'recibida', '0001-00012345', 3, 3),
(2, '2026-03-15T10:30:00', 'recibida', '0003-00004521', 9, 4),
(3, '2026-04-01T11:00:00', 'recibida', '0002-00087410', 5, 5),
(4, '2026-04-20T09:15:00', 'recibida', '0005-00001298', 6, 3),
(5, '2026-05-06T14:00:00', 'recibida', '0001-00033412', 8, 8),
(6, '2026-06-03T10:00:00', 'recibida', '0004-00005567', 4, 4),
(7, '2026-07-10T09:30:00', 'recibida', '0001-00012987', 7, 5),
(8, '2026-08-12T15:20:00', 'recibida', '0002-00091234', 5, 3),
(9, '2026-09-22T10:10:00', 'pendiente', NULL, 1, 8),
(10, '2026-09-25T16:45:00', 'cancelada', '0010-00000451', 10, 4);
SET IDENTITY_INSERT compra OFF;
GO

SET IDENTITY_INSERT auditoria ON;
INSERT INTO auditoria (cod_auditoria, entidad, operacion, registro_id, fecha, valor_anterior, valor_nuevo, cod_usuario) VALUES
(1, 'producto', 'UPDATE', 1, '2026-04-05T10:00:00', 'precio_lista=275000.00', 'precio_lista=289256.20', 1),
(2, 'producto', 'UPDATE', 6, '2026-04-05T10:05:00', 'precio_lista=398000.00', 'precio_lista=413223.14', 1),
(3, 'compra', 'UPDATE', 1, '2026-03-04T09:30:00', 'estado=pendiente', 'estado=recibida', 3),
(4, 'producto', 'UPDATE', 3, '2026-03-17T11:00:00', 'stock=0', 'stock=8', 4),
(5, 'pedido', 'UPDATE', 1, '2026-05-13T09:00:00', 'estado_envio=pendiente', 'estado_envio=despachado', 3),
(6, 'factura', 'INSERT', 1, '2026-05-12T10:20:00', NULL, 'factura B 1 total=245000.00', 1),
(7, 'pedido', 'UPDATE', 11, '2026-09-28T18:00:00', 'estado=pendiente', 'estado=cancelado', 9),
(8, 'compra', 'UPDATE', 10, '2026-09-26T09:00:00', 'estado=pendiente', 'estado=cancelada', 4),
(9, 'producto', 'UPDATE', 9, '2026-06-04T10:00:00', 'stock=0', 'stock=20', 4),
(10, 'promocion', 'INSERT', 4, '2026-09-14T17:30:00', NULL, 'Liquidación Accesorios 35%', 2);
SET IDENTITY_INSERT auditoria OFF;
GO

SET IDENTITY_INSERT factura ON;
INSERT INTO factura (cod_factura, tipo_comprobante, numero, fecha_emision, cond_iva_cliente, subtotal, iva_total, total, cae, fecha_vto_cae, tipo_documento_cliente, nro_documento_cliente, razon_social, punto_venta, cod_pedido, cod_usuario) VALUES
(1, 'B', 1, '2026-05-12', 'Consumidor Final', 202479.34, 42520.66, 245000.00, '75432100000013', '2026-05-22', 'DNI', '38456123', NULL, 1, 1, 1),
(2, 'B', 2, '2026-06-15', 'Consumidor Final', 73760.33, 15489.67, 89250.00, '75432100000027', '2026-06-25', 'DNI', '35123987', NULL, 1, 2, 2),
(3, 'A', 3, '2026-07-03', 'Responsable Inscripto', 396694.21, 83305.78, 479999.99, '75432100000041', '2026-07-13', 'CUIT', '27-31456789-4', 'Sofía Acosta', 1, 3, 9),
(4, 'B', 4, '2026-07-20', 'Consumidor Final', 775842.34, 82157.66, 858000.00, '75432100000054', '2026-07-30', 'DNI', '40221334', NULL, 1, 4, 1),
(5, 'B', 5, '2026-08-02', 'Consumidor Final', 413223.14, 86776.86, 500000.00, '75432100000068', '2026-08-12', 'DNI', '37888456', NULL, 1, 5, 2),
(6, 'A', 6, '2026-08-18', 'Responsable Inscripto', 206611.57, 43388.43, 250000.00, '75432100000082', '2026-08-28', 'CUIT', '20-29876543-1', 'Joaquín Fernández', 1, 6, 9),
(7, 'B', 7, '2026-09-05', 'Consumidor Final', 520661.16, 109338.84, 630000.00, '75432100000095', '2026-09-15', 'DNI', '39554120', NULL, 1, 7, 1),
(8, 'B', 8, '2026-09-18', 'Consumidor Final', 149090.91, 31309.09, 180400.00, '75432100000109', '2026-09-28', 'DNI', '36112789', NULL, 1, 8, 2),
(9, 'B', 9, '2026-09-26', 'Consumidor Final', 334710.75, 70289.26, 405000.01, '75432100000123', '2026-10-06', 'DNI', '41223556', NULL, 1, 9, 9),
(10, 'B', 10, '2026-09-29', 'Consumidor Final', 24958.68, 5241.32, 30200.00, '75432100000164', '2026-10-09', 'DNI', '35123987', NULL, 1, 12, 1);
SET IDENTITY_INSERT factura OFF;
GO

INSERT INTO detalle_compra (cod_compra, cod_producto, cantidad, costo_unitario) VALUES
(1, 1, 10, 210000.00),
(1, 6, 15, 300000.00),
(2, 3, 8, 285000.00),
(2, 8, 6, 380000.00),
(3, 2, 50, 14500.00),
(3, 10, 30, 32000.00),
(4, 5, 10, 560000.00),
(4, 7, 12, 130000.00),
(5, 4, 40, 4200.00),
(6, 3, 4, 290000.00),
(6, 9, 20, 98000.00),
(7, 6, 10, 305000.00),
(8, 2, 20, 14800.00),
(8, 10, 10, 32500.00),
(9, 1, 5, 215000.00),
(9, 9, 5, 99500.00),
(10, 8, 3, 385000.00);
GO

INSERT INTO detalle_pedido (cod_pedido, cod_producto, item, cantidad, precio_unitario_venta, alicuota_iva, iva_monto) VALUES
(1, 1, 1, 1, 245000.00, 21.00, 42520.66),  -- descuento 30.00 % por promoción
(2, 2, 1, 2, 21250.00, 21.00, 7376.03),  -- descuento 15.00 % por promoción
(2, 10, 2, 1, 46750.00, 21.00, 8113.64),  -- descuento 15.00 % por promoción
(3, 3, 1, 1, 479999.99, 21.00, 83305.78),
(4, 5, 1, 1, 850000.00, 10.50, 80769.23),
(4, 4, 2, 1, 8000.00, 21.00, 1388.43),
(5, 6, 1, 1, 500000.00, 21.00, 86776.86),
(6, 7, 1, 1, 225000.00, 21.00, 39049.59),
(6, 2, 2, 1, 25000.00, 21.00, 4338.84),
(7, 8, 1, 1, 630000.00, 21.00, 109338.84),
(8, 4, 1, 2, 5200.00, 21.00, 1804.96),  -- descuento 35.00 % por promoción
(8, 9, 2, 1, 170000.00, 21.00, 29504.13),
(9, 1, 1, 1, 350000.00, 21.00, 60743.80),
(9, 10, 2, 1, 55000.01, 21.00, 9545.46),
(10, 9, 1, 1, 170000.00, 21.00, 29504.13),
(11, 6, 1, 1, 500000.00, 21.00, 86776.86),
(12, 2, 1, 1, 25000.00, 21.00, 4338.84),
(12, 4, 2, 1, 5200.00, 21.00, 902.48);  -- descuento 35.00 % por promoción
GO

SET IDENTITY_INSERT promocion ON;
INSERT INTO promocion (cod_promocion, nombre, descripcion, fecha_inicio, fecha_fin, porcentaje_descuento, nro_cuotas) VALUES
(1, 'Hot Sale 2026', 'Descuentos exclusivos en tecnología durante el Hot Sale.', '2026-05-11T00:00:00', '2026-05-13T23:59:59', 30.00, NULL),
(2, 'Día del Padre', 'Regalos tecnológicos para papá con descuento.', '2026-06-08T00:00:00', '2026-06-21T23:59:59', 15.00, NULL),
(3, 'Línea Blanca en cuotas', 'Electrodomésticos en 12 cuotas sin interés.', '2026-09-01T00:00:00', '2026-12-31T23:59:59', NULL, 12),
(4, 'Liquidación Accesorios', 'Accesorios con gran descuento hasta agotar stock.', '2026-09-15T00:00:00', '2026-10-15T23:59:59', 35.00, NULL),
(5, 'Día de la Madre', 'Descuento y cuotas sin interés para el Día de la Madre.', '2026-10-05T00:00:00', '2026-10-18T23:59:59', 15.00, 6),
(6, 'Semana del Audio', 'Auriculares y parlantes con descuento y cuotas.', '2026-10-20T00:00:00', '2026-10-27T23:59:59', 18.00, 6),
(7, 'Semana Cyber', 'Ofertas online en informática y celulares.', '2026-11-02T00:00:00', '2026-11-04T23:59:59', 20.00, NULL),
(8, 'Black Friday', 'Los mejores descuentos del año en toda la tienda.', '2026-11-27T00:00:00', '2026-11-30T23:59:59', 25.00, NULL),
(9, 'Navidad Tecno', 'Regalos de Navidad con descuento y 12 cuotas sin interés.', '2026-12-01T00:00:00', '2026-12-24T23:59:59', 10.00, 12),
(10, 'Vuelta a Clases 2027', 'Notebooks, impresoras y accesorios para el inicio de clases.', '2027-02-15T00:00:00', '2027-03-10T23:59:59', 10.00, 3);
SET IDENTITY_INSERT promocion OFF;
GO

INSERT INTO promocion_producto (cod_promocion, cod_producto) VALUES
(1, 1),
(1, 6),
(2, 2),
(2, 10),
(3, 3),
(3, 8),
(3, 9),
(4, 4),
(5, 9),
(6, 2),
(6, 10),
(7, 5),
(8, 1),
(9, 5),
(9, 6),
(10, 7);
GO

SET IDENTITY_INSERT slide ON;
INSERT INTO slide (cod_slide, url, cod_promocion) VALUES
(1, 'https://cdn.smarthomestore.com.ar/slides/hot-sale-2026.webp', 1),
(2, 'https://cdn.smarthomestore.com.ar/slides/dia-del-padre-2026.webp', 2),
(3, 'https://cdn.smarthomestore.com.ar/slides/linea-blanca-12-cuotas.webp', 3),
(4, 'https://cdn.smarthomestore.com.ar/slides/linea-blanca-mobile.webp', 3),
(5, 'https://cdn.smarthomestore.com.ar/slides/liquidacion-accesorios.webp', 4),
(6, 'https://cdn.smarthomestore.com.ar/slides/dia-de-la-madre-2026.webp', 5),
(7, 'https://cdn.smarthomestore.com.ar/slides/semana-del-audio.webp', 6),
(8, 'https://cdn.smarthomestore.com.ar/slides/semana-cyber-2026.webp', 7),
(9, 'https://cdn.smarthomestore.com.ar/slides/black-friday-2026.webp', 8),
(10, 'https://cdn.smarthomestore.com.ar/slides/navidad-tecno-2026.webp', 9);
SET IDENTITY_INSERT slide OFF;
GO

SET IDENTITY_INSERT multimedia ON;
INSERT INTO multimedia (cod_multimedia, url, tipo, cod_producto) VALUES
(1, 'https://cdn.smarthomestore.com.ar/productos/1/frente.jpg', 'imagen', 1),
(2, 'https://cdn.smarthomestore.com.ar/productos/1/lateral.jpg', 'imagen', 1),
(3, 'https://cdn.smarthomestore.com.ar/productos/1/demo.mp4', 'video', 1),
(4, 'https://cdn.smarthomestore.com.ar/productos/2/frente.jpg', 'imagen', 2),
(5, 'https://cdn.smarthomestore.com.ar/productos/3/frente.jpg', 'imagen', 3),
(6, 'https://cdn.smarthomestore.com.ar/productos/3/interior.jpg', 'imagen', 3),
(7, 'https://cdn.smarthomestore.com.ar/productos/4/frente.jpg', 'imagen', 4),
(8, 'https://cdn.smarthomestore.com.ar/productos/5/frente.jpg', 'imagen', 5),
(9, 'https://cdn.smarthomestore.com.ar/productos/6/frente.jpg', 'imagen', 6),
(10, 'https://cdn.smarthomestore.com.ar/productos/7/frente.jpg', 'imagen', 7),
(11, 'https://cdn.smarthomestore.com.ar/productos/8/frente.jpg', 'imagen', 8),
(12, 'https://cdn.smarthomestore.com.ar/productos/10/frente.jpg', 'imagen', 10);
SET IDENTITY_INSERT multimedia OFF;
GO

SET IDENTITY_INSERT especificacion ON;
INSERT INTO especificacion (cod_especificacion, nombre) VALUES
(1, 'Tamaño de pantalla'),
(2, 'Resolución'),
(3, 'Capacidad'),
(4, 'Memoria RAM'),
(5, 'Almacenamiento'),
(6, 'Conectividad'),
(7, 'Autonomía de batería'),
(8, 'Eficiencia energética'),
(9, 'Garantía'),
(10, 'Color');
SET IDENTITY_INSERT especificacion OFF;
GO

INSERT INTO especificacion_producto (cod_producto, cod_especificacion, valor) VALUES
(1, 1, '50 pulgadas'),
(1, 2, '4K UHD (3840 x 2160)'),
(1, 6, 'WiFi, Bluetooth, 3 HDMI'),
(2, 6, 'Bluetooth 5.3'),
(2, 7, '30 horas'),
(3, 3, '300 litros'),
(3, 8, 'A'),
(4, 10, 'Negro'),
(5, 1, '15.6 pulgadas'),
(5, 4, '16 GB'),
(5, 5, 'SSD 512 GB'),
(6, 5, '128 GB'),
(7, 6, 'WiFi, USB'),
(8, 3, '8 kg'),
(9, 3, '25 litros'),
(10, 9, '12 meses');
GO

SELECT 'alicuota_iva' AS tabla, COUNT(*) AS registros FROM alicuota_iva
UNION ALL SELECT 'categoria', COUNT(*) FROM categoria
UNION ALL SELECT 'usuario', COUNT(*) FROM usuario
UNION ALL SELECT 'cliente', COUNT(*) FROM cliente
UNION ALL SELECT 'proveedor', COUNT(*) FROM proveedor
UNION ALL SELECT 'metodo_pago', COUNT(*) FROM metodo_pago
UNION ALL SELECT 'producto', COUNT(*) FROM producto
UNION ALL SELECT 'compra', COUNT(*) FROM compra
UNION ALL SELECT 'detalle_compra', COUNT(*) FROM detalle_compra
UNION ALL SELECT 'pedido', COUNT(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido
UNION ALL SELECT 'factura', COUNT(*) FROM factura
UNION ALL SELECT 'auditoria', COUNT(*) FROM auditoria
UNION ALL SELECT 'promocion', COUNT(*) FROM promocion
UNION ALL SELECT 'promocion_producto', COUNT(*) FROM promocion_producto
UNION ALL SELECT 'slide', COUNT(*) FROM slide
UNION ALL SELECT 'multimedia', COUNT(*) FROM multimedia
UNION ALL SELECT 'especificacion', COUNT(*) FROM especificacion
UNION ALL SELECT 'especificacion_producto', COUNT(*) FROM especificacion_producto
;
GO

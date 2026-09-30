CREATE DATABASE smarthome_store;
GO
USE smarthome_store;
GO
CREATE TABLE cliente
(
  cod_cliente INT IDENTITY CONSTRAINT PK_cliente PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL,
  apellido VARCHAR(50) NOT NULL,
  email VARCHAR(100) NOT NULL,
  contrasena_hash VARCHAR(255) NOT NULL,
  calle VARCHAR(50) NOT NULL,
  numero VARCHAR(10) NOT NULL,
  ciudad VARCHAR(50) NOT NULL,
  provincia VARCHAR(50) NOT NULL,
  cod_postal VARCHAR(10) NOT NULL,
  fecha_registro DATE NOT NULL,
  activo BIT NOT NULL,
  telefono VARCHAR (20) NOT NULL,
  CONSTRAINT UQ_cliente_email UNIQUE (email),
  CONSTRAINT DF_cliente_activo DEFAULT 1 FOR activo,
  CONSTRAINT CK_cliente_estado CHECK(activo IN (0,1)),
  CONSTRAINT CK_cliente_email CHECK (email LIKE '%_@__%.__%'),
  CONSTRAINT DF_cliente_fecha_registro DEFAULT CAST(GETDATE() AS DATE) FOR fecha_registro,
  CONSTRAINT CK_cliente_provincia CHECK (UPPER(provincia) IN ('BUENOS AIRES', 'CATAMARCA', 'CHACO', 'CHUBUT', 
                                                              'CIUDAD AUTÓNOMA DE BUENOS AIRES','CÓRDOBA', 'CORRIENTES', 
                                                              'ENTRE RÍOS', 'FORMOSA', 'JUJUY', 'LA PAMPA', 'LA RIOJA', 'MENDOZA', 
                                                              'MISIONES', 'NEUQUÉN', 'RÍO NEGRO', 'SALTA', 'SAN JUAN', 'SAN LUIS', 
                                                              'SANTA CRUZ', 'SANTA FE', 'SANTIAGO DEL ESTERO', 'TIERRA DEL FUEGO', 'TUCUMÁN') 
                                          AND provincia = UPPER(provincia))
);
GO
CREATE TABLE usuario
(
  cod_usuario INT IDENTITY CONSTRAINT PK_usuario PRIMARY KEY,
  nombre_usuario VARCHAR(50) NOT NULL,
  contrasena_hash VARCHAR(255) NOT NULL,
  rol VARCHAR(20) NOT NULL,
  estado BIT NOT NULL,
  CONSTRAINT UQ_usuario_nombre_usuario UNIQUE (nombre_usuario), 
  CONSTRAINT CK_usuario_rol CHECK(UPPER(rol) IN ('DEPOSITO', 'ADMINISTRADOR', 'SOPORTE') AND rol = UPPER(rol)),
  CONSTRAINT CK_usuario_estado CHECK(estado IN (0,1)),
  CONSTRAINT DF_usuario_estado DEFAULT 1 FOR estado
);
GO
CREATE TABLE categoria
(
  cod_categoria INT IDENTITY CONSTRAINT PK_categoria PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL,
  cod_categoria_padre INT NULL, --para una jerarqu�a
  activo BIT NOT NULL,
  CONSTRAINT UQ_categoria_nombre_padre UNIQUE (nombre, cod_categoria_padre),
  CONSTRAINT FK_categoria_categoria_padre FOREIGN KEY (cod_categoria_padre) REFERENCES categoria(cod_categoria) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT DF_categoria_activo DEFAULT 1 FOR activo,
  CONSTRAINT CK_categoria_estado CHECK(activo IN (0,1))
);
GO
CREATE TABLE alicuota_iva
(
  cod_alicuota INT CONSTRAINT PK_alicuota_iva PRIMARY KEY, --código oficial de ARCA, sin IDENTITY
  nombre VARCHAR(50) NOT NULL,
  porcentaje DECIMAL(4,2) NOT NULL,
  CONSTRAINT UQ_alicuota_iva_nombre UNIQUE (nombre),
  CONSTRAINT UQ_alicuota_iva_porcentaje UNIQUE (porcentaje),
  CONSTRAINT CK_alicuota_iva_porcentaje CHECK (porcentaje >= 0 AND porcentaje < 100)
);
GO
CREATE TABLE producto
(
  cod_producto INT IDENTITY CONSTRAINT PK_producto PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL,
  descripcion VARCHAR(1000) NULL,
  precio_lista DECIMAL(10,2) NOT NULL,
  cod_alicuota INT NOT NULL,
  stock INT NOT NULL,
  cod_categoria INT NOT NULL,
  activo BIT NOT NULL,
  CONSTRAINT FK_producto_categoria FOREIGN KEY (cod_categoria) REFERENCES categoria(cod_categoria) ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT FK_producto_alicuota_iva FOREIGN KEY (cod_alicuota) REFERENCES alicuota_iva(cod_alicuota) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT DF_producto_activo DEFAULT 1 FOR activo,
  CONSTRAINT CK_producto_estado CHECK(activo IN (0,1)),
  CONSTRAINT CK_producto_precio_lista CHECK (precio_lista > 0),
  CONSTRAINT CK_producto_stock CHECK (stock >= 0)
);
GO
CREATE TABLE proveedor
(
  cod_proveedor INT IDENTITY CONSTRAINT PK_proveedor PRIMARY KEY,
  razon_social VARCHAR(50) NOT NULL,
  cuit VARCHAR(13) NOT NULL,
  calle VARCHAR(50) NOT NULL,
  numero VARCHAR(10) NOT NULL,
  ciudad VARCHAR(50) NOT NULL,
  provincia VARCHAR(50) NOT NULL,
  activo BIT NOT NULL,
  CONSTRAINT UQ_proveedor_cuit UNIQUE (cuit),
  CONSTRAINT CK_proveedor_cuit CHECK (cuit LIKE '[0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9]'),
  CONSTRAINT CK_proveedor_provincia CHECK (UPPER(provincia) IN ('BUENOS AIRES', 'CATAMARCA', 'CHACO', 'CHUBUT', 
                                                              'CIUDAD AUT�NOMA DE BUENOS AIRES','C�RDOBA', 'CORRIENTES', 
                                                              'ENTRE R�OS', 'FORMOSA', 'JUJUY', 'LA PAMPA', 'LA RIOJA', 'MENDOZA', 
                                                              'MISIONES', 'NEUQU�N', 'R�O NEGRO', 'SALTA', 'SAN JUAN', 'SAN LUIS', 
                                                              'SANTA CRUZ', 'SANTA FE', 'SANTIAGO DEL ESTERO', 'TIERRA DEL FUEGO', 'TUCUM�N') 
                                         AND provincia = UPPER(provincia)),
CONSTRAINT DF_proveedor_activo DEFAULT 1 FOR activo,
  CONSTRAINT CK_proveedor_estado CHECK(activo IN (0,1))
);
GO
CREATE TABLE metodo_pago
(
  cod_metodo_pago INT IDENTITY CONSTRAINT PK_metodo_pago PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL,
  CONSTRAINT UQ_metodo_pago_nombre UNIQUE (nombre)
);
GO
CREATE TABLE pedido
(
  cod_pedido INT IDENTITY CONSTRAINT PK_pedido PRIMARY KEY,
  fecha_pedido DATETIME NOT NULL,
  estado VARCHAR(20) NOT NULL,
  estado_pago VARCHAR(20) NOT NULL,
  ref_transaccion VARCHAR(50) NULL,
  calle  VARCHAR(50) NOT NULL,
  numero VARCHAR(10) NOT NULL,
  ciudad VARCHAR(50) NOT NULL,
  provincia VARCHAR(50) NOT NULL,
  cod_postal VARCHAR(10) NOT NULL,
  estado_envio VARCHAR(20) NULL,
  fecha_envio DATETIME NULL,
  transportista VARCHAR(50) NULL,
  fecha_entrega DATE NULL,
  nro_seguimiento VARCHAR(50) NULL,
  cod_cliente INT NOT NULL,
  cod_metodo_pago INT NOT NULL,
  cod_usuario INT NULL,
  CONSTRAINT DF_pedido_fecha_pedido DEFAULT GETDATE() FOR fecha_pedido,
  CONSTRAINT DF_pedido_estado DEFAULT 'pendiente' FOR estado,
  CONSTRAINT DF_pedido_estado_pago DEFAULT 'pendiente' FOR estado_pago,
  CONSTRAINT CK_pedido_estado CHECK (estado IN ('pendiente', 'confirmado', 'cancelado')),
  CONSTRAINT CK_pedido_estado_pago CHECK (estado_pago IN ('pendiente', 'aprobado', 'rechazado')),
  CONSTRAINT CK_pedido_estado_envio CHECK (estado_envio IS NULL OR estado_envio IN ('pendiente', 'despachado', 'entregado')),
  CONSTRAINT CK_pedido_fecha CHECK (fecha_pedido <= GETDATE()),
  CONSTRAINT CK_pedido_ref_transaccion CHECK (estado_pago <> 'aprobado' OR ref_transaccion IS NOT NULL),
  CONSTRAINT FK_pedido_cliente FOREIGN KEY (cod_cliente) REFERENCES cliente(cod_cliente) ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT FK_pedido_metodo_pago FOREIGN KEY (cod_metodo_pago) REFERENCES metodo_pago(cod_metodo_pago) ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT FK_pedido_usuario FOREIGN KEY (cod_usuario) REFERENCES usuario(cod_usuario)
  
);
GO
CREATE TABLE compra
(
  cod_compra INT IDENTITY CONSTRAINT PK_compra PRIMARY KEY,
  fecha DATETIME NOT NULL,
  estado VARCHAR(20) NOT NULL,
  nro_comprobante_prov VARCHAR(50) NULL,
  cod_proveedor INT NOT NULL,
  cod_usuario INT NOT NULL,
  CONSTRAINT FK_compra_proveedor FOREIGN KEY (cod_proveedor) REFERENCES proveedor(cod_proveedor) ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT FK_compra_usuario  FOREIGN KEY (cod_usuario) REFERENCES usuario(cod_usuario) ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT DF_compra_estado DEFAULT 'pendiente' FOR estado,
  CONSTRAINT CK_compra_estado CHECK (estado IN ('pendiente', 'recibida', 'cancelada')),
  CONSTRAINT DF_compra_fecha DEFAULT GETDATE() FOR fecha,
  CONSTRAINT CK_compra_fecha CHECK (fecha <= GETDATE())
);
GO
CREATE TABLE auditoria
(
  cod_auditoria INT IDENTITY CONSTRAINT PK_auditoria PRIMARY KEY,
  entidad VARCHAR(50) NOT NULL,
  operacion VARCHAR(10) NOT NULL,
  registro_id INT NOT NULL,
  fecha DATETIME NOT NULL,
  valor_anterior VARCHAR(255) NULL,
  valor_nuevo VARCHAR(255) NULL,
  cod_usuario INT NOT NULL,
  CONSTRAINT FK_auditoria_usuario FOREIGN KEY (cod_usuario) REFERENCES usuario(cod_usuario) ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT CK_auditoria_operacion CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE')),
  CONSTRAINT DF_auditoria_fecha DEFAULT GETDATE() FOR fecha
);
GO
CREATE TABLE factura
(
  cod_factura INT IDENTITY CONSTRAINT PK_factura PRIMARY KEY,
  tipo_comprobante CHAR(1) NOT NULL,
  numero INT NOT NULL,
  fecha_emision DATE NOT NULL,
  cond_iva_cliente VARCHAR(30) NOT NULL,
  subtotal DECIMAL(12,2) NOT NULL,
  iva_total DECIMAL(12,2) NOT NULL,
  total DECIMAL(12,2) NOT NULL,
  cae VARCHAR(14) NOT NULL,
  fecha_vto_cae DATE NOT NULL,
  tipo_documento_cliente VARCHAR(10) NULL,
  nro_documento_cliente VARCHAR(20) NULL,
  razon_social VARCHAR(100) NULL,
  punto_venta INT NOT NULL,
  cod_pedido INT NOT NULL,
  cod_usuario INT NOT NULL,
  CONSTRAINT FK_factura_pedido FOREIGN KEY (cod_pedido) REFERENCES pedido(cod_pedido) ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT FK_factura_usuario FOREIGN KEY (cod_usuario) REFERENCES usuario(cod_usuario) ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT CK_factura_montos CHECK (subtotal >= 0 AND iva_total >= 0 AND total >= 0),
  CONSTRAINT DF_factura_fecha_emision DEFAULT CAST(GETDATE() AS DATE) FOR fecha_emision,
  CONSTRAINT CK_factura_tipo_comprobante CHECK (tipo_comprobante IN ('A','B','C')),
  CONSTRAINT UQ_factura_pto_nro UNIQUE (punto_venta, numero)
);
GO
CREATE TABLE detalle_pedido
(
  item INT NOT NULL,
  precio_unitario_venta DECIMAL(10,2) NOT NULL,
  cantidad INT NOT NULL,
  alicuota_iva DECIMAL(4,2) NOT NULL,
  iva_monto DECIMAL(10,2) NOT NULL,
  cod_pedido INT NOT NULL,
  cod_producto INT NOT NULL,
  CONSTRAINT PK_detalle_pedido PRIMARY KEY (cod_pedido, cod_producto),
  CONSTRAINT FK_detalle_pedido_pedido FOREIGN KEY (cod_pedido) REFERENCES pedido(cod_pedido) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT FK_detalle_pedido_producto FOREIGN KEY (cod_producto) REFERENCES producto(cod_producto) ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT CK_detalle_pedido_cantidad CHECK (cantidad > 0),
  CONSTRAINT CK_detalle_pedido_precio CHECK (precio_unitario_venta > 0)
);
GO
CREATE TABLE detalle_compra
(
  costo_unitario DECIMAL(10,2) NOT NULL,
  cantidad INT NOT NULL,
  cod_producto INT NOT NULL,
  cod_compra INT NOT NULL,
  CONSTRAINT PK_detalle_compra PRIMARY KEY (cod_producto, cod_compra),
  CONSTRAINT FK_detalle_compra_producto FOREIGN KEY (cod_producto) REFERENCES producto(cod_producto),
  CONSTRAINT FK_detalle_compra_compra FOREIGN KEY (cod_compra) REFERENCES compra(cod_compra) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT CK_detalle_compra_cantidad CHECK (cantidad > 0),
  CONSTRAINT CK_detalle_compra_costo CHECK (costo_unitario > 0)
);
GO
CREATE TABLE promocion (
    cod_promocion        INT IDENTITY(1,1) NOT NULL,
    nombre               VARCHAR(100)      NOT NULL,
    descripcion          VARCHAR(500)      NULL,
    fecha_inicio         DATETIME          NOT NULL,
    fecha_fin            DATETIME          NOT NULL,
    porcentaje_descuento DECIMAL(5,2)      NULL,
    nro_cuotas           INT               NULL,
    CONSTRAINT PK_promocion PRIMARY KEY (cod_promocion),
    CONSTRAINT CK_promocion_fechas
        CHECK (fecha_fin >= fecha_inicio),
    CONSTRAINT CK_promocion_descuento
        CHECK (porcentaje_descuento > 0 AND porcentaje_descuento <= 75),
    CONSTRAINT CK_promocion_cuotas
        CHECK (nro_cuotas BETWEEN 2 AND 36),
    CONSTRAINT CK_promocion_beneficio
        CHECK (porcentaje_descuento IS NOT NULL OR nro_cuotas IS NOT NULL)
);
GO
CREATE TABLE promocion_producto (
    cod_promocion INT NOT NULL,
    cod_producto  INT NOT NULL,
    CONSTRAINT PK_promocion_producto PRIMARY KEY (cod_promocion, cod_producto),
    CONSTRAINT FK_promprod_promocion FOREIGN KEY (cod_promocion)
        REFERENCES promocion (cod_promocion)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_promprod_producto FOREIGN KEY (cod_producto)
        REFERENCES producto (cod_producto)
        ON DELETE CASCADE ON UPDATE CASCADE
);
GO
CREATE TABLE slide (
    cod_slide     INT IDENTITY(1,1) NOT NULL,
    url           VARCHAR(500)      NOT NULL,
    cod_promocion INT               NOT NULL,
    CONSTRAINT PK_slide PRIMARY KEY (cod_slide),
    CONSTRAINT UQ_slide_url UNIQUE (url),
    CONSTRAINT CK_slide_url CHECK (url LIKE 'https://%'),
    CONSTRAINT FK_slide_promocion FOREIGN KEY (cod_promocion)
        REFERENCES promocion (cod_promocion)
        ON DELETE CASCADE ON UPDATE CASCADE
);
GO
CREATE TABLE multimedia (
    cod_multimedia INT IDENTITY(1,1) NOT NULL,
    url            VARCHAR(500)      NOT NULL,
    tipo           VARCHAR(10)       NOT NULL,
    cod_producto   INT               NOT NULL,
    CONSTRAINT PK_multimedia PRIMARY KEY (cod_multimedia),
    CONSTRAINT UQ_multimedia_url UNIQUE (url),
    CONSTRAINT CK_multimedia_url CHECK (url LIKE 'https://%'),
    CONSTRAINT CK_multimedia_tipo CHECK (tipo IN ('imagen', 'video')),
    CONSTRAINT FK_multimedia_producto FOREIGN KEY (cod_producto)
        REFERENCES producto (cod_producto)
        ON DELETE CASCADE ON UPDATE CASCADE
);
GO
CREATE TABLE especificacion (
    cod_especificacion INT IDENTITY(1,1) NOT NULL,
    nombre             VARCHAR(100)      NOT NULL,
    CONSTRAINT PK_especificacion PRIMARY KEY (cod_especificacion),
    CONSTRAINT UQ_especificacion_nombre UNIQUE (nombre)
);
GO
CREATE TABLE especificacion_producto (
    cod_producto       INT          NOT NULL,
    cod_especificacion INT          NOT NULL,
    valor              VARCHAR(150) NOT NULL,
    CONSTRAINT PK_especificacion_producto
        PRIMARY KEY (cod_producto, cod_especificacion),
    CONSTRAINT FK_espprod_producto FOREIGN KEY (cod_producto)
        REFERENCES producto (cod_producto)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_espprod_especificacion FOREIGN KEY (cod_especificacion)
        REFERENCES especificacion (cod_especificacion)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    CONSTRAINT CK_espprod_valor CHECK (LEN(valor) > 0)
);
GO
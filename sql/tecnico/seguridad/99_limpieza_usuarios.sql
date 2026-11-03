-- =============================================================
-- ETAPA V - Seguridad: limpieza
-- Elimina los usuarios, el rol y los inicios de sesión de
-- 02_usuarios_y_roles.sql. Los inicios de sesión son del servidor:
-- no se borran al eliminar la base.
-- =============================================================

USE smarthome_store;
GO

DROP USER IF EXISTS smarthome_admin;
DROP USER IF EXISTS smarthome_lectura;
DROP USER IF EXISTS smarthome_con_rol;
DROP USER IF EXISTS smarthome_sin_rol;
DROP ROLE IF EXISTS rol_lectura_producto;
GO

IF SUSER_ID('smarthome_admin') IS NOT NULL DROP LOGIN smarthome_admin;
IF SUSER_ID('smarthome_lectura') IS NOT NULL DROP LOGIN smarthome_lectura;
IF SUSER_ID('smarthome_con_rol') IS NOT NULL DROP LOGIN smarthome_con_rol;
IF SUSER_ID('smarthome_sin_rol') IS NOT NULL DROP LOGIN smarthome_sin_rol;
GO

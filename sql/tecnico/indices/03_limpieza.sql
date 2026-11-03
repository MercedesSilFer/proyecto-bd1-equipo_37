-- =============================================================
-- ETAPA V - Índices: limpieza
-- Elimina la tabla auxiliar, para que la base vuelva a las 22 tablas
-- del modelo.
-- =============================================================

USE smarthome_store;
GO

DROP TABLE IF EXISTS dbo.venta_historica;
GO

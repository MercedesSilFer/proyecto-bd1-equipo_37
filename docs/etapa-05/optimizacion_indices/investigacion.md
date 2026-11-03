# Optimización de consultas con índices

**Base de datos:** `smarthome_store` (SQL Server)
**Scripts:** [sql/tecnico/indices](../../../sql/tecnico/indices/) · **Planes de ejecución:** carpeta [evidencias](evidencias/)

---

## 1. Definición y objetivo

Un **índice** es una estructura ordenada que le permite al motor encontrar filas sin recorrer toda la tabla, como el índice de un libro. SQL Server los guarda como árboles B: baja desde la raíz hasta las hojas en pocos pasos.

**Objetivo en nuestro proyecto:** medir cuánto mejora una búsqueda por período, porque los reportes de ventas filtran por fecha (CU-15) y esa búsqueda se vuelve más costosa a medida que crece el historial.

## 2. Ventajas y costos

**Ventajas:**

- Reducen las páginas que se leen y, con ellas, el tiempo de respuesta.
- Permiten resolver rangos de fechas sin recorrer toda la tabla.
- Un índice que contiene todas las columnas de la consulta evita leer la tabla.

**Costos:**

- Cada `INSERT`, `UPDATE` o `DELETE` también tiene que actualizar los índices.
- Un índice no agrupado ocupa espacio adicional.
- Conviene crearlos para consultas reales, no sobre todas las columnas.

## 3. Implementación en SQL Server

| Tipo | Qué es | Cuántos por tabla |
|---|---|---|
| Heap | Tabla sin índice agrupado: las filas no tienen un orden definido | No aplica |
| Agrupado (`CLUSTERED`) | Ordena las filas de la tabla: sus hojas son los propios datos | Uno |
| No agrupado (`NONCLUSTERED`) | Estructura aparte, con la clave y una referencia a la fila | Varios |
| No agrupado con `INCLUDE` | Además guarda columnas en sus hojas, para no ir a la tabla | Varios |

| Operador del plan | Qué significa |
|---|---|
| `Table Scan` | Recorre toda la tabla |
| `Clustered Index Seek` | Va directo al rango dentro del índice agrupado |
| `Index Seek` | Va directo al rango dentro de un índice no agrupado |

## 4. Caso concreto aplicado a SmartHome Store

Se creó `venta_historica`, una tabla auxiliar con **un millón de ventas** de 2021 a 2026. No forma parte del modelo y se elimina al final. No se usó `pedido` porque ya tiene un índice agrupado en su clave primaria y su trigger generaría un millón de filas de auditoría.

La consulta es la misma en los tres escenarios y devuelve 14.158 filas:

```sql
SELECT cod_venta, fecha_venta, importe
FROM dbo.venta_historica
WHERE fecha_venta >= '2025-01-01' AND fecha_venta < '2025-02-01';
```

| Script | Qué hace |
|---|---|
| [01_carga_masiva.sql](../../../sql/tecnico/indices/01_carga_masiva.sql) | Crea la tabla sin índices y carga el millón de filas |
| [02_pruebas_indices.sql](../../../sql/tecnico/indices/02_pruebas_indices.sql) | Crea cada índice y repite la consulta |
| [03_limpieza.sql](../../../sql/tecnico/indices/03_limpieza.sql) | Elimina la tabla auxiliar |

**Diferencia con la consigna:** el tema pide un segundo índice agrupado que incluya las columnas seleccionadas, pero SQL Server no admite `INCLUDE` en un índice agrupado, porque ese índice ya contiene todas las columnas. Por eso el tercer escenario usa un índice no agrupado con `INCLUDE`.

## 5. Demostración y resultados

Las pruebas se ejecutaron con `sqlcmd` sobre una base temporal, en una sola PC con SQL Server Express. "En frío" es la primera lectura, sin datos en memoria; "en caliente" es la mediana de 9 repeticiones. El tiempo incluye escribir las filas en un archivo.

| Escenario | Operador | Filas leídas | Lecturas lógicas | Costo estimado | Tiempo en frío | Tiempo en caliente |
|---|---|---|---|---|---|---|
| 1. Sin índice | `Table Scan` | 1.000.000 | 25.642 | 20,10 | 178 ms | 142 ms |
| 2. Índice agrupado | `Clustered Index Seek` | 14.158 | 367 | 0,29 | 44 ms | 32 ms |
| 3. No agrupado con `INCLUDE` | `Index Seek` | 14.158 | 67 | 0,06 | 42 ms | 29 ms |

| Estructura | Tamaño | Tiempo de creación |
|---|---|---|
| Tabla sin índice (heap) | 200 MB | No aplica |
| Índice agrupado (reemplaza al heap) | 200 MB | 2.022 ms |
| Índice no agrupado con `INCLUDE` (se suma a la tabla) | 33 MB | 634 ms |

Los planes reales están en la carpeta [evidencias](evidencias/) y se abren en SSMS:

- [plan_1_sin_indice.sqlplan](evidencias/plan_1_sin_indice.sqlplan)
- [plan_2_indice_agrupado.sqlplan](evidencias/plan_2_indice_agrupado.sqlplan)
- [plan_3_indice_no_agrupado_cubriente.sqlplan](evidencias/plan_3_indice_no_agrupado_cubriente.sqlplan)

## 6. Conclusiones

- **Sin índice, el motor lee todo:** recorre el millón de filas para devolver 14.158. La consulta se encarece a medida que crece la tabla, aunque el resultado sea el mismo.
- **El índice agrupado redujo las lecturas un 98,6 %** (de 25.642 a 367), porque las filas quedan ordenadas por fecha y el rango está contiguo. Pero una tabla tiene un solo índice agrupado, así que elegir la fecha impide usarlo para otra columna, como la clave primaria.
- **El índice con `INCLUDE` fue el que menos leyó** (67 lecturas, un 99,7 % menos), porque sus hojas solo guardan las columnas que pide la consulta. A cambio ocupa 33 MB más y solo cubre esta consulta: si se pide otra columna, el motor tiene que ir a buscarla a la tabla.
- **Las lecturas son una medida más confiable que el tiempo.** Las lecturas se repiten exactas en cada corrida, y el tiempo depende de la PC. Entre el índice agrupado y el no agrupado casi no hay diferencia de tiempo (32 y 29 ms), porque gran parte se va en devolver las filas.

**Para nuestro modelo:** los datos de prueba tienen solo 12 pedidos, así que un índice hoy no aportaría una mejora medible. Si el historial crece, conviene un índice no agrupado sobre `pedido.fecha_pedido`, porque `pedido` ya usa su índice agrupado en la clave primaria.

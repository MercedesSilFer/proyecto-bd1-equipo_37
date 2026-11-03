# Alcance del Sistema

## Actores

| Actor | Qué hace |
|---|---|
| Cliente | Se registra, administra sus direcciones y genera pedidos |
| Depósito | Gestiona las compras a proveedores y confirma el despacho de pedidos |
| Administrador | Gestiona el catálogo, las promociones, los usuarios y las facturas, y consulta la auditoría |
| Soporte | Consulta el estado de pedidos y envíos |
| Pasarela de pago (sistema externo) | Informa el resultado de cada pago |

## Funciones que cubrirá el sistema

- **Gestión de clientes**: registro y autogestión de clientes (alta, login con email/contraseña, nombre completo y direcciones de envío).
- **Gestión de productos**: catálogo de productos y categorías, con sus respectivos precio de lista, alícuota de IVA, stock, descripción, especificaciones técnicas (ficha técnica) y contenido multimedia (imágenes y videos).
- **Gestión de promociones**: registro de promociones con vigencia, porcentaje de descuento y/o cuotas sin interés, aplicables a uno o varios productos, y sus slides (banners) para la página principal de la tienda.
- **Gestión de compras a proveedores**: catálogo de proveedores, historial de compras y control de stock mediante actualización en catálogo de productos.
- **Registro de pedidos**: con confirmación por parte del cliente, validación automática de stock disponible antes de confirmar la operación, y seguimiento logístico del envío (transportista, número de seguimiento, estado), método de pago y estado como datos propios del pedido; el monto no se guarda, se calcula desde el detalle (RN.10). Un pedido puede cancelarse mientras no esté facturado ni despachado (RN.30).
- **Registro de métodos de pago.**
- **Emisión de facturación total del pedido.**
- **Gestión de usuarios internos**: administración del sistema mediante usuarios con roles diferenciados (depósito, administrador, soporte) y permisos distintos por rol; auditoría de las operaciones sensibles realizadas sobre precios, stock, pedidos, facturación y compras.

## Funciones que NO cubrirá el sistema

- La lógica interna de procesamiento de la pasarela de pago (solo se integra su resultado).
- La gestión logística del transporte en sí (flota, rutas, tarifas).
- La gestión de la venta física en local.
- Gestión de consultas.
- Devoluciones y cambios de productos.

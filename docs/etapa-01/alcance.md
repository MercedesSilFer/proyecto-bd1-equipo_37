# Alcance del Sistema

## Funciones que cubrirá el sistema

- **Gestión de clientes**: registro y autogestión de clientes (alta, login con email/contraseña, nombre completo y dirección de envío).
- **Gestión de productos**: catálogo de productos y categorías, con sus respectivos precio de lista y stock.
- **Gestión de compras a proveedores**: catálogo de proveedores, historial de compras y control de stock mediante actualización en catálogo de productos.
- **Registro de pedidos**: con confirmación por parte del cliente, validación automática de stock disponible antes de confirmar la operación, y seguimiento logístico del envío (transportista, número de seguimiento, estado), método de pago, estado y monto como datos propios del pedido.
- **Registro de métodos de pago.**
- **Emisión de facturación total del pedido.**
- **Gestión de usuarios internos**: administración del sistema mediante usuarios con roles diferenciados (depósito, administrador, soporte) y permisos distintos por rol; auditoría de las operaciones sensibles realizadas sobre precios, stock, pedidos, facturación y compras.

## Funciones que NO cubrirá el sistema

- La lógica interna de procesamiento de la pasarela de pago (solo se integra su resultado).
- La gestión logística del transporte en sí (flota, rutas, tarifas).
- La gestión de la venta física en local.
- Gestión de consultas.
- Devoluciones y cambios de productos.

# CHANGELOG

Todas las novedades, mejoras y correcciones planeadas y lanzadas para Deuda Flow.


## [1.0.3] - 2025-08-25
- Selección automática de la última moneda nueva agregada en los chips de moneda.
- Contador visual de caracteres en el campo "descripción" de los formularios de transacción, con cambio de color según los caracteres restantes.
- Mejoras en validación y sincronización de monedas/tasas.
- Segundo diálogo de confirmación al intentar eliminar todas las transacciones o todos los clientes, para evitar eliminaciones accidentales.
-Agrega nombre y telefono del cliente al selecciona de forma automatica
- Campo de tasa ahora readOnly; edición por diálogo y persistencia inmediata.
- Corrección en cálculo/estadísticas y en la visualización de montos usando `anchorUsdValue`.
- `TransactionCard` muestra montos correctamente convertidos; etiqueta no engañosa.
- Se eliminó la fila icono+texto en el modal de añadir transacción.
- PDFs: mejor formato de montos y se quitaron los códigos de moneda en las celdas de tabla.
- Mensaje del snackBar al cerrar sesión cambiado a "Cierre de sesión exitoso".
- Test actualizado para evitar inicializar Hive en unit tests rápidos.


## [1.0.2] - 2025-08-24
- Versión inicial publicada en Google Play.
- Control de deudas y pagos sin conexión y con sincronización online.
- Soporte para múltiples monedas y tasas de cambio personalizables.
- Generación de recibos individuales y generales en PDF.
- Gestión de clientes y transacciones.



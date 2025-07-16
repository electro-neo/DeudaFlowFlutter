import 'package:flutter/material.dart'; // Importa los widgets principales de Flutter
import 'package:provider/provider.dart'; // Importa Provider para manejo de estado global
import '../providers/client_provider.dart'; // Proveedor de clientes
import '../providers/transaction_provider.dart'; // Proveedor de transacciones
import '../providers/tab_provider.dart'; // Proveedor para la navegación de pestañas
import '../providers/transaction_filter_provider.dart'; // Proveedor para filtrar transacciones
import '../providers/currency_provider.dart'; // Proveedor de moneda y tasa
import '../utils/currency_utils.dart'; // Utilidades para formatear moneda

// Widget que muestra los statscard del dashboard
class DashboardStats extends StatelessWidget {
  const DashboardStats({super.key});
  //
  @override
  Widget build(BuildContext context) {
    // Escuchar cambios de moneda/tasa
    context.watch<CurrencyProvider>(); // Escucha cambios en la moneda/tasa
    final clients = context
        .watch<ClientProvider>()
        .clients; // Obtiene la lista de clientes
    final transactions = context
        .watch<TransactionProvider>()
        .transactions; // Obtiene la lista de transacciones
    final totalClients = clients.length; // Total de clientes
    String format(num value) => CurrencyUtils.formatCompact(
      context,
      value,
    ); // Formatea números de moneda
    // Calcular totales
    // Deuda total: suma de los balances negativos de los clientes (deuda real pendiente)
    double totalDeuda = 0;
    for (final c in clients) {
      debugPrint(
        '[DashboardStats][DEBUG] Cliente: ${c.name}, Balance: ${c.balance}',
      );
      if (c.balance < 0) totalDeuda += -c.balance;
    }
    debugPrint('[DashboardStats][DEBUG] Deuda total calculada: $totalDeuda');
    debugPrint('[DashboardStats][DEBUG][TRANS] Transacciones actuales:');
    for (final t in transactions) {
      debugPrint(
        '[DashboardStats][DEBUG][TRANS] id: ${t.id}, desc: ${t.description}, amount: ${t.amount}, type: ${t.type}, clientId: ${t.clientId}, pendingDelete: ${t.pendingDelete}',
      );
    }
    debugPrint(
      '[DashboardStats][DEBUG][EVENT] --- FIN DEUDA TOTAL, tras posible eliminación de transacción ---',
    );
    // Total abonado y saldo neto siguen calculados desde transacciones
    double totalAbonado = 0;
    double totalSaldo = 0;
    if (transactions.isNotEmpty) {
      totalAbonado = transactions
          .where((t) => t.type == 'payment')
          .fold<double>(0, (sum, t) => sum + t.amount);
      // El saldo neto puede calcularse como suma de balances de todos los clientes
      totalSaldo = clients.fold<double>(0, (sum, c) => sum + c.balance);
    }
    // LOGS TEMPORALES PARA DEPURACIÓN
    debugPrint(
      '[DashboardStats] Clientes: \\${clients.length}',
    ); // Muestra en consola la cantidad de clientes
    debugPrint(
      '[DashboardStats] Transacciones: \\${transactions.length}',
    ); // Muestra en consola la cantidad de transacciones
    debugPrint(
      '[DashboardStats] totalDeuda: $totalDeuda',
    ); // Muestra el total de deuda
    debugPrint(
      '[DashboardStats] totalAbonado: $totalAbonado',
    ); // Muestra el total abonado
    debugPrint(
      '[DashboardStats] totalSaldo: $totalSaldo',
    ); // Muestra el saldo neto
    // Navegación igual que el botón de la barra inferior usando Provider
    void goToClientsTab() {
      Provider.of<TabProvider>(
        context,
        listen: false,
      ).setTab(1); // Cambia a la pestaña de clientes
    }

    void goToDeudaTab() {
      Provider.of<TransactionFilterProvider>(
        context,
        listen: false,
      ).setType('debt'); // Filtra por deudas
      Provider.of<TabProvider>(
        context,
        listen: false,
      ).setTab(2); // Cambia a la pestaña de transacciones
    }

    void goToAbonoTab() {
      Provider.of<TransactionFilterProvider>(
        context,
        listen: false,
      ).setType('payment'); // Filtra por abonos
      Provider.of<TabProvider>(
        context,
        listen: false,
      ).setTab(2); // Cambia a la pestaña de transacciones
    }

    //
    // Creamos los stat cards
    final statClientes = _StatCard(
      label: 'Clientes', // Título del statcard
      value: totalClients.toString(), // Valor: cantidad de clientes
      icon: Icons.people, // Icono de personas
      isButton: true, // Es un botón
      onTap: goToClientsTab, // Acción al pulsar
    );
    final statDeuda = _StatCard(
      label: 'Deuda total', // Título del statcard
      value: format(totalDeuda), // Valor: total de deuda
      icon: Icons.trending_up, // Icono de tendencia hacia arriba
      color: Colors.red, // Color rojo
      isButton: true, // Es un botón
      onTap: goToDeudaTab, // Acción al pulsar
    );
    final statAbonado = _StatCard(
      label: 'Total abonado', // Título del statcard
      value: format(totalAbonado), // Valor: total abonado
      icon: Icons.trending_down, // Icono de tendencia hacia abajo
      color: Colors.green, // Color verde
      isButton: true, // Es un botón
      onTap: goToAbonoTab, // Acción al pulsar
    );
    // StatCard Clientes con deudas (balance < 0)
    final clientesConDeuda = clients
        .where((c) => c.balance < 0)
        .length; // Cuenta clientes con balance negativo (deuda)
    final statClientesConDeuda = _StatCard(
      label: 'Clientes con deudas', // Título del statcard
      value: clientesConDeuda
          .toString(), // Valor: cantidad de clientes con deuda
      icon: Icons.warning_amber_rounded, // Icono de advertencia
      color: Colors.orange, // Color naranja
    );
    //
    // Orden personalizado: Clientes y Saldo neto arriba, Deuda total y Total abonado abajo
    // --- INICIO: Layout 2x2 (dos filas, dos columnas) para los statcards ---
    // Puedes ajustar los SizedBox(width) y SizedBox(height) para el tamaño y separación
    // --- INICIO: Layout 2x2 con ancho individual por statcard ---
    // --- INICIO: Configuración individual de ancho y márgenes para cada statcard ---
    // width* controla el ancho de cada statcard
    // marginLeft* controla el margen izquierdo de cada statcard (espacio a la izquierda)
    // --- INICIO: Layout 2x2 (dos filas, dos columnas) para los statcards ---
    // Puedes ajustar los SizedBox(width) y SizedBox(height) para el tamaño y separación
    // --- INICIO: Layout 2x2 con ancho individual por statcard ---
    // Puedes ajustar individualmente el ancho y los márgenes de cada statcard cambiando los valores abajo

    // --- FILA SUPERIOR ---
    // Statcard de la IZQUIERDA ARRIBA (Clientes):
    // widthClientes: ancho del statcard de clientes (izquierda arriba)
    // heightClientes: alto del statcard de clientes
    // marginLeftClientes: margen izquierdo del statcard de clientes
    // marginRightClientes: margen derecho del statcard de clientes (espacio entre clientes y clientes con deuda)
    // marginBottomClientes: margen inferior del statcard de clientes (espacio debajo de la tarjeta)
    const double widthClientes = 160;
    const double heightClientes = 180;
    const double marginLeftClientes = 0;
    const double marginRightClientes = 1;
    const double marginBottomClientes = 0;

    // Statcard de la DERECHA ARRIBA (Clientes con deudas):
    // widthClientesConDeuda: ancho del statcard de clientes con deudas (derecha arriba)
    // heightClientesConDeuda: alto del statcard de clientes con deudas
    // marginLeftClientesConDeuda: margen izquierdo del statcard de clientes con deudas (espacio entre clientes y clientes con deudas)
    // marginRightClientesConDeuda: margen derecho del statcard de clientes con deudas
    // marginBottomClientesConDeuda: margen inferior del statcard de clientes con deudas
    const double widthClientesConDeuda = 160;
    const double heightClientesConDeuda = 180;
    const double marginLeftClientesConDeuda = 1;
    const double marginRightClientesConDeuda = 0;
    const double marginBottomClientesConDeuda = 0;

    // --- FILA INFERIOR ---
    // Statcard de la IZQUIERDA ABAJO (Deuda total):
    // widthDeuda: ancho del statcard de deuda total (izquierda abajo)
    // heightDeuda: alto del statcard de deuda total
    // marginLeftDeuda: margen izquierdo del statcard de deuda total
    // marginRightDeuda: margen derecho del statcard de deuda total (espacio entre deuda y abonado)
    // marginTopDeuda: margen superior del statcard de deuda total (espacio arriba de la tarjeta)
    const double widthDeuda = 160;
    const double heightDeuda = 180;
    const double marginLeftDeuda = 0;
    const double marginRightDeuda = 1;
    const double marginTopDeuda = 0;

    // Statcard de la DERECHA ABAJO (Total abonado):
    // widthAbonado: ancho del statcard de total abonado (derecha abajo)
    // heightAbonado: alto del statcard de total abonado
    // marginLeftAbonado: margen izquierdo del statcard de total abonado (espacio entre deuda y abonado)
    // marginRightAbonado: margen derecho del statcard de total abonado
    // marginTopAbonado: margen superior del statcard de total abonado
    const double widthAbonado = 160;
    const double heightAbonado = 180;
    const double marginLeftAbonado = 1;
    const double marginRightAbonado = 0;
    const double marginTopAbonado = 0;

    // --- FIN DE LOS AJUSTES DE ANCHOS Y MÁRGENES ---
    // Para mover o cambiar el tamaño de cada statcard, modifica los valores de width*, height* y margin* correspondientes arriba.
    // Ahora también puedes ajustar el margen inferior de los statcards de la fila superior (marginBottomClientes, marginBottomClientesConDeuda),
    // el margen superior de los statcards de la fila inferior (marginTopDeuda, marginTopAbonado),
    // y el alto de cada statcard (height*).
    // Ejemplo: para hacer más alto el statcard de Clientes, aumenta heightClientes.

    return Center(
      child: SizedBox(
        width: 600, // Ancho total del área de statcards
        child: Column(
          children: [
            // --- FILA SUPERIOR: Clientes (izquierda) y Clientes con deudas (derecha) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Statcard IZQUIERDA ARRIBA (Clientes)
                Container(
                  margin: EdgeInsets.only(
                    left: marginLeftClientes,
                    right: marginRightClientes,
                    bottom: marginBottomClientes,
                  ),
                  width: widthClientes,
                  height: heightClientes,
                  child: statClientes,
                ),
                // Statcard DERECHA ARRIBA (Clientes con deudas)
                Container(
                  margin: EdgeInsets.only(
                    left: marginLeftClientesConDeuda,
                    right: marginRightClientesConDeuda,
                    bottom: marginBottomClientesConDeuda,
                  ),
                  width: widthClientesConDeuda,
                  height: heightClientesConDeuda,
                  child: statClientesConDeuda,
                ),
              ],
            ),
            const SizedBox(height: 1), // Espacio vertical entre filas
            // --- FILA INFERIOR: Deuda total (izquierda) y Total abonado (derecha) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Statcard IZQUIERDA ABAJO (Deuda total)
                Container(
                  margin: EdgeInsets.only(
                    left: marginLeftDeuda,
                    right: marginRightDeuda,
                    top: marginTopDeuda,
                  ),
                  width: widthDeuda,
                  height: heightDeuda,
                  child: statDeuda,
                ),
                // Statcard DERECHA ABAJO (Total abonado)
                Container(
                  margin: EdgeInsets.only(
                    left: marginLeftAbonado,
                    right: marginRightAbonado,
                    top: marginTopAbonado,
                  ),
                  width: widthAbonado,
                  height: heightAbonado,
                  child: statAbonado,
                ),
              ],
            ),
          ],
        ),
      ),
    );
    // --- FIN: Cambia los valores de width* y marginLeft*/marginRight* para ajustar cada lado de cada statcard ---
  }
}

// StatCard reutilizable para mostrar cada estadística del dashboard
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final bool isButton;
  final VoidCallback? onTap;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.isButton = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cardColor = isLight ? Colors.white : null;
    // Ajustes de layout para que el texto del label nunca se corte ni salte de línea innecesariamente:
    // - Se usa un layout flexible y padding reducido
    // - El label se ajusta a una sola línea si cabe, o máximo dos líneas sin cortar palabras
    // - El ancho máximo del label depende del ancho real del statcard
    final cardContent = Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 18.0,
        horizontal: 16.0,
      ), // Padding horizontal reducido
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color ?? Colors.blue, size: 40),
          const SizedBox(height: 10),
          // Valor principal (monto/cantidad) con tamaño de fuente más grande
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 28, // <-- Cambia aquí el tamaño del monto
                letterSpacing: 0.5,
              ),
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              // Calcula el ancho máximo disponible para el label
              final maxLabelWidth = constraints.maxWidth;
              return Container(
                width: double.infinity,
                alignment: Alignment.center,
                constraints: BoxConstraints(
                  minHeight: 36,
                  minWidth: 0,
                  maxWidth: maxLabelWidth, // Usa todo el ancho disponible
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7B7B7B),
                  ),
                  maxLines: 2, // Permite hasta dos líneas
                  overflow: TextOverflow.ellipsis, // Si no cabe, muestra ...
                  textAlign: TextAlign.center,
                  softWrap: true,
                ),
              );
            },
          ),
        ],
      ),
    );
    if (isButton) {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: cardColor,
          child: cardContent,
        ),
      );
    } else {
      return Card(color: cardColor, child: cardContent);
    }
  }
}

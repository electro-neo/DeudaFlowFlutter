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
    // Calcular totales SOLO a partir de transacciones
    double totalDeuda = 0; // Total de deuda
    double totalAbonado = 0; // Total abonado
    double totalSaldo = 0; // Saldo neto
    if (transactions.isNotEmpty) {
      totalDeuda = transactions
          .where((t) => t.type == 'debt') // Filtra transacciones de tipo deuda
          .fold<double>(
            0,
            (sum, t) => sum + t.amount,
          ); // Suma los montos de deuda
      totalAbonado = transactions
          .where(
            (t) => t.type == 'payment',
          ) // Filtra transacciones de tipo abono
          .fold<double>(
            0,
            (sum, t) => sum + t.amount,
          ); // Suma los montos abonados
      totalSaldo = totalDeuda - totalAbonado; // Calcula el saldo neto
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
    // StatCard Clientes con deudas (balance > 0)
    final clientesConDeuda = clients
        .where((c) => c.balance > 0)
        .length; // Cuenta clientes con balance positivo
    final statClientesConDeuda = _StatCard(
      label: 'Clientes con deudas', // Título del statcard
      value: clientesConDeuda
          .toString(), // Valor: cantidad de clientes con deuda
      icon: Icons.warning_amber_rounded, // Icono de advertencia
      color: Colors.orange, // Color naranja
    );
    //
    // Orden personalizado: Clientes y Saldo neto arriba, Deuda total y Total abonado abajo
    return Center(
      child: SizedBox(
        width:
            1000, // Mucho más ancho para evitar saltos de línea en los labels
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: statClientes), // Statcard de clientes
                const SizedBox(width: 16), // Espacio entre statcards
                Expanded(
                  child: statClientesConDeuda,
                ), // Statcard de clientes con deudas
              ],
            ),
            const SizedBox(height: 16), // Espacio vertical
            Row(
              children: [
                Expanded(child: statDeuda), // Statcard de deuda total
                const SizedBox(width: 16), // Espacio entre statcards
                Expanded(child: statAbonado), // Statcard de total abonado
              ],
            ),
          ],
        ),
      ),
    );
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
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
                    fontSize: 15,
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

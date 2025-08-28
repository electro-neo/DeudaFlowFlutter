import 'package:flutter/material.dart'; // Importa los widgets principales de Flutter
import 'package:intl/intl.dart'; // Importar para formateo de números
import 'scale_on_tap.dart';
import 'package:provider/provider.dart'; // Importa Provider para manejo de estado global
import '../providers/client_provider.dart'; // Proveedor de clientes
import '../providers/transaction_provider.dart'; // Proveedor de transacciones
// import '../providers/tab_provider.dart'; // Proveedor para la navegación de pestañas
import '../providers/transaction_filter_provider.dart'; // Proveedor para filtrar transacciones
import '../providers/currency_provider.dart'; // Proveedor de moneda y tasa
// Utilidades para formatear moneda

// Widget que muestra los statscard del dashboard
class DashboardStats extends StatefulWidget {
  final void Function(int)? onTab;
  final Duration scaleTapDuration;
  const DashboardStats({
    super.key,
    this.onTab,
    this.scaleTapDuration = const Duration(milliseconds: 120),
  });

  @override
  State<DashboardStats> createState() => _DashboardStatsState();
}

class _DashboardStatsState extends State<DashboardStats> {
  @override
  Widget build(BuildContext context) {
    // 1. Escuchar y obtener la instancia del provider
    final currencyProvider = context.watch<CurrencyProvider>();
    final clients = context.watch<ClientProvider>().clients;
    final transactions = context.watch<TransactionProvider>().transactions;
    final totalClients = clients.length;

    // 2. Lógica de formato y conversión explícita DENTRO del widget
    // Nueva función para obtener solo el monto formateado
    String getFormattedAmount(num value) {
      final selectedCurrency = currencyProvider.currency;
      // FIX: Se usa getRateFor para obtener la tasa correcta de la moneda seleccionada.
      final rate = currencyProvider.getRateFor(selectedCurrency) ?? 1.0;
      num displayValue = value;

      if (selectedCurrency != 'USD' && rate > 0) {
        displayValue = value * rate;
      }
      return NumberFormat("#,##0.00", "en_US").format(displayValue);
    }

    // Nueva función para obtener solo el símbolo de la moneda
    String getCurrencySymbol() {
      return currencyProvider.currency;
    }

    // --- INICIO: Cálculo de estadísticas basado en anchorUsdValue ---
    // Se calculan todos los valores desde la lista de transacciones para asegurar consistencia.

    // 1. Calcular el balance individual de cada cliente en USD
    final Map<String, double> clientBalances = {
      for (var c in clients) c.id: 0.0,
    };
    for (final t in transactions) {
      final value = t.anchorUsdValue ?? 0.0;
      if (clientBalances.containsKey(t.clientId)) {
        if (t.type == 'payment') {
          clientBalances[t.clientId] = clientBalances[t.clientId]! + value;
        } else if (t.type == 'debt') {
          clientBalances[t.clientId] = clientBalances[t.clientId]! - value;
        }
      }
    }

    // 2. Calcular las estadísticas globales usando los balances y transacciones
    // Deuda total: suma de los balances negativos de los clientes (deuda real pendiente)
    final totalDeuda = clientBalances.values
        .where((balance) => balance < 0)
        .fold<double>(0, (sum, balance) => sum + balance.abs());

    // Total abonado: suma de todas las transacciones de tipo 'payment' en USD
    final totalAbonado = transactions
        .where((t) => t.type == 'payment')
        .fold<double>(0, (sum, t) => sum + (t.anchorUsdValue ?? 0.0));

    // Clientes con deudas: cuenta de clientes con balance negativo
    final clientesConDeuda = clientBalances.values.where((b) => b < 0).length;

    // --- FIN: Cálculo de estadísticas ---

    // LOGS TEMPORALES PARA DEPURACIÓN
    final totalSaldo = totalAbonado - totalDeuda; // <-- CÁLCULO AÑADIDO
    debugPrint(
      '[DashboardStats] Clientes: ${clients.length}',
    ); // Muestra en consola la cantidad de clientes
    debugPrint(
      '[DashboardStats] Transacciones: ${transactions.length}',
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
      if (widget.onTab != null) widget.onTab!(1);
    }

    Future<void> goToDeudaTab() async {
      if (widget.onTab != null) {
        widget.onTab!(2);
        await Future.delayed(widget.scaleTapDuration);
      }
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      Provider.of<TransactionFilterProvider>(
        // ignore: use_build_context_synchronously
        context,
        listen: false,
      ).setType('debt'); // Filtra por deudas
    }

    Future<void> goToAbonoTab() async {
      if (widget.onTab != null) {
        widget.onTab!(2);
        await Future.delayed(widget.scaleTapDuration);
      }
      if (!mounted) return;
      Provider.of<TransactionFilterProvider>(
        // ignore: use_build_context_synchronously
        context,
        listen: false,
      ).setType('payment'); // Filtra por abonos
    }

    //
    // Creamos los stat cards
    final statClientes = _StatCard(
      label: 'Clientes', // Título del statcard
      value: totalClients.toString(), // Valor: cantidad de clientes
      icon: Icons.people, // Icono de personas
      isButton: true, // Es un botón
      onTap: goToClientsTab, // CORREGIDO: de onTab a onTap
    );
    final statDeuda = _StatCard(
      label: 'Deuda total', // Título del statcard
      value: getFormattedAmount(totalDeuda), // Valor: total de deuda
      subValue: getCurrencySymbol(), // Símbolo de moneda en línea aparte
      icon: Icons.trending_up, // Icono de tendencia hacia arriba
      color: Colors.red, // Color rojo
      isButton: true, // Es un botón
      onTap: goToDeudaTab, // Acción al pulsar
      // Padding personalizado: puedes ajustar cada lado de forma independiente
      contentPadding: const EdgeInsets.fromLTRB(
        16.0, // padding izquierdo
        25.0, // padding superior
        16.0, // padding derecho
        5.0, // padding inferior
      ),
    );
    final statAbonado = _StatCard(
      label: 'Total abonado', // Título del statcard
      value: getFormattedAmount(totalAbonado), // Valor: total abonado
      subValue: getCurrencySymbol(), // Símbolo de moneda en línea aparte
      icon: Icons.trending_down, // Icono de tendencia hacia abajo
      color: Colors.green, // Color verde
      isButton: true, // Es un botón
      onTap: goToAbonoTab, // Acción al pulsar
      // Padding personalizado: puedes ajustar cada lado de forma independiente
      contentPadding: const EdgeInsets.fromLTRB(
        16.0, // padding izquierdo
        25.0, // padding superior
        16.0, // padding derecho
        5.0, // padding inferior
      ),
    );
    // StatCard Clientes con deudas (balance < 0)
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
  final String? subValue;
  final IconData icon;
  final Color? color;
  final bool isButton;
  final VoidCallback? onTap;
  final EdgeInsets? contentPadding;
  const _StatCard({
    required this.label,
    required this.value,
    this.subValue,
    required this.icon,
    this.color,
    this.isButton = false,
    this.onTap,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    // Fondo translúcido y borde blanco más notorio para resaltar sobre el fondo degradado
    final cardColor = Color.fromARGB((0.10 * 255).round(), 255, 255, 255);
    final borderColor = Color.fromARGB(
      (0.65 * 255).round(),
      255,
      255,
      255,
    ); // Más visible
    final glowColor = Color.fromARGB(
      (0.18 * 255).round(),
      255,
      255,
      255,
    ); // Efecto de brillo
    // Ajustes de layout para que el texto del label nunca se corte ni salte de línea innecesariamente:
    // - Se usa un layout flexible y padding reducido
    // - El label se ajusta a una sola línea si cabe, o máximo dos líneas sin cortar palabras
    // - El ancho máximo del label depende del ancho real del statcard
    final cardContent = Padding(
      padding:
          contentPadding ?? const EdgeInsets.fromLTRB(16.0, 25.0, 16.0, 5.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Color.fromARGB((0.25 * 255).round(), 255, 255, 255),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: color ?? Colors.white,
              size: 28,
              shadows: const [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Columna para el valor principal y el símbolo de la moneda
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    letterSpacing: 0.5,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (subValue != null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                  ), // Padding superior eliminado para juntar el símbolo al monto
                  child: Text(
                    subValue!,
                    style: TextStyle(
                      fontSize: 13, // Tamaño de fuente reducido
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          // SizedBox eliminado para juntar el título al símbolo
          LayoutBuilder(
            builder: (context, constraints) {
              final maxLabelWidth = constraints.maxWidth;
              return Container(
                width: double.infinity,
                alignment: Alignment.center,
                constraints: BoxConstraints(
                  minHeight: 10, // Altura mínima aún más reducida para el label
                  minWidth: 0,
                  maxWidth: maxLabelWidth,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color.fromARGB(255, 252, 252, 252),
                      height: 1.05, // Reduce el espacio entre líneas
                      shadows: [
                        Shadow(
                          color: Color.fromARGB(0, 0, 0, 0),
                          offset: Offset(0, 2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    softWrap: true,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: borderColor, width: 2.2), // Borde más grueso
    );
    if (isButton) {
      return ScaleOnTap(
        onTap: onTap ?? () {},
        child: Card(
          elevation: 8,
          shape: cardShape,
          color: cardColor,
          shadowColor: Color.fromARGB((0.08 * 255).round(), 0, 0, 0),
          child: cardContent,
        ),
      );
    } else {
      return Card(
        color: cardColor,
        shape: cardShape,
        elevation: 8,
        shadowColor: Color.fromARGB((0.08 * 255).round(), 0, 0, 0),
        child: cardContent,
      );
    }
  }
}

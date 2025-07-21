import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client.dart';
import '../providers/client_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/transaction_provider.dart';
import '../utils/currency_utils.dart';
import '../utils/no_scrollbar_behavior.dart';
import '../widgets/cyclic_animated_fade_list.dart';
import '../widgets/dashboard_stats.dart';
import '../widgets/sync_banner.dart';
import '../services/supabase_service.dart';

// Para kIsWeb
class DashboardScreen extends StatefulWidget {
  final String userId;
  const DashboardScreen({super.key, required this.userId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  void _showRateDialog(BuildContext context, double initialRate) {
    final TextEditingController rateController = TextEditingController(
      text: initialRate.toString(),
    );
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Registrar tasa USD'),
          content: TextField(
            controller: rateController,
            decoration: const InputDecoration(
              labelText: 'Tasa USD',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final rate =
                    double.tryParse(rateController.text.replaceAll(',', '.')) ??
                    1.0;
                if (ctx.mounted) {
                  Provider.of<CurrencyProvider>(
                    ctx,
                    listen: false,
                  ).setRate(rate);
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Registrar'),
            ),
          ],
        );
      },
    );
  }

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Inicializa el estado de SyncProvider para que el banner se muestre correctamente
    Future.microtask(() {
      Provider.of<SyncProvider>(
        context,
        listen: false,
      ).initializeConnectionStatus();
    });
    // Comprobar diferencias de balance tras cargar datos
    Future.delayed(const Duration(milliseconds: 800), _checkBalanceDifferences);
  }

  // Compara balances locales y remotos y muestra SnackBar si hay diferencias
  Future<void> _checkBalanceDifferences() async {
    final clientProvider = Provider.of<ClientProvider>(context, listen: false);
    final localClients = clientProvider.clients;
    try {
      // Asume que tienes un método en SupabaseService para obtener clientes remotos
      final supabaseService = SupabaseService();
      final remoteClients = await supabaseService.fetchClients(widget.userId);
      // Mapear por id para comparar
      final localMap = {for (var c in localClients) c.id: c};
      final remoteMap = {for (var c in remoteClients) c.id: c};
      bool difference = false;
      for (final id in localMap.keys) {
        if (remoteMap.containsKey(id)) {
          final localBal = localMap[id]!.balance;
          final remoteBal = remoteMap[id]!.balance;
          if ((localBal - remoteBal).abs() > 0.01) {
            difference = true;
            break;
          }
        }
      }
      if (difference && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '¡Atención! Hay diferencias entre los balances locales y online.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            duration: const Duration(minutes: 5),
            action: SnackBarAction(
              label: 'X',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
              textColor: Colors.white,
            ),
            backgroundColor: Colors.deepOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Silenciar error si no hay conexión o método no implementado
    }
  }

  Future<void> _loadData() async {
    final clientProvider = Provider.of<ClientProvider>(context, listen: false);
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    await clientProvider.loadClients(widget.userId);
    await txProvider.loadTransactions(widget.userId);
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final clients = context.watch<ClientProvider>().clients;
    final transactions = context.watch<TransactionProvider>().transactions;
    final recentTransactions = List.of(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    final recent = recentTransactions.take(10).toList();

    // Obtener usuario actual de Supabase o modo offline
    final user = Supabase.instance.client.auth.currentUser;
    String userName = '';
    if (user != null) {
      final meta = user.userMetadata;
      if (meta != null &&
          meta['name'] != null &&
          (meta['name'] as String).trim().isNotEmpty) {
        userName = (meta['name'] as String)
            .trim()
            .split(' ')
            .map(
              (w) => w.isNotEmpty
                  ? w[0].toUpperCase() + w.substring(1).toLowerCase()
                  : '',
            )
            .join(' ');
      } else if (user.email != null) {
        final emailName = user.email!.split('@')[0];
        userName = emailName.isNotEmpty
            ? emailName[0].toUpperCase() + emailName.substring(1)
            : '';
      }
    } else {
      userName = 'Invitado';
    }

    String saludo() {
      final hour = DateTime.now().hour;
      if (hour >= 5 && hour < 12) return 'Buenos días';
      if (hour >= 12 && hour < 19) return 'Buenas tardes';
      return 'Buenas noches';
    }

    final isMobile =
        Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      drawer: isMobile
          ? Drawer(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DrawerHeader(
                      decoration: const BoxDecoration(
                        color: Color.fromARGB(221, 240, 25, 13),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.account_circle_rounded,
                            color: Color.fromARGB(255, 233, 27, 27),
                            size: 64,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            userName.isNotEmpty ? userName : 'Usuario',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.attach_money_rounded),
                      title: Consumer<CurrencyProvider>(
                        builder: (context, currencyProvider, _) => Row(
                          children: [
                            Switch(
                              value: currencyProvider.currency == 'USD',
                              onChanged: (val) {
                                if (val) {
                                  currencyProvider.setCurrency('USD');
                                  Future.delayed(
                                    const Duration(milliseconds: 200),
                                    () {
                                      if (mounted) {
                                        _showRateDialog(
                                          context,
                                          currencyProvider.rate,
                                        );
                                      }
                                    },
                                  );
                                } else {
                                  currencyProvider.setCurrency('VES');
                                }
                              },
                            ),
                            const Text('USD'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF7C3AED), // Morado principal (igual que login)
              Color(0xFF4F46E5), // Azul/morado
              Color(0xFF60A5FA), // Azul claro
            ],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ScrollConfiguration(
                behavior: const NoScrollbarBehavior(),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header translúcido con degradado y saludo
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((0.10 * 255).toInt()),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(32),
                            bottomRight: Radius.circular(32),
                          ),
                          border: Border.all(
                            color: Colors.white.withAlpha((0.07 * 255).toInt()),
                            width: 2.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withAlpha(
                                (0.12 * 255).toInt(),
                              ),
                              blurRadius: 16,
                              spreadRadius: 2,
                              offset: const Offset(0, 2),
                            ),
                            BoxShadow(
                              color: Colors.black.withAlpha(
                                (0.04 * 255).toInt(),
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Eliminado círculo decorativo superior derecho
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 24),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Transform.translate(
                                      offset: const Offset(0, -8),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color.fromARGB(
                                            255,
                                            251,
                                            250,
                                            250,
                                          ).withAlpha((0.25 * 255).toInt()),
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        child: const Icon(
                                          Icons.account_circle_rounded,
                                          color: Color.fromARGB(
                                            255,
                                            248,
                                            246,
                                            248,
                                          ),
                                          size: 48,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 8),
                                          Text(
                                            userName.isNotEmpty
                                                ? '${saludo()}, $userName'
                                                : saludo(),
                                            style: const TextStyle(
                                              color: Color.fromARGB(
                                                255,
                                                255,
                                                255,
                                                255,
                                              ),
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                              shadows: [
                                                Shadow(
                                                  color: Color.fromARGB(
                                                    0,
                                                    247,
                                                    246,
                                                    246,
                                                  ),
                                                  offset: Offset(0, 0),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [SyncBanner()],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 16,
                        ),
                        child: Consumer<ClientProvider>(
                          builder: (context, clientProvider, _) =>
                              DashboardStats(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Movimientos recientes',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color.fromARGB(255, 241, 240, 243),
                                shadows: [
                                  Shadow(
                                    color: Color.fromARGB(0, 255, 255, 255),
                                    offset: Offset(0, 0),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (recent.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'No hay movimientos registrados aún',
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 245, 243, 243),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                    shadows: [
                                      Shadow(
                                        color: Color.fromARGB(0, 255, 255, 255),
                                        offset: Offset(0, 0),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Consumer<CurrencyProvider>(
                                builder: (context, currencyProvider, _) {
                                  return CyclicAnimatedFadeList(
                                    interval: const Duration(
                                      milliseconds: 2000,
                                    ),
                                    animationDuration: const Duration(
                                      milliseconds: 8000,
                                    ),
                                    minOpacity: 0.25,
                                    itemSpacing: 10.0,
                                    children: recent.map((tx) {
                                      final client = clients.firstWhere(
                                        (c) => c.id == tx.clientId,
                                        orElse: () => Client(
                                          id: '',
                                          name: '',
                                          balance: 0,
                                        ),
                                      );
                                      final clientName = client.name.isNotEmpty
                                          ? client.name
                                          : 'Desconocido';
                                      final symbol = CurrencyUtils.symbol(
                                        context,
                                      );
                                      final formatted = CurrencyUtils.format(
                                        context,
                                        tx.amount,
                                      );
                                      final amountText = tx.type == 'debt'
                                          ? '-$symbol$formatted'
                                          : '+$symbol$formatted';
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(
                                            (0.85 * 255).toInt(),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(
                                                (0.04 * 255).toInt(),
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 8,
                                              ),
                                          leading: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: tx.type == 'debt'
                                                  ? const Color(0xFFFFE5E5)
                                                  : const Color(0xFFE5FFE8),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              tx.type == 'debt'
                                                  ? Icons.arrow_downward_rounded
                                                  : Icons.arrow_upward_rounded,
                                              color: tx.type == 'debt'
                                                  ? const Color(0xFFD32F2F)
                                                  : const Color(0xFF388E3C),
                                              size: 28,
                                            ),
                                          ),
                                          title: Text(
                                            tx.description,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              color: Colors.deepPurple,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.white,
                                                  offset: Offset(0, 0),
                                                  blurRadius: 6,
                                                ),
                                              ],
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Cliente: $clientName',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF7B7B7B),
                                            ),
                                          ),
                                          trailing: Text(
                                            amountText,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: tx.type == 'debt'
                                                  ? const Color(0xFFD32F2F)
                                                  : const Color(0xFF388E3C),
                                              shadows: const [
                                                Shadow(
                                                  color: Colors.white,
                                                  offset: Offset(0, 0),
                                                  blurRadius: 6,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

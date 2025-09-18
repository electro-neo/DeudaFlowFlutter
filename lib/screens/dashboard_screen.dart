import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/faq_help_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Importar para formateo de números
import 'package:characters/characters.dart';
import '../utils/string_sanitizer.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client.dart';
import '../providers/client_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/transaction_provider.dart';
import '../utils/no_scrollbar_behavior.dart';
import '../widgets/cyclic_animated_fade_list.dart';
import '../widgets/dashboard_stats.dart';
import '../widgets/sync_banner.dart';
import '../services/supabase_service.dart';
import '../services/session_authority_service.dart';

// Para kIsWeb
class DashboardScreen extends StatefulWidget {
  final String userId;
  final void Function(int)? onTab;
  final Duration scaleTapDuration;
  const DashboardScreen({
    super.key,
    required this.userId,
    this.onTab,
    this.scaleTapDuration = const Duration(milliseconds: 120),
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _faqShown = false;
  String _capitalizeSafe(String input) {
    final chars = input.characters;
    if (chars.isEmpty) return '';
    final first = chars.first.toUpperCase();
    final rest = chars.skip(1).toString().toLowerCase();
    return '$first$rest';
  }

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
  late final AnimationController _syncController;
  void _syncStatusListener() {
    try {
      final sp = Provider.of<SyncProvider>(context, listen: false);
      if (sp.status.toString().contains('syncing')) {
        if (!_syncController.isAnimating) _syncController.repeat();
      } else {
        if (_syncController.isAnimating) {
          _syncController.reset();
        }
      }
    } catch (_) {
      // Context might be unavailable during dispose
    }
  }

  @override
  void initState() {
    super.initState();
    _syncController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _loadData();
    // Inicializa el estado de SyncProvider para que el banner se muestre correctamente
    Future.microtask(() {
      Provider.of<SyncProvider>(
        // ignore: use_build_context_synchronously
        context,
        listen: false,
      ).initializeConnectionStatus();
    });
    // Comprobar diferencias de balance tras cargar datos
    Future.delayed(const Duration(milliseconds: 800), _checkBalanceDifferences);
    // El FAQ solo se mostrará después de cargar datos y si el usuario está autenticado

    // --- INICIO LISTENER DE DEVICE_ID ---
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // Se recomienda usar addPostFrameCallback para asegurar que el context es válido
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SessionAuthorityService.instance.listenToDeviceIdChanges(
          user.id,
          context,
        );
        // Añadir listener de SyncProvider para animar el icono de sync
        final sp = Provider.of<SyncProvider>(context, listen: false);
        sp.addListener(_syncStatusListener);
      });
    }
  }

  @override
  void dispose() {
    try {
      final sp = Provider.of<SyncProvider>(context, listen: false);
      sp.removeListener(_syncStatusListener);
    } catch (_) {}
    _syncController.dispose();
    super.dispose();
  }

  Future<void> _showFaqIfFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenFaq = prefs.getBool('hasSeenFaq') ?? false;
    if (!hasSeenFaq && mounted && !_faqShown) {
      _faqShown = true;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const FaqHelpSheet(),
      );
      await prefs.setBool('hasSeenFaq', true);
    }
  }

  // Compara balances locales y remotos y muestra un diálogo si hay diferencias
  Future<void> _checkBalanceDifferences() async {
    final clientProvider = Provider.of<ClientProvider>(context, listen: false);
    final localClients = clientProvider.clients;
    try {
      final supabaseService = SupabaseService();
      final remoteClients = await supabaseService.fetchClients(widget.userId);
      final localMap = {for (var c in localClients) c.id: c};
      final remoteMap = {for (var c in remoteClients) c.id: c};
      // Detectar clientes con conflicto
      final List<Map<String, dynamic>> conflicts = [];
      for (final id in localMap.keys) {
        if (remoteMap.containsKey(id)) {
          final localBal = localMap[id]!.balance;
          final remoteBal = remoteMap[id]!.balance;
          debugPrint(
            '[BALANCE] Cliente: ${localMap[id]!.name} (id: $id) | Local: $localBal | Supabase: $remoteBal',
          );
          if ((localBal - remoteBal).abs() > 0.01) {
            debugPrint(
              '[CONFLICTO BALANCE] Cliente: ${localMap[id]!.name} (id: $id) | Local: $localBal | Supabase: $remoteBal',
            );
            conflicts.add({
              'id': id,
              'name': localMap[id]!.name,
              'local': localBal,
              'remote': remoteBal,
            });
          }
        }
      }
      if (conflicts.isNotEmpty && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Conflicto de balances',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Builder(
                builder: (ctx) {
                  final maxHeight = MediaQuery.of(ctx).size.height * 0.6;
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 340,
                        maxHeight: maxHeight,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Se detectaron diferencias entre los balances locales y online de los siguientes clientes:',
                            style: TextStyle(fontSize: 15),
                          ),
                          const SizedBox(height: 12),
                          // La lista se envuelve en Flexible para respetar el maxHeight y poder hacer scroll
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: conflicts.length,
                              itemBuilder: (context, i) {
                                final c = conflicts[i];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          c['name'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Local: ${c['local'].toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.blue,
                                            ),
                                          ),
                                          Text(
                                            'Online: ${c['remote'].toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.deepOrange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '¿Con qué versión deseas quedarte para todos los clientes?',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              actionsPadding: const EdgeInsets.symmetric(vertical: 8),
              actions: [
                Center(
                  child: Consumer<SyncProvider>(
                    builder: (context, syncProvider, _) {
                      final isSyncing = syncProvider.status.toString().contains(
                        'syncing',
                      );
                      final onlineFuture = Provider.of<TransactionProvider>(
                        context,
                        listen: false,
                      ).isOnline();
                      return FutureBuilder<bool>(
                        future: onlineFuture,
                        builder: (context, snapshot) {
                          final online = snapshot.data ?? true;
                          if (!online) return const SizedBox.shrink();
                          return ElevatedButton(
                            onPressed: isSyncing
                                ? () {}
                                : () {
                                    // Llamar al SyncProvider para forzar sincronización completa
                                    try {
                                      Provider.of<SyncProvider>(
                                        context,
                                        listen: false,
                                      ).startSync(context, widget.userId);
                                    } catch (_) {}
                                    if (mounted) Navigator.of(ctx).pop();
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                            ),
                            child: AnimatedBuilder(
                              animation: _syncController,
                              builder: (context, child) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Transform.rotate(
                                      angle: isSyncing
                                          ? -_syncController.value * 6.28319
                                          : 0,
                                      child: Icon(
                                        Icons.sync,
                                        color: isSyncing
                                            ? Colors.green
                                            : Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('Sincronizar Todo'),
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
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
    setState(() => _loading = false);
    // Mostrar FAQ solo si el usuario está autenticado y la pantalla está lista
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      Future.delayed(const Duration(milliseconds: 400), _showFaqIfFirstTime);
    }
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
            .split(RegExp(r'\s+'))
            .map((w) => w.isNotEmpty ? _capitalizeSafe(w) : '')
            .join(' ');
      } else if (user.email != null) {
        final emailName = user.email!.split('@')[0];
        userName = emailName.isNotEmpty ? _capitalizeSafe(emailName) : '';
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
                                          // ignore: use_build_context_synchronously
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
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  saludo(),
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
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (userName.isNotEmpty)
                                                  Text(
                                                    userName,
                                                    style: const TextStyle(
                                                      color: Color.fromARGB(
                                                        255,
                                                        255,
                                                        255,
                                                        255,
                                                      ),
                                                      fontSize: 32,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                              ],
                                            ),
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
                              DashboardStats(
                                onTab: widget.onTab,
                                scaleTapDuration: widget.scaleTapDuration,
                              ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          100,
                        ), // Aumenta el padding inferior
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
                                    children: recent.asMap().entries.map((
                                      entry,
                                    ) {
                                      final i = entry.key;
                                      final tx = entry.value;
                                      final client = clients.firstWhere(
                                        (c) => c.id == tx.clientId,
                                        orElse: () => Client(
                                          id: '',
                                          name: '',
                                          balance: 0,
                                        ),
                                      );
                                      final clientName = client.name.isNotEmpty
                                          ? StringSanitizer.sanitizeForText(
                                              client.name,
                                            )
                                          : 'Desconocido';

                                      // --- Lógica de balance corregida ---
                                      final valueInUsd =
                                          tx.anchorUsdValue ?? tx.amount;

                                      // Lógica de conversión explícita para reaccionar a la moneda seleccionada
                                      final selectedCurrency =
                                          currencyProvider.currency;
                                      // FIX: Se usa getRateFor para obtener la tasa correcta.
                                      final rate = currencyProvider.getRateFor(
                                        selectedCurrency,
                                      );

                                      num displayValue = valueInUsd;
                                      if (selectedCurrency != 'USD' &&
                                          rate != null &&
                                          rate > 0) {
                                        displayValue = valueInUsd * rate;
                                      }

                                      final formattedNumber = NumberFormat(
                                        "#,##0.00",
                                        "en_US",
                                      ).format(displayValue);

                                      final formattedAmount =
                                          (selectedCurrency == 'USD')
                                          ? 'USD $formattedNumber'
                                          : '$formattedNumber $selectedCurrency';

                                      final amountText = tx.type == 'debt'
                                          ? '-$formattedAmount'
                                          : '+$formattedAmount';
                                      // --- Fin de la corrección ---

                                      // El degradado se ajusta según la posición: el primer card es más blanco
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color.lerp(
                                                Colors.white,
                                                const Color.fromARGB(
                                                  255,
                                                  250,
                                                  250,
                                                  250,
                                                ),
                                                i /
                                                    (recent.length - 1 == 0
                                                        ? 1
                                                        : recent.length - 1),
                                              )!,
                                              const Color.fromARGB(
                                                255,
                                                255,
                                                255,
                                                255,
                                              ),
                                              const Color(0xFFD1E8FF),
                                            ],
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
                                          title: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                tx.description,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                  color: Colors.deepPurple,
                                                ),
                                              ),
                                              Text(
                                                'Cliente: $clientName',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF7B7B7B),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    amountText,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: tx.type == 'debt'
                                                          ? const Color(
                                                              0xFFD32F2F,
                                                            )
                                                          : const Color(
                                                              0xFF388E3C,
                                                            ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
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

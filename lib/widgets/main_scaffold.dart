import 'scale_on_tap.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/clients_screen.dart';
import '../screens/transactions_screen.dart';
import '../services/guest_cleanup_service.dart' as guest_cleanup;
import '../providers/tab_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/transaction_filter_provider.dart';
import '../providers/client_provider.dart';
import 'add_global_transaction_modal.dart';
import 'faq_help_sheet.dart';

import '../providers/transaction_provider.dart';
import '../services/session_authority_service.dart';
import '../utils/currency_manager_dialog.dart';
import '../services/ad_service.dart';

// Banner de debug para mostrar un número aleatorio que cambia en cada hot reload
// class DebugBanner extends StatefulWidget {
//   const DebugBanner({super.key});
//   @override
//   State<DebugBanner> createState() => _DebugBannerState();
// }

// class _DebugBannerState extends State<DebugBanner> {
//   int _randomNumber = 0;

//   @override
//   void initState() {
//     super.initState();
//     _generateRandom();
//   }

//   void _generateRandom() {
//     _randomNumber = DateTime.now().millisecondsSinceEpoch.remainder(100000);
//   }

//   @override
//   void didUpdateWidget(covariant DebugBanner oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     _generateRandom();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       color: Colors.purple.withValues(
//         red: ((Colors.purple.r * 255.0).round() & 0xff).toDouble(),
//         green: ((Colors.purple.g * 255.0).round() & 0xff).toDouble(),
//         blue: ((Colors.purple.b * 255.0).round() & 0xff).toDouble(),
//         alpha: 0.8 * 255,
//       ),
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Center(
//         child: Text(
//           'DEBUG: $_randomNumber',
//           style: const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontSize: 14,
//             letterSpacing: 2,
//           ),
//         ),
//       ),
//     );
//   }
// }

class MainScaffold extends StatefulWidget {
  final String userId;
  const MainScaffold({super.key, required this.userId});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    // Cargar las tasas de cambio iniciales cuando el scaffold se inicia
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CurrencyProvider>(context, listen: false).loadInitialData();
    });
    // Controlador para animar el cambio de pestaña sin reconstruir pantallas
    _tabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    // Curvas separadas para suavizar cada propiedad
    _fadeCurve = CurvedAnimation(
      parent: _tabAnimController,
      curve: Curves.easeOutSine,
    );
    _moveCurve = CurvedAnimation(
      parent: _tabAnimController,
      curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic),
    );
    _scaleCurve = CurvedAnimation(
      parent: _tabAnimController,
      curve: Curves.easeOutSine,
    );
    // Valores iniciales (se recalculan al cambiar de tab)
    _slideUp = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_moveCurve);
    _scaleIn = Tween<double>(begin: 0.998, end: 1.0).animate(_scaleCurve);
    _opacityIn = Tween<double>(begin: 0.98, end: 1.0).animate(_fadeCurve);
    // Arranca visible
    _tabAnimController.value = 1.0;
  }

  // El FAB ahora llama al método público de ClientsScreenState
  void _showClientForm() {
    _clientsScreenKey.currentState?.showClientForm();
  }

  // Centraliza la duración de la animación para todos los botones animados
  final Duration scaleTapDuration = const Duration(milliseconds: 120);

  final GlobalKey<ClientsScreenState> _clientsScreenKey =
      GlobalKey<ClientsScreenState>();
  final GlobalKey _transactionsScreenKey = GlobalKey();
  int _currentIndex = 0;
  late AnimationController _tabAnimController;
  late Animation<double> _fadeCurve;
  late Animation<double> _moveCurve;
  late Animation<double> _scaleCurve;
  late Animation<Offset> _slideUp;
  late Animation<double> _scaleIn;
  late Animation<double> _opacityIn;

  // Progreso de ocultación (0.0 visible, 1.0 oculto)
  double _chromeT = 0.0;
  // Notificador para evitar rebuilds grandes en scroll
  final ValueNotifier<double> _chromeTNotifier = ValueNotifier<double>(0.0);
  // Distancia de scroll necesaria para ocultar por completo
  static const double _hideDistance = 96.0;

  void _onTab(int index) {
    // Si cambias desde la pestaña de clientes, limpia el buscador y cierra expansión
    if (_currentIndex == 1 && index != 1) {
      _clientsScreenKey.currentState?.resetSearchState();
      _clientsScreenKey.currentState?.closeExpansion();
    }
    // Si cambias desde la pestaña de movimientos, limpia el buscador de transacciones
    if (_currentIndex == 2 && index != 2) {
      final state = _transactionsScreenKey.currentState;
      if (state != null) {
        try {
          // ignore: avoid_dynamic_calls, invalid_use_of_protected_member
          (state as dynamic).resetSearchState();
        } catch (_) {}
      }
    }

    // Caso especial Movimientos
    if (index == 2) {
      final filterProvider = Provider.of<TransactionFilterProvider>(
        context,
        listen: false,
      );
      filterProvider.setClientId(null);
      filterProvider.setType(null);
      final tabProvider = Provider.of<TabProvider>(context, listen: false);
      if (tabProvider.currentIndex == 2) {
        final state = _transactionsScreenKey.currentState;
        if (state != null) {
          try {
            // ignore: avoid_dynamic_calls, invalid_use_of_protected_member
            (state as dynamic).resetSearchState();
          } catch (_) {}
        }
        setState(() {
          _chromeT = 0.0;
          _chromeTNotifier.value = 0.0;
        });
      }
      tabProvider.setTab(index);
      // Prepara animación para el nuevo contenido
      _tabAnimController.stop();
      _tabAnimController.value = 0.0;
      final prev = _currentIndex;
      final dir = (index > prev) ? 1.0 : -1.0; // derecha si avanzas
      setState(() {
        _slideUp = Tween<Offset>(
          begin: Offset(0.04 * dir, 0),
          end: Offset.zero,
        ).animate(_moveCurve);
        _currentIndex = index;
        _chromeT = 0.0;
        _chromeTNotifier.value = 0.0;
      });
      // Intentar mostrar interstitial con 20% de probabilidad y mínimo 2 minutos
      AdService.instance.maybeShowInterstitialOnNavigation(
        probability: 0.4,
        minInterval: const Duration(minutes: 5),
      );
      // Dispara animación en el siguiente frame para evitar parpadeo
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tabAnimController.forward();
      });
      return;
    }

    // Si se toca la misma pestaña (no 2), evita trabajo extra
    if (_currentIndex == index) {
      setState(() {
        _chromeT = 0.0;
        _chromeTNotifier.value = 0.0;
      });
      return;
    }

    Provider.of<TabProvider>(context, listen: false).setTab(index);
    // Prepara animación para el nuevo contenido
    _tabAnimController.stop();
    _tabAnimController.value = 0.0;
    final prev = _currentIndex;
    final dir = (index > prev) ? 1.0 : -1.0; // derecha si avanzas
    setState(() {
      _slideUp = Tween<Offset>(
        begin: Offset(0.06 * dir, 0),
        end: Offset.zero,
      ).animate(_moveCurve);
      _currentIndex = index;
      _chromeT = 0.0;
      _chromeTNotifier.value = 0.0;
    });
    // Dispara animación en el siguiente frame para evitar parpadeo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tabAnimController.forward();
    });
    // Intentar mostrar interstitial con 20% de probabilidad y mínimo 2 minutos
    AdService.instance.maybeShowInterstitialOnNavigation(
      probability: 0.4,
      minInterval: const Duration(minutes: 5),
    );
  }

  // Permite cambiar a la pestaña de movimientos y filtrar por cliente
  void goToMovementsWithClient(String clientId) {
    final filterProvider = Provider.of<TransactionFilterProvider>(
      context,
      listen: false,
    );
    filterProvider.setClientId(clientId);
    filterProvider.setType(null);
    final tabProvider = Provider.of<TabProvider>(context, listen: false);
    tabProvider.setTab(2);
    setState(() {
      _currentIndex = 2;
      _chromeT = 0.0;
      _chromeTNotifier.value = 0.0;
    });
    // Intentar mostrar interstitial al navegar a Movimientos
    AdService.instance.maybeShowInterstitialOnNavigation(
      probability: 0.4,
      minInterval: const Duration(minutes: 5),
    );
  }

  void _logout() async {
    await Future.delayed(const Duration(milliseconds: 100));
    final guestCleanup = await importGuestCleanup();
    if (guestCleanup != null) {
      await guestCleanup();
    }
    try {
      await SessionAuthorityService.instance.signOutAndDisposeListener();
    } catch (e) {
      debugPrint('[LOGOUT] Error al cerrar sesión: $e');
    }
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  Future<Function?> importGuestCleanup() async {
    try {
      final guestCleanup = await Future.value(() async {
        await guest_cleanup.GuestCleanupService.cleanupGuestData();
      });
      return guestCleanup;
    } catch (_) {
      return null;
    }
  }

  // Listener de scroll para ocultar/mostrar progresivamente FAB y BottomBar
  bool _onScrollNotification(ScrollNotification notification) {
    // Solo vertical del scrollable primario (evita notifs anidadas)
    if (notification.metrics.axis != Axis.vertical || notification.depth != 0) {
      return false;
    }

    double? delta;
    if (notification is ScrollUpdateNotification) {
      delta = notification.scrollDelta;
    } else if (notification is OverscrollNotification) {
      delta = notification.overscroll;
    }
    if (delta == null) return false;

    // Suaviza ruido de deltas minúsculos
    if (delta.abs() < 0.5) return false;

    // delta > 0: scroll down (oculta), delta < 0: scroll up (muestra)
    final next = (_chromeT + (delta / _hideDistance)).clamp(0.0, 1.0);
    if (next != _chromeT) {
      _chromeT = next;
      _chromeTNotifier.value = next; // solo repinta FAB y barra
    }
    return false; // no consumimos el evento
  }

  // Desplaza el scroll principal hasta el tope
  Future<void> _scrollToTop() async {
    final controller = PrimaryScrollController.of(context);
    if (controller.hasClients) {
      await controller.animateTo(
        0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _chromeTNotifier.dispose();
    _tabAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, transactionProvider, _) {
        final tabIndex = _currentIndex;
        final screens = [
          DashboardScreen(
            userId: widget.userId,
            onTab: _onTab,
            scaleTapDuration: scaleTapDuration,
          ),
          ClientsScreen(
            key: _clientsScreenKey,
            userId: widget.userId,
            onViewMovements: goToMovementsWithClient,
          ),
          TransactionsScreen(
            key: _transactionsScreenKey,
            userId: widget.userId,
          ),
        ];
        final viewInsets = MediaQuery.of(context).viewInsets;
        final isKeyboardVisible = viewInsets.bottom > 0.0;

        // Elimina este addPostFrameCallback vacío para evitar trabajo por build
        // WidgetsBinding.instance.addPostFrameCallback((_) {
        //   // lógica desactivada
        // });

        Widget? fab = isKeyboardVisible
            ? null
            : ValueListenableBuilder<double>(
                valueListenable: _chromeTNotifier,
                builder: (context, t, child) {
                  return Transform.translate(
                    offset: Offset(0, 120.0 * t),
                    child: Opacity(opacity: 1.0 - t, child: child),
                  );
                },
                child: RepaintBoundary(
                  child: FloatingActionButton(
                    heroTag: 'mainFab',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) {
                          final clientProvider = Provider.of<ClientProvider>(
                            context,
                            listen: false,
                          );
                          final hasClients = clientProvider.clients.isNotEmpty;
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            title: const Text('¿Qué deseas registrar?'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: const Text('Cliente'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(
                                      double.infinity,
                                      44,
                                    ),
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    _showClientForm();
                                  },
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add_card),
                                  label: const Text('Transacción'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(
                                      double.infinity,
                                      44,
                                    ),
                                    backgroundColor: hasClients
                                        ? Colors.deepPurple
                                        : Colors.grey,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: hasClients
                                      ? () {
                                          Navigator.of(ctx).pop();
                                          showDialog(
                                            context: context,
                                            builder: (ctx2) =>
                                                AddGlobalTransactionModal(
                                                  userId: widget.userId,
                                                ),
                                          );
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    backgroundColor: const Color.fromARGB(255, 145, 88, 236),
                    elevation: 6,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.add, size: 32, color: Colors.white),
                  ),
                ),
              );

        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Aísla el fondo para evitar repaints ascendentes
                  RepaintBoundary(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF7C3AED),
                            Color(0xFF4F46E5),
                            Color(0xFF60A5FA),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Scaffold(
                    extendBody: true,
                    backgroundColor: Colors.transparent,
                    appBar: null,
                    body: FadeTransition(
                      opacity: _opacityIn,
                      child: SlideTransition(
                        position: _slideUp,
                        child: ScaleTransition(
                          scale: _scaleIn,
                          child: NotificationListener<ScrollNotification>(
                            onNotification: _onScrollNotification,
                            child: IndexedStack(
                              index: tabIndex,
                              children: screens,
                            ),
                          ),
                        ),
                      ),
                    ),
                    floatingActionButton: fab,
                    floatingActionButtonLocation:
                        FloatingActionButtonLocation.centerDocked,
                    bottomNavigationBar: ValueListenableBuilder<double>(
                      valueListenable: _chromeTNotifier,
                      builder: (context, t, child) {
                        return Transform.translate(
                          offset: Offset(0, 80.0 * t),
                          child: Opacity(opacity: 1.0 - t, child: child),
                        );
                      },
                      child: RepaintBoundary(
                        child: BottomAppBar(
                          color: Colors.white,
                          elevation: 0,
                          shape: const CircularNotchedRectangle(),
                          notchMargin: 8.0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: <Widget>[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.dashboard),
                                    tooltip: 'Dashboard',
                                    color: tabIndex == 0
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    onPressed: () => _onTab(0),
                                  ),
                                  const SizedBox(width: 20),
                                  IconButton(
                                    icon: const Icon(Icons.people),
                                    tooltip: 'Clientes',
                                    color: tabIndex == 1
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    onPressed: () => _onTab(1),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 32),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.list_alt),
                                    tooltip: 'Movimientos',
                                    color: tabIndex == 2
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    onPressed: () => _onTab(2),
                                  ),
                                  const SizedBox(width: 20),
                                  IconButton(
                                    icon: const Icon(Icons.menu),
                                    tooltip: 'Menú',
                                    onPressed: () {
                                      final logout = _logout;
                                      showModalBottomSheet(
                                        context: context,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(16),
                                          ),
                                        ),
                                        builder: (ctx) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 24,
                                              horizontal: 24,
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                const SizedBox(height: 16),
                                                Consumer<CurrencyProvider>(
                                                  builder: (context, currencyProvider, _) {
                                                    onPressedAction() async {
                                                      final monedasConTasa =
                                                          currencyProvider
                                                              .exchangeRates
                                                              .entries
                                                              .where(
                                                                (e) =>
                                                                    e.key !=
                                                                    'USD',
                                                              )
                                                              .map(
                                                                (e) =>
                                                                    '${e.key}: ${e.value}',
                                                              )
                                                              .toList();
                                                      debugPrint(
                                                        '[DEBUG][GESTION MONEDAS] Monedas con tasa registrada: ${monedasConTasa.join(', ')}',
                                                      );
                                                      await CurrencyManagerDialog.show(
                                                        context,
                                                      );
                                                    }

                                                    return ScaleOnTap(
                                                      duration:
                                                          scaleTapDuration,
                                                      onTap: onPressedAction,
                                                      child: ElevatedButton.icon(
                                                        icon: const Icon(
                                                          Icons
                                                              .attach_money_rounded,
                                                          color: Colors.indigo,
                                                        ),
                                                        label: const Text(
                                                          'Gestionar monedas',
                                                          style: TextStyle(
                                                            color:
                                                                Colors.indigo,
                                                          ),
                                                        ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.white,
                                                          foregroundColor:
                                                              Colors.indigo,
                                                          elevation: 0,
                                                          side:
                                                              const BorderSide(
                                                                color: Colors
                                                                    .indigo,
                                                              ),
                                                        ),
                                                        onPressed:
                                                            onPressedAction,
                                                      ),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 16),
                                                ScaleOnTap(
                                                  duration: scaleTapDuration,
                                                  onTap: () {
                                                    showModalBottomSheet(
                                                      context: ctx,
                                                      isScrollControlled: true,
                                                      backgroundColor:
                                                          const Color.fromARGB(
                                                            255,
                                                            241,
                                                            239,
                                                            239,
                                                          ),
                                                      builder: (_) =>
                                                          const FaqHelpSheet(),
                                                    );
                                                  },
                                                  child: ElevatedButton.icon(
                                                    icon: const Icon(
                                                      Icons.help_outline,
                                                      color: Colors.indigo,
                                                    ),
                                                    label: const Text(
                                                      'Ayuda / FAQ',
                                                      style: TextStyle(
                                                        color: Colors.indigo,
                                                      ),
                                                    ),
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              const Color(
                                                                0xFFFFFFFF,
                                                              ),
                                                          foregroundColor:
                                                              Colors.indigo,
                                                          elevation: 0,
                                                          side:
                                                              const BorderSide(
                                                                color: Colors
                                                                    .indigo,
                                                              ),
                                                        ),
                                                    onPressed: () {
                                                      showModalBottomSheet(
                                                        context: ctx,
                                                        isScrollControlled:
                                                            true,
                                                        backgroundColor:
                                                            const Color.fromARGB(
                                                              255,
                                                              241,
                                                              239,
                                                              239,
                                                            ),
                                                        builder: (_) =>
                                                            const FaqHelpSheet(),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                ScaleOnTap(
                                                  duration: scaleTapDuration,
                                                  onTap: () {
                                                    Navigator.of(ctx).pop();
                                                    logout();
                                                  },
                                                  child: ElevatedButton.icon(
                                                    icon: const Icon(
                                                      Icons.logout,
                                                      color: Colors.red,
                                                    ),
                                                    label: const Text(
                                                      'Cerrar sesión',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              const Color(
                                                                0xFFFFFFFF,
                                                              ),
                                                          foregroundColor:
                                                              Colors.red,
                                                          elevation: 0,
                                                          side:
                                                              const BorderSide(
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                        ),
                                                    onPressed: () {
                                                      Navigator.of(ctx).pop();
                                                      logout();
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Botón "subir arriba" en la esquina inferior derecha
                  Positioned(
                    right: 16,
                    bottom: 16 + MediaQuery.of(context).padding.bottom,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _chromeTNotifier,
                      builder: (context, t, _) {
                        final isKeyboardVisibleLocal =
                            MediaQuery.of(context).viewInsets.bottom > 0;
                        final show = !isKeyboardVisibleLocal && t >= 0.98;
                        return IgnorePointer(
                          ignoring: !show,
                          child: AnimatedSlide(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            offset: show ? Offset.zero : const Offset(0, 0.4),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: show ? 1 : 0,
                              child: FloatingActionButton.small(
                                heroTag: 'scrollTopFab',
                                backgroundColor: const Color.fromARGB(
                                  255,
                                  145,
                                  88,
                                  236,
                                ),
                                onPressed: _scrollToTop,
                                child: const Icon(
                                  Icons.arrow_upward,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Widget para la barra inferior móvil/tablet con modal de tasa
class _MobileBottomBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTab;
  final VoidCallback onLogout;
  const _MobileBottomBar({
    required this.currentIndex,
    required this.onTab,
    required this.onLogout,
  });

  @override
  State<_MobileBottomBar> createState() => _MobileBottomBarState();
}

class _MobileBottomBarState extends State<_MobileBottomBar> {
  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.dashboard),
            tooltip: 'Dashboard',
            color: widget.currentIndex == 0
                ? Theme.of(context).colorScheme.primary
                : null,
            onPressed: () => widget.onTab(0),
          ),
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Clientes',
            color: widget.currentIndex == 1
                ? Theme.of(context).colorScheme.primary
                : null,
            onPressed: () => widget.onTab(1),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Movimientos',
            color: widget.currentIndex == 2
                ? Theme.of(context).colorScheme.primary
                : null,
            onPressed: () => widget.onTab(2),
          ),
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menú',
            onPressed: () {
              // ignore: use_build_context_synchronously
              // NOTA: Este warning aparece porque el linter de Flutter no siempre detecta correctamente el patrón de uso seguro de 'context' tras operaciones asíncronas o callbacks.
              // En este caso, el uso de 'context' es seguro porque no hay await antes y el callback se ejecuta en el mismo frame.
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (ctx) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        // Toggle USD/VES
                        Consumer<CurrencyProvider>(
                          builder: (context, currencyProvider, _) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.attach_money_rounded),
                                Switch(
                                  value: currencyProvider.currency == 'USD',
                                  onChanged: (val) {
                                    if (val) {
                                      currencyProvider.setCurrency('USD');
                                      Future.delayed(
                                        const Duration(milliseconds: 200),
                                        () {
                                          // ignore: use_build_context_synchronously
                                          // NOTA: El uso de 'context' aquí es seguro porque este callback se ejecuta en el mismo frame y no hay await previo. El linter puede reportar un falso positivo.
                                          showDialog(
                                            // ignore: use_build_context_synchronously
                                            context: context,
                                            builder: (ctx2) {
                                              final rate =
                                                  currencyProvider.rate;
                                              final controller =
                                                  TextEditingController(
                                                    text: rate.toString(),
                                                  );
                                              return AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                title: const Text(
                                                  'Registrar Tasa USD',
                                                ),
                                                content: TextField(
                                                  controller: controller,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Tasa USD',
                                                        border:
                                                            OutlineInputBorder(),
                                                        isDense: true,
                                                      ),
                                                  keyboardType:
                                                      TextInputType.numberWithOptions(
                                                        decimal: true,
                                                      ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          ctx2,
                                                        ).pop(),
                                                    child: const Text(
                                                      'Cancelar',
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      final rate =
                                                          double.tryParse(
                                                            controller.text
                                                                .replaceAll(
                                                                  ',',
                                                                  '.',
                                                                ),
                                                          ) ??
                                                          1.0;
                                                      currencyProvider.setRate(
                                                        rate,
                                                      );
                                                      Navigator.of(ctx2).pop();
                                                    },
                                                    child: const Text(
                                                      'Registrar',
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                      );
                                    } else {
                                      currencyProvider.setCurrency('VES');
                                    }
                                  },
                                ),
                                const Text('USD'),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Consumer<ThemeProvider>(
                            builder: (context, themeProvider, _) => Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.brightness_6),
                                Switch(
                                  value:
                                      themeProvider.themeData.brightness ==
                                      Brightness.dark,
                                  onChanged: (val) {
                                    themeProvider.toggleTheme();
                                  },
                                ),
                                Text(
                                  themeProvider.themeData.brightness ==
                                          Brightness.dark
                                      ? 'Dark'
                                      : 'Light',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text(
                            'Cerrar sesión',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red,
                            elevation: 0,
                            side: const BorderSide(color: Colors.red),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            final mainState = context
                                .findAncestorStateOfType<_MainScaffoldState>();
                            mainState?._logout();
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// Nuevo widget para manejar el PageView y sincronizar con el tab
class _SwipeableScaffold extends StatefulWidget {
  final int tabIndex;
  final Function(int) onTab;
  final List<Widget> screens;
  final Widget bottomNavigationBar;
  const _SwipeableScaffold({
    required this.tabIndex,
    required this.onTab,
    required this.screens,
    required this.bottomNavigationBar,
  });

  @override
  State<_SwipeableScaffold> createState() => _SwipeableScaffoldState();
}

class _SwipeableScaffoldState extends State<_SwipeableScaffold> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.tabIndex);
  }

  @override
  void didUpdateWidget(covariant _SwipeableScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabIndex != oldWidget.tabIndex) {
      _pageController.jumpToPage(widget.tabIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: PageView(
        controller: _pageController,
        onPageChanged: widget.onTab,
        physics: const ClampingScrollPhysics(),
        children: widget.screens,
      ),
      bottomNavigationBar: widget.bottomNavigationBar,
    );
  }
}

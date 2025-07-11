import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/dashboard_screen.dart';
import '../screens/clients_screen.dart';
import '../screens/transactions_screen.dart';
import 'app_navigation_bar.dart';
import '../services/guest_cleanup_service.dart' as guest_cleanup;
import '../providers/tab_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/currency_provider.dart';

class MainScaffold extends StatefulWidget {
  final String userId;
  const MainScaffold({super.key, required this.userId});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  // final ScrollController _scrollController = ScrollController(); // No se usa
  // El índice de tab ahora se gestiona por Provider
  void _onTab(int index) {
    Provider.of<TabProvider>(context, listen: false).setTab(index);
  }

  void _logout() async {
    // Limpieza de datos de invitado
    await Future.delayed(const Duration(milliseconds: 100));
    final guestCleanup = await importGuestCleanup();
    if (guestCleanup != null) {
      await guestCleanup();
    }
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  // Import dinámico para evitar problemas de dependencias circulares
  Future<Function?> importGuestCleanup() async {
    try {
      // ignore: import_of_legacy_library_into_null_safe
      final guestCleanup = await Future.value(() async {
        await guest_cleanup.GuestCleanupService.cleanupGuestData();
      });
      return guestCleanup;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = Provider.of<TabProvider>(context).currentIndex;
    final screens = [
      DashboardScreen(userId: widget.userId),
      ClientsScreen(userId: widget.userId),
      TransactionsScreen(userId: widget.userId),
    ];
    final width = MediaQuery.of(context).size.width;
    final isWeb = identical(0, 0.0);
    // Eliminar AppBar superior en todas las vistas principales
    if (isWeb && width >= 600) {
      return AppNavigationBar(
        currentIndex: tabIndex,
        onTap: _onTab,
        onLogout: _logout,
        child: Scaffold(appBar: null, body: screens[tabIndex]),
      );
    } else {
      // --- INICIO CAMBIO: PageView para swipe ---
      return _SwipeableScaffold(
        tabIndex: tabIndex,
        onTab: _onTab,
        screens: screens,
        bottomNavigationBar: _MobileBottomBar(
          currentIndex: tabIndex,
          onTab: _onTab,
          onLogout: () {},
        ),
      );
      // --- FIN CAMBIO ---
    }
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
                                          showDialog(
                                            context: context,
                                            builder: (ctx2) {
                                              final rate = currencyProvider.rate;
                                              final controller = TextEditingController(text: rate.toString());
                                              return AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                title: const Text('Registrar tasa USD'),
                                                content: TextField(
                                                  controller: controller,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Tasa USD',
                                                    border: OutlineInputBorder(),
                                                    isDense: true,
                                                  ),
                                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.of(ctx2).pop(),
                                                    child: const Text('Cancelar'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      final rate = double.tryParse(controller.text.replaceAll(',', '.')) ?? 1.0;
                                                      currencyProvider.setRate(rate);
                                                      Navigator.of(ctx2).pop();
                                                    },
                                                    child: const Text('Registrar'),
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
                                  value: themeProvider.isDarkMode,
                                  onChanged: (val) {
                                    themeProvider.toggleTheme(val);
                                  },
                                ),
                                Text(
                                  themeProvider.isDarkMode ? 'Dark' : 'Light',
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

import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../providers/theme_provider.dart';

class AppNavigationBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onLogout;
  final Widget child;
  const AppNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onLogout,
    required this.child,
  });

  @override
  State<AppNavigationBar> createState() => _AppNavigationBarState();
}

class _AppNavigationBarState extends State<AppNavigationBar> {
  bool _drawerOpen = false;
  TextEditingController? _rateController;

  @override
  void dispose() {
    _rateController?.dispose();
    super.dispose();
  }

  void _toggleDrawer() {
    setState(() {
      _drawerOpen = !_drawerOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final isWeb = kIsWeb;
    final width = MediaQuery.of(context).size.width;
    // Solo mostrar el menú hamburguesa en web escritorio (ancho >= 600)
    if (isWeb && width >= 600) {
      // Eliminar AppBar superior, solo mostrar el contenido principal y menú lateral si está abierto
      return Stack(
        children: [
          Positioned.fill(child: widget.child),
          Positioned(
            top: 16,
            right: 24,
            child: IconButton(
              icon: const Icon(Icons.menu, size: 32),
              tooltip: 'Menú',
              onPressed: _toggleDrawer,
            ),
          ),
          if (_drawerOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleDrawer,
                child: Container(),
              ),
            ),
          if (_drawerOpen)
            Positioned(
              top: 60,
              right: 24,
              child: Material(
                elevation: 16,
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).canvasColor,
                child: Container(
                  width: 260,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.dashboard),
                          title: const Text('Dashboard'),
                          selected: widget.currentIndex == 0,
                          onTap: () {
                            widget.onTap(0);
                            _toggleDrawer();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.people),
                          title: const Text('Clientes'),
                          selected: widget.currentIndex == 1,
                          onTap: () {
                            widget.onTap(1);
                            _toggleDrawer();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.list_alt),
                          title: const Text('Movimientos'),
                          selected: widget.currentIndex == 2,
                          onTap: () {
                            widget.onTap(2);
                            _toggleDrawer();
                          },
                        ),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              const Text('💱'),
                              Switch(
                                value: currencyProvider.currency == 'USD',
                                onChanged: (val) {
                                  currencyProvider.setCurrency(
                                    val ? 'USD' : 'VES',
                                  );
                                },
                              ),
                              const Text('USD'),
                            ],
                          ),
                        ),
                        if (currencyProvider.currency == 'USD')
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Builder(
                                    builder: (context) {
                                      if (_rateController == null ||
                                          _rateController!.text !=
                                              currencyProvider.rate
                                                  .toString()) {
                                        _rateController?.dispose();
                                        _rateController = TextEditingController(
                                          text: currencyProvider.rate
                                              .toString(),
                                        );
                                      }
                                      return TextField(
                                        decoration: const InputDecoration(
                                          hintText: 'Tasa',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 4,
                                          ),
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        controller: _rateController,
                                        onSubmitted: (val) {
                                          final rate =
                                              double.tryParse(
                                                val.replaceAll(',', '.'),
                                              ) ??
                                              1.0;
                                          currencyProvider.setRate(rate);
                                        },
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    final rate =
                                        double.tryParse(
                                          _rateController?.text.replaceAll(
                                                ',',
                                                '.',
                                              ) ??
                                              '',
                                        ) ??
                                        1.0;
                                    currencyProvider.setRate(rate);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    textStyle: const TextStyle(fontSize: 14),
                                  ),
                                  child: const Text('Registrar'),
                                ),
                              ],
                            ),
                          ),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          child: Consumer<ThemeProvider>(
                            builder: (context, themeProvider, _) => Row(
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
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text(
                            'Cerrar sesión',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () {
                            widget.onLogout();
                            _toggleDrawer();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    // En móvil/tablet/web reducido, solo muestra el contenido principal
    return widget.child;
  }
}

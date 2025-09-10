import 'dart:io';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/client_hive.dart';
import 'models/contact_hive.dart';
import 'models/transaction_hive.dart';

import 'providers/client_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/sync_provider.dart';

import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'supabase_keys.dart';
import 'widgets/main_scaffold.dart';
import 'providers/transaction_filter_provider.dart';
import 'providers/tab_provider.dart';
import 'providers/theme_provider.dart';
import 'widgets/budgeto_theme.dart';
import 'services/session_authority_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
String _initialRoute = '/'; // Se ajustará en _initializeApp según sesión

// Indicador interno para saber si ya intentamos restaurar sesión antes del árbol
bool _preBootRestored = false;

// ...eliminada duplicidad de _initializeApp...
Future<void> _initializeApp() async {
  try {
    debugPrint('Iniciando Supabase...');
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    debugPrint('Supabase inicializado');

    // Captura errores globales de Supabase y de Flutter
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('SocketException')) {
        debugPrint('Supabase offline: \n[${details.exception}]');
      } else {
        FlutterError.presentError(details);
      }
    };

    debugPrint('Iniciando Hive...');
    await Hive.initFlutter();
    debugPrint('Hive inicializado');
    Hive.registerAdapter(ClientHiveAdapter());
    Hive.registerAdapter(TransactionHiveAdapter());
    Hive.registerAdapter(ContactHiveAdapter());
    debugPrint('Adapters registrados');
    await Hive.openBox<ClientHive>('clients');
    debugPrint('Box clients abierto');
    await Hive.openBox<TransactionHive>('transactions');
    debugPrint('Box transactions abierto');
    await Hive.openBox<ContactHive>('contacts');
    debugPrint('Box contacts abierto');
    await Hive.openBox('user_settings');

    // Chequeo de conectividad rápido
    bool hasInternet = true;
    try {
      final r = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 2));
      hasInternet = r.isNotEmpty && r[0].rawAddress.isNotEmpty;
    } catch (_) {
      hasInternet = false;
    }
    // Restaurar sesión (si existe) antes de montar la UI
    try {
      await SessionAuthorityService.instance
          .restoreSessionIfNeeded(hasInternet: hasInternet)
          .timeout(const Duration(seconds: 3));
      _preBootRestored = true;
      debugPrint('[BOOT] Restauración previa completada');
    } catch (e) {
      debugPrint('[BOOT] Restauración previa falló: $e');
    }

    // Determinar initialRoute dinámicamente
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final clientsBox = Hive.box<ClientHive>('clients');
      final txBox = Hive.box<TransactionHive>('transactions');
      final hasLocalData = clientsBox.isNotEmpty || txBox.isNotEmpty;
      if (session != null) {
        _initialRoute = '/dashboard';
        debugPrint('[BOOT] initialRoute => /dashboard (sesión válida)');
      } else if (!hasInternet && hasLocalData) {
        // Modo offline permitido directo
        _initialRoute = '/dashboard';
        debugPrint(
          '[BOOT] initialRoute => /dashboard (offline con datos locales)',
        );
      } else {
        _initialRoute = '/';
        debugPrint('[BOOT] initialRoute => / (sin sesión)');
      }
    } catch (e) {
      debugPrint('[BOOT] No se pudo determinar initialRoute dinamica: $e');
    }

    runApp(const MyApp());
    debugPrint('runApp ejecutado');
  } catch (e, st) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Error de inicialización en móvil:\n$e')),
        ),
      ),
    );
    debugPrint('Error en inicialización: $e\n$st');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nota: No borres datos locales en cada arranque; esto elimina la sesión guardada (email)
  // y rompe el acceso offline. Deja esta función solo para migraciones/debug manuales.
  // await clearHiveData(); // SOLO usar manualmente si necesitas resetear Hive
  await _initializeApp();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _sub;
  AppLinks? _appLinks;
  // Splash overlay
  double _splashOpacity = 1.0;
  bool _splashRemoved = false;

  @override
  void initState() {
    super.initState();
    _handleIncomingLinks();
    // Programa el fade del overlay splash después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pequeña espera para asegurar que initialRoute ya montó su primer frame
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => _splashOpacity = 0.0);
        // Tras el fade, remover del árbol para no costar en composición
        Future.delayed(const Duration(milliseconds: 380), () {
          if (mounted) setState(() => _splashRemoved = true);
        });
      });
    });
  }

  void _handleIncomingLinks() {
    _appLinks = AppLinks();
    // Handle initial link (cold start)
    _appLinks!
        .getInitialLink()
        .then((uri) {
          if (uri != null &&
              uri.scheme == 'deudaflow' &&
              uri.host == 'reset-password') {
            navigatorKey.currentState?.pushNamed('/reset-password');
          }
        })
        .catchError((err) {
          debugPrint('Deep link initial error: $err');
          return null;
        });

    // Listen for subsequent links
    _sub = _appLinks!.uriLinkStream.listen(
      (Uri uri) {
        if (uri.scheme == 'deudaflow' && uri.host == 'reset-password') {
          navigatorKey.currentState?.pushNamed('/reset-password');
        }
      },
      onError: (err) {
        debugPrint('Deep link error: $err');
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _appLinks = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ClientProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
        ChangeNotifierProvider(create: (_) => TabProvider()),
        ChangeNotifierProvider(create: (_) => TransactionFilterProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Deuda Flow Control',
          theme: BudgetoTheme.light,
          initialRoute: _initialRoute,
          routes: {
            '/': (context) => const WelcomeScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/reset-password': (context) => const ResetPasswordScreen(),
            '/dashboard': (context) => const AuthGate(),
            '/clients': (context) => const AuthGate(),
            '/transactions': (context) => const AuthGate(),
          },
          builder: (context, child) {
            return Stack(
              children: [
                if (child != null) child,
                if (!_splashRemoved)
                  IgnorePointer(
                    ignoring: _splashOpacity == 0.0,
                    child: AnimatedOpacity(
                      opacity: _splashOpacity,
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
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
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              // Logo con fondo circular y sombra para asegurar contraste
                              SizedBox(height: 8),
                              Icon(
                                Icons.account_balance_wallet_rounded,
                                size: 130,
                                color: Colors.white,
                              ),
                              SizedBox(height: 34),
                              Text(
                                'Deuda Flow',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<Map<String, dynamic>> _bootstrap() async {
    // Conectividad
    bool isOnline;
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 2));
      isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      isOnline = false;
    }
    // Si no restauramos antes (hot reload / navegaciones), intentar ahora una sola vez
    if (!_preBootRestored) {
      try {
        await SessionAuthorityService.instance
            .restoreSessionIfNeeded(hasInternet: isOnline)
            .timeout(const Duration(seconds: 3));
        _preBootRestored = true;
      } catch (_) {}
    }
    final session = Supabase.instance.client.auth.currentSession;
    return {'online': isOnline, 'session': session};
  }

  @override
  Widget build(BuildContext context) {
    final clientsBox = Hive.box<ClientHive>('clients');
    final transactionsBox = Hive.box<TransactionHive>('transactions');
    final hasLocalData = clientsBox.isNotEmpty || transactionsBox.isNotEmpty;

    return FutureBuilder<Map<String, dynamic>>(
      future: _bootstrap(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final isOnline = data['online'] as bool;
        final session = data['session'];
        if (!isOnline && hasLocalData) {
          // Modo offline: acceso directo
          return MainScaffold(userId: 'offline');
        }
        if (session == null) {
          return const LoginScreen();
        } else {
          final userId = session.user.id;
          return MainScaffold(userId: userId);
        }
      },
    );
  }
}

// Borra todas las cajas locales de Hive (solo para debug/desarrollo)
Future<void> clearHiveData() async {
  // Cierra y borra las cajas si están abiertas
  try {
    if (Hive.isBoxOpen('transactions')) {
      await Hive.box('transactions').close();
    }
    await Hive.deleteBoxFromDisk('transactions');
    debugPrint('Caja transactions borrada');
  } catch (e) {
    debugPrint('Error al borrar caja transactions: $e');
  }
  try {
    if (Hive.isBoxOpen('clients')) {
      await Hive.box('clients').close();
    }
    await Hive.deleteBoxFromDisk('clients');
    debugPrint('Caja clients borrada');
  } catch (e) {
    debugPrint('Error al borrar caja clients: $e');
  }
  try {
    if (Hive.isBoxOpen('session')) {
      await Hive.box('session').close();
    }
    await Hive.deleteBoxFromDisk('session');
    debugPrint('Caja session borrada');
  } catch (e) {
    debugPrint('Error al borrar caja session: $e');
  }
}

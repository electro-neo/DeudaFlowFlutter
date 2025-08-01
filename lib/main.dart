import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/client_hive.dart';
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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ...eliminada duplicidad de _initializeApp...
Future<void> _initializeApp() async {
  try {
    debugPrint('Iniciando Supabase...');
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    debugPrint('Supabase inicializado');

    // Captura errores globales de Supabase y de Flutter
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('SocketException')) {
        debugPrint('Supabase offline: \n[${details.exception}]');
      } else {
        FlutterError.presentError(details);
      }
    };

    debugPrint('Iniciando Hive...');
    await Hive.initFlutter();
    debugPrint('Hive inicializado');
    Hive.registerAdapter(ClientHiveAdapter());
    Hive.registerAdapter(TransactionHiveAdapter());
    debugPrint('Adapters registrados');
    await Hive.openBox<ClientHive>('clients');
    debugPrint('Box clients abierto');
    await Hive.openBox<TransactionHive>('transactions');
    debugPrint('Box transactions abierto');
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
  await clearHiveData(); // Limpia datos locales de Hive SOLO para migración
  await _initializeApp();
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
          theme: BudgetoTheme.light, // Usa tu tema estático
          initialRoute: '/',
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
  Future<bool> checkInternet() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsBox = Hive.box<ClientHive>('clients');
    final transactionsBox = Hive.box<TransactionHive>('transactions');
    final hasLocalData = clientsBox.isNotEmpty || transactionsBox.isNotEmpty;

    return FutureBuilder<bool>(
      future: checkInternet(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final isOnline = snapshot.data ?? false;
        if (!isOnline && hasLocalData) {
          // Modo offline: acceso directo
          return MainScaffold(userId: 'offline');
        }
        // Si hay internet, consulta Supabase normalmente
        final session = Supabase.instance.client.auth.currentSession;
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/client_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/currency_provider.dart';

import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/not_found_screen.dart';
import 'supabase_keys.dart';
import 'widgets/main_scaffold.dart';
import 'providers/transaction_filter_provider.dart';
import 'providers/tab_provider.dart';
import 'providers/theme_provider.dart';
import 'widgets/budgeto_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl, // Usando la variable importada
    anonKey: supabaseAnonKey, // Usando la variable importada
  );
  runApp(const MyApp());
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
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'Deuda Flow Control',
          theme: BudgetoTheme.light,
          darkTheme: BudgetoTheme.dark,
          themeMode: themeProvider.themeMode,
          home: const AuthGate(),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/':
                return MaterialPageRoute(builder: (_) => const WelcomeScreen());
              case '/login':
                return MaterialPageRoute(builder: (_) => const LoginScreen());
              case '/register':
                return MaterialPageRoute(
                  builder: (_) => const RegisterScreen(),
                );
              case '/forgot-password':
                return MaterialPageRoute(
                  builder: (_) => const ForgotPasswordScreen(),
                );
              case '/reset-password':
                return MaterialPageRoute(
                  builder: (_) => const ResetPasswordScreen(),
                );
              case '/dashboard':
                return MaterialPageRoute(builder: (_) => AuthGate());
              case '/clients':
                return MaterialPageRoute(builder: (_) => AuthGate());
              case '/transactions':
                return MaterialPageRoute(builder: (_) => AuthGate());
              default:
                return MaterialPageRoute(
                  builder: (_) => const NotFoundScreen(),
                );
            }
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
  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const LoginScreen();
    } else {
      final userId = session.user.id;
      // Usar el nuevo MainScaffold para navegación global
      return MainScaffold(userId: userId);
    }
  }
}

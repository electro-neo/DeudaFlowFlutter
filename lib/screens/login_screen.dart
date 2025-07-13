import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../providers/client_provider.dart';
import '../providers/transaction_provider.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Future<void> _loginOffline() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final email = _emailController.text.trim();
    final sessionBox = await Hive.openBox('session');
    final savedEmail = sessionBox.get('email');
    if (!mounted) return;
    if (savedEmail == email && email.isNotEmpty) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      setState(() {
        _error = 'No hay sesión guardada para este usuario.';
      });
    }
    setState(() {
      _loading = false;
    });
  }

  // Datos de invitado (ajusta si es necesario)
  static const String _guestEmail = 'invitado@deudaflow.com';
  static const String _guestPassword = 'invitado123';

  Future<void> _loginAsGuest() async {
    _emailController.text = _guestEmail;
    _passwordController.text = _guestPassword;
    await _login();
  }

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Email y contraseña requeridos';
        _loading = false;
      });
      return;
    }
    // Intentar login online primero
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      final user = res.user;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Login fallido';
        });
      } else {
        // Guardar usuario en Hive para saludo offline
        final sessionBox = await Hive.openBox('session');
        final userMeta = user.userMetadata;
        final userName =
            (userMeta != null &&
                userMeta['name'] != null &&
                userMeta['name'].toString().trim().isNotEmpty)
            ? userMeta['name']
            : null;
        await sessionBox.put('userName', userName ?? '');
        await sessionBox.put('email', user.email ?? email);
        if (!mounted) return;
        // Sincronizar datos locales si hay internet
        try {
          final clientProvider = Provider.of<ClientProvider>(
            context,
            listen: false,
          );
          final txProvider = Provider.of<TransactionProvider>(
            context,
            listen: false,
          );
          await clientProvider.syncPendingClients(user.id);
          await txProvider.syncPendingTransactions(user.id);
        } catch (_) {}
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } on AuthException catch (e) {
      // Si es error de red, permitir login offline si hay datos guardados
      if (e.message.toLowerCase().contains('network') ||
          e.message.toLowerCase().contains('internet')) {
        final sessionBox = await Hive.openBox('session');
        final savedEmail = sessionBox.get('email');
        if (!mounted) return;
        if (savedEmail == email) {
          // Login offline permitido
          // ignore: use_build_context_synchronously
          Navigator.of(context).pushReplacementNamed('/dashboard');
        } else {
          setState(() {
            _error = 'No hay sesión guardada para este usuario.';
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _error = e.message;
        });
      }
    } catch (e) {
      // Si es error de red, permitir login offline si hay datos guardados
      if (e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('internet')) {
        final sessionBox = await Hive.openBox('session');
        final savedEmail = sessionBox.get('email');
        if (savedEmail == email) {
          // Login offline permitido
          // ignore: use_build_context_synchronously
          Navigator.of(context).pushReplacementNamed('/dashboard');
        } else {
          setState(() {
            _error = 'No hay sesión guardada para este usuario.';
          });
        }
      } else {
        setState(() {
          _error = 'Error inesperado: [${e.toString()}';
        });
      }
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 350),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 36,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Iniciar sesión',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_outline, size: 20),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Entrar',
                                  style: TextStyle(fontSize: 15),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _loginOffline,
                          icon: const Icon(Icons.wifi_off, size: 18),
                          label: const Text(
                            'Ingresar sin conexión',
                            style: TextStyle(fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              ),
                              child: const Text(
                                'Registrarse',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              ),
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _loginAsGuest,
                          icon: const Icon(Icons.person_outline, size: 18),
                          label: const Text(
                            'Probar como invitado',
                            style: TextStyle(fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

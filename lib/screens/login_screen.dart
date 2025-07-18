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
    // Verifica si ya hay sesión guardada para invitado
    final sessionBox = await Hive.openBox('session');
    final savedEmail = sessionBox.get('email');
    if (savedEmail == _guestEmail) {
      // Ya hay sesión guardada, permite acceso offline
      await _login();
    } else {
      // No hay sesión guardada, requiere internet la primera vez
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No es posible usar el modo invitado sin conexión la primera vez. Por favor, conéctate a internet e inicia sesión como invitado para habilitar el acceso offline.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
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
          // Si es invitado, mensaje especial
          if (email == _guestEmail) {
            setState(() {
              _error =
                  'No es posible usar el modo invitado sin conexión la primera vez. Conéctate a internet e inicia sesión como invitado para habilitar el acceso offline.';
            });
          } else {
            setState(() {
              _error = 'No hay sesión guardada para este usuario.';
            });
          }
        }
      } else {
        if (!mounted) return;
        // Si es invitado, mensaje más amigable
        if (email == _guestEmail) {
          setState(() {
            _error =
                'No se pudo acceder como invitado. Verifica tu conexión o intenta más tarde.';
          });
        } else {
          setState(() {
            _error = e.message;
          });
        }
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
          // Si es invitado, mensaje especial
          if (email == _guestEmail) {
            setState(() {
              _error =
                  'No es posible usar el modo invitado sin conexión la primera vez. Conéctate a internet e inicia sesión como invitado para habilitar el acceso offline.';
            });
          } else {
            setState(() {
              _error = 'No hay sesión guardada para este usuario.';
            });
          }
        }
      } else {
        // Si es invitado, mensaje más amigable
        if (email == _guestEmail) {
          setState(() {
            _error =
                'No se pudo acceder como invitado. Verifica tu conexión o intenta más tarde.';
          });
        } else {
          setState(() {
            _error = 'Error inesperado: ${e.toString()}';
          });
        }
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF7C3AED), // Morado principal
              Color(0xFF4F46E5), // Azul/morado
              Color(0xFF60A5FA), // Azul claro
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 370),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                      width: 1.2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 36,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 54,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Deuda Flow',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(0, 2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Inicia sesión para gestionar tus deudas y clientes',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                            filled: true,
                            fillColor: Colors.white,
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
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 12),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              minimumSize: const Size(0, 42),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 2,
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Entrar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
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
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                ),
                                child: const Text(
                                  '¿Olvidaste tu contraseña?',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _loginOffline,
                            icon: const Icon(
                              Icons.wifi_off,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Ingresar sin conexión',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Colors.white70,
                                width: 1.2,
                              ),
                              minimumSize: const Size(0, 38),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _loginAsGuest,
                            icon: const Icon(
                              Icons.person_outline,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Probar como invitado',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Colors.white70,
                                width: 1.2,
                              ),
                              minimumSize: const Size(0, 38),
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
      ),
    );
  }
}

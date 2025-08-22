import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import '../services/session_authority_service.dart';
import '../providers/client_provider.dart';
import '../providers/transaction_provider.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../widgets/budgeto_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ...existing code...

  // Animación simple para los botones: escala al presionar
  double _loginBtnScale = 1.0;
  double _offlineBtnScale = 1.0;
  double _googleBtnScale = 1.0;

  @override
  void initState() {
    super.initState();
    _prefillEmailFromSession();
  }

  Future<void> _prefillEmailFromSession() async {
    try {
      final box = await Hive.openBox('session');
      final savedEmail = box.get('email');
      if (savedEmail is String && savedEmail.trim().isNotEmpty) {
        // El email ya se guarda normalizado en minúsculas
        _emailController.text = savedEmail;
      }
    } catch (_) {}
  }

  Future<void> _loginOffline() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final email = _emailController.text.trim();
    final sessionBox = await Hive.openBox('session');
    final savedEmail = sessionBox.get('email');
    if (!mounted) return;
    // Permite usar el email guardado si el campo está vacío
    String? candidateEmail = email.isNotEmpty
        ? email
        : (savedEmail is String && savedEmail.trim().isNotEmpty)
        ? savedEmail
        : null;
    // Comparación tolerante a mayúsculas/minúsculas
    if (savedEmail is String &&
        candidateEmail != null &&
        savedEmail.trim().toLowerCase() == candidateEmail.toLowerCase()) {
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

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  // Verifica rápidamente si hay conectividad y acceso real a internet.
  Future<bool> _hasConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final hasAnyNetwork = results.any((r) => r != ConnectivityResult.none);
      if (!hasAnyNetwork) return false;
      // Verifica acceso real a internet (no solo red local/portal cautivo)
      final hasInternet = await InternetConnectionChecker().hasConnection;
      return hasInternet;
    } catch (_) {
      // En caso de error del plugin, no bloquear el flujo existente
      return true;
    }
  }

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
    // Verificar conectividad antes de intentar login online
    if (!await _hasConnectivity()) {
      setState(() {
        _error = 'Sin conexión a internet.';
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
        // Guarda email normalizado para evitar fallas por diferencia de mayúsculas
        final normalizedEmail = (user.email ?? email).trim().toLowerCase();
        await sessionBox.put('email', normalizedEmail);
        if (!mounted) return;
        // Verificación de sesión única por dispositivo
        try {
          final state = await SessionAuthorityService.instance.evaluate(
            userId: user.id,
            hasInternet: true,
          );
          if (state == AuthorityState.conflict) {
            // ignore: use_build_context_synchronously
            final proceed = await SessionAuthorityService.instance
                // ignore: use_build_context_synchronously
                .handleConflictDialog(context, user.id, isLoginFlow: true);
            if (!proceed) {
              // Usuario canceló o cerró sesión
              setState(() {
                _loading = false;
              });
              return;
            }
          } else {
            // Si el device_id remoto está vacío, fijarlo a este dispositivo
            final localId = await SessionAuthorityService.instance
                .getOrCreateLocalDeviceId();
            final remote = await SessionAuthorityService.instance
                .fetchServerDeviceId(user.id);
            if (remote == null || remote.isEmpty) {
              await SessionAuthorityService.instance.setServerDeviceId(
                user.id,
                localId,
              );
            }
            await SessionAuthorityService.instance.markSessionFlag(
              'authorized',
            );
          }
        } catch (_) {}

        // Sincronizar datos locales si hay internet (solo si no hubo bloqueo por conflicto)
        try {
          final clientProvider = Provider.of<ClientProvider>(
            // ignore: use_build_context_synchronously
            context,
            listen: false,
          );
          final txProvider = Provider.of<TransactionProvider>(
            // ignore: use_build_context_synchronously
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
      // Si es error de red, permitir login offline si hay datos guardadas
      if (e.message.toLowerCase().contains('network') ||
          e.message.toLowerCase().contains('internet')) {
        final sessionBox = await Hive.openBox('session');
        final savedEmail = sessionBox.get('email');
        if (!mounted) return;
        if (savedEmail is String &&
            savedEmail.trim().toLowerCase() == email.toLowerCase()) {
          // Login offline permitido
          // ignore: use_build_context_synchronously
          Navigator.of(context).pushReplacementNamed('/dashboard');
        } else {
          // Si es invitado, mensaje especial
          setState(() {
            _error = 'No hay sesión guardada para este usuario.';
          });
        }
      } else {
        if (!mounted) return;
        // Si es invitado, mensaje más amigable
        setState(() {
          _error = e.message.toLowerCase().contains('invalid login credentials')
              ? 'Credenciales incorrectas. Verifica tu email y contraseña.'
              : e.message;
        });
      }
    } catch (e) {
      // Si es error de red, permitir login offline si hay datos guardadas
      if (e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('internet')) {
        final sessionBox = await Hive.openBox('session');
        final savedEmail = sessionBox.get('email');
        if (savedEmail is String &&
            savedEmail.trim().toLowerCase() == email.toLowerCase()) {
          // Login offline permitido
          // ignore: use_build_context_synchronously
          Navigator.of(context).pushReplacementNamed('/dashboard');
        } else {
          // Si es invitado, mensaje especial
          setState(() {
            _error = 'No hay sesión guardada para este usuario.';
          });
        }
      } else {
        // Si es invitado, mensaje más amigable
        setState(() {
          _error = 'Error inesperado: ${e.toString()}';
        });
      }
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Validación de conectividad antes de iniciar el flujo de Google
    if (!await _hasConnectivity()) {
      setState(() {
        _loading = false;
        _error = 'Sin conexión a internet.';
      });
      return;
    }
    debugPrint(
      'DEBUG: Iniciando login con Google (Android, OAuth tipo Web Client ID, no WebApp)...',
    );
    try {
      final googleSignIn = GoogleSignIn.instance;
      debugPrint(
        'DEBUG: Llamando a googleSignIn.initialize con serverClientId (Android, tipo Web)...',
      );
      await googleSignIn.initialize(
        serverClientId:
            '1059073312131-hj2t8nus9buk7ii3j7cj37bptsfonh8k.apps.googleusercontent.com',
      );
      debugPrint('DEBUG: googleSignIn.initialize completado');
      debugPrint('DEBUG: Llamando a googleSignIn.authenticate...');
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await googleSignIn.authenticate();
        debugPrint(
          'DEBUG: googleSignIn.authenticate: usuario seleccionó cuenta: email=[32m[1m[4m[0m[0m${googleUser.email}, id=${googleUser.id}',
        );
        debugPrint('DEBUG: googleUser (raw): $googleUser');
      } catch (e) {
        debugPrint('DEBUG: googleSignIn.authenticate lanzó excepción: $e');
        rethrow;
      }

      GoogleSignInAuthentication? googleAuth;
      try {
        googleAuth = googleUser.authentication;
        debugPrint('DEBUG: googleUser.authentication completado: $googleAuth');
        debugPrint('DEBUG: googleAuth.idToken: ${googleAuth.idToken}');
      } catch (e) {
        debugPrint('DEBUG: googleUser.authentication lanzó excepción: $e');
        setState(() {
          _loading = false;
          _error = 'No se pudo obtener el token de Google.';
        });
        return;
      }

      final idToken = googleAuth.idToken;
      if (idToken == null) {
        debugPrint('DEBUG: idToken es null después de seleccionar cuenta.');
        setState(() {
          _loading = false;
          _error = 'No se pudo obtener el token de Google.';
        });
        return;
      }
      debugPrint(
        'DEBUG: Llamando a Supabase signInWithIdToken con idToken: $idToken',
      );
      final res = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      debugPrint('DEBUG: Supabase signInWithIdToken completado: $res');
      final user = res.user;
      if (user == null) {
        debugPrint('DEBUG: Supabase devolvió user == null');
        setState(() {
          _loading = false;
          _error = 'No se pudo iniciar sesión con Google.';
        });
        return;
      }
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
      // Guarda email normalizado para consistencia con el botón offline
      final normalizedEmail = (user.email ?? '').trim().toLowerCase();
      await sessionBox.put('email', normalizedEmail);
      if (!mounted) return;

      // Verificación de sesión única por dispositivo
      try {
        final state = await SessionAuthorityService.instance.evaluate(
          userId: user.id,
          hasInternet: true,
        );
        if (state == AuthorityState.conflict) {
          final proceed = await SessionAuthorityService.instance
              // ignore: use_build_context_synchronously
              .handleConflictDialog(context, user.id, isLoginFlow: true);
          if (!proceed) {
            setState(() {
              _loading = false;
            });
            return;
          }
        } else {
          final localId = await SessionAuthorityService.instance
              .getOrCreateLocalDeviceId();
          final remote = await SessionAuthorityService.instance
              .fetchServerDeviceId(user.id);
          if (remote == null || remote.isEmpty) {
            await SessionAuthorityService.instance.setServerDeviceId(
              user.id,
              localId,
            );
          }
          await SessionAuthorityService.instance.markSessionFlag('authorized');
        }
      } catch (_) {}
      debugPrint('DEBUG: Login con Google exitoso, navegando a dashboard.');
      // ignore: use_build_context_synchronously
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (e) {
      if (e is GoogleSignInException) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          debugPrint('DEBUG: Login cancelado por el usuario');
          setState(() {
            _error = 'Selección de cuenta cancelada.';
          });
        } else {
          final msg = e.toString().toLowerCase();
          final isNet =
              msg.contains('network') ||
              msg.contains('internet') ||
              msg.contains('timeout');
          setState(() {
            _error = isNet
                ? 'Problemas de conexión. Intenta nuevamente.'
                : 'Error al iniciar sesión con Google: ${e.toString()}';
          });
        }
      } else {
        debugPrint(
          'DEBUG: Error inesperado en login con Google: ${e.toString()}',
        );
        final msg = e.toString().toLowerCase();
        final isNet =
            msg.contains('network') ||
            msg.contains('internet') ||
            msg.contains('timeout');
        setState(() {
          _error = isNet
              ? 'Problemas de conexión. Intenta nuevamente.'
              : 'Error al iniciar sesión con Google: ${e.toString()}';
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
                    color: Colors.white.withAlpha((0.10 * 255).toInt()),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.08 * 255).toInt()),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withAlpha((0.18 * 255).toInt()),
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
                                color: kErrorColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                shadows: kErrorShadow,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTapDown: (_) =>
                                setState(() => _loginBtnScale = 0.93),
                            onTapUp: (_) =>
                                setState(() => _loginBtnScale = 1.0),
                            onTapCancel: () =>
                                setState(() => _loginBtnScale = 1.0),
                            onTap: _loading
                                ? null
                                : () {
                                    setState(() => _loginBtnScale = 1.0);
                                    _login();
                                  },
                            child: AnimatedScale(
                              scale: _loginBtnScale,
                              duration: const Duration(milliseconds: 120),
                              curve: Curves.easeOut,
                              child: OutlinedButton.icon(
                                onPressed:
                                    null, // Solo GestureDetector ejecuta la acción
                                icon: const Icon(
                                  Icons.login,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: _loading
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  backgroundColor: Colors.transparent,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // ...guest login button removed...
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTapDown: (_) =>
                                setState(() => _googleBtnScale = 0.93),
                            onTapUp: (_) =>
                                setState(() => _googleBtnScale = 1.0),
                            onTapCancel: () =>
                                setState(() => _googleBtnScale = 1.0),
                            onTap: _loading
                                ? null
                                : () {
                                    setState(() => _googleBtnScale = 1.0);
                                    _loginWithGoogle();
                                  },
                            child: AnimatedScale(
                              scale: _googleBtnScale,
                              duration: const Duration(milliseconds: 120),
                              curve: Curves.easeOut,
                              child: OutlinedButton.icon(
                                onPressed:
                                    null, // Desactivado, solo GestureDetector ejecuta la acción
                                icon: const FaIcon(
                                  FontAwesomeIcons.google,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Entrar con Google',
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  backgroundColor: Colors.transparent,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTapDown: (_) =>
                                setState(() => _offlineBtnScale = 0.93),
                            onTapUp: (_) =>
                                setState(() => _offlineBtnScale = 1.0),
                            onTapCancel: () =>
                                setState(() => _offlineBtnScale = 1.0),
                            onTap: _loading
                                ? null
                                : () {
                                    setState(() => _offlineBtnScale = 1.0);
                                    _loginOffline();
                                  },
                            child: AnimatedScale(
                              scale: _offlineBtnScale,
                              duration: const Duration(milliseconds: 120),
                              curve: Curves.easeOut,
                              child: OutlinedButton.icon(
                                onPressed:
                                    null, // Desactivado, solo GestureDetector ejecuta la acción
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
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
                        ),// ...existing code...
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

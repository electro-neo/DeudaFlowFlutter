import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import '../services/session_authority_service.dart';
// import '../services/network_warmup.dart';
import '../providers/client_provider.dart';
import '../providers/transaction_provider.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../widgets/budgeto_colors.dart';
import '../main.dart';

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
  static const String _guestEmail = 'invitado@deudaflow.com';

  // Botón y lógica de invitado ocultos/deshabilitados
  // void _loginAsGuest() async {}

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  // Verifica rápidamente si hay conectividad y acceso real a internet.
  Future<bool> _hasConnectivity() async {
    final sw = Stopwatch()..start();
    try {
      final results = await Connectivity().checkConnectivity();
      final hasAnyNetwork = results.any((r) => r != ConnectivityResult.none);
      debugPrint(
        '[LOGIN][conn] checkConnectivity en ${sw.elapsedMilliseconds}ms -> ${hasAnyNetwork ? 'alguna red' : 'sin red'}',
      );
      if (!hasAnyNetwork) return false;
      // Verifica acceso real a internet (no solo red local/portal cautivo)
      final hasInternet = await InternetConnectionChecker().hasConnection;
      debugPrint(
        '[LOGIN][conn] hasConnection en ${sw.elapsedMilliseconds}ms -> ${hasInternet ? 'internet OK' : 'sin internet'}',
      );
      return hasInternet;
    } catch (e) {
      debugPrint('[LOGIN][conn] error conectividad: $e');
      // En caso de error del plugin, no bloquear el flujo existente
      return true;
    }
  }

  Future<void> _login() async {
    final req = DateTime.now().millisecondsSinceEpoch.toString();
    final sw = Stopwatch()..start();
    debugPrint('[LOGIN][$req] Inicio login con email');
    setState(() {
      _loading = true;
      _error = null;
    });
    // Calentamiento de red (no bloqueante), por si el primer request tarda por DNS/TLS
    Future.microtask(() async {
      // await NetworkWarmup.warmSupabase();
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
      final authSw = Stopwatch()..start();
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      debugPrint(
        '[LOGIN][$req] signInWithPassword completó en ${authSw.elapsedMilliseconds}ms',
      );
      if (!mounted) return;
      final user = res.user;
      if (user == null) {
        setState(() {
          _error = 'Login fallido';
        });
      } else {
        // Guardar usuario en Hive para saludo offline
        final hiveSw = Stopwatch()..start();
        final sessionBox = await Hive.openBox('session');
        debugPrint(
          '[LOGIN][$req] Hive.openBox(session) ${hiveSw.elapsedMilliseconds}ms',
        );
        final userMeta = user.userMetadata;
        final userName =
            (userMeta != null &&
                userMeta['name'] != null &&
                userMeta['name'].toString().trim().isNotEmpty)
            ? userMeta['name']
            : null;
        final saveSw = Stopwatch()..start();
        await sessionBox.put('userName', userName ?? '');
        // Guarda email normalizado para evitar fallas por diferencia de mayúsculas
        final normalizedEmail = (user.email ?? email).trim().toLowerCase();
        await sessionBox.put('email', normalizedEmail);
        debugPrint(
          '[LOGIN][$req] Guardado en Hive (userName/email) ${saveSw.elapsedMilliseconds}ms',
        );
        if (!mounted) return;
        // Verificación de sesión única por dispositivo
        try {
          final evalSw = Stopwatch()..start();
          final state = await SessionAuthorityService.instance.evaluate(
            userId: user.id,
            hasInternet: true,
          );
          debugPrint(
            '[LOGIN][$req] evaluate() => $state en ${evalSw.elapsedMilliseconds}ms',
          );
          if (state == AuthorityState.conflict) {
            final dlgSw = Stopwatch()..start();
            final proceed = await SessionAuthorityService.instance
                // ignore: use_build_context_synchronously
                .handleConflictDialog(context, user.id, isLoginFlow: true);
            debugPrint(
              '[LOGIN][$req] handleConflictDialog() result=$proceed en ${dlgSw.elapsedMilliseconds}ms',
            );
            if (!proceed) {
              // Usuario canceló o cerró sesión
              setState(() {
                _loading = false;
              });
              return;
            }
          } else {
            // En primer login: marcar autorizado y hacer el bind de device_id en segundo plano
            final markSw = Stopwatch()..start();
            await SessionAuthorityService.instance.markSessionFlag(
              'authorized',
            );
            debugPrint(
              '[LOGIN][$req] markSessionFlag("authorized") ${markSw.elapsedMilliseconds}ms',
            );
            final alreadyBound = (sessionBox.get('device_bound') == true);
            if (!alreadyBound) {
              final lidSw = Stopwatch()..start();
              final localId = await SessionAuthorityService.instance
                  .getOrCreateLocalDeviceId();
              debugPrint(
                '[LOGIN][$req] getOrCreateLocalDeviceId() ${lidSw.elapsedMilliseconds}ms -> $localId',
              );
              // No bloquear la UI: realizar el guardado remoto en background
              Future.microtask(() async {
                try {
                  final bindSw = Stopwatch()..start();
                  await SessionAuthorityService.instance.setServerDeviceId(
                    user.id,
                    localId,
                  );
                  await sessionBox.put('device_bound', true);
                  debugPrint(
                    '[LOGIN][$req] setServerDeviceId + flag device_bound en ${bindSw.elapsedMilliseconds}ms (bg)',
                  );
                } catch (_) {}
              });
            } else {
              debugPrint('[LOGIN][$req] device ya estaba bound');
            }
          }
        } catch (e) {
          debugPrint('[LOGIN][$req] Error durante evaluación/autoridad: $e');
        }

        debugPrint(
          '[LOGIN][$req] Navegando a /dashboard t+${sw.elapsedMilliseconds}ms',
        );
        // Mostrar dashboard inmediatamente
        // ignore: use_build_context_synchronously
        Navigator.of(context).pushReplacementNamed('/dashboard');
        return;

        // Iniciar escucha de cambios en device_id para este usuario (no bloquear UI)
        Future.microtask(() {
          debugPrint(
            '[LOGIN][$req] Iniciando listener realtime de device_id (microtask)',
          );
          final ctx = navigatorKey.currentContext ?? context;
          SessionAuthorityService.instance.listenToDeviceIdChanges(
            user.id,
            ctx,
          );
        });

        // Sincronizar datos locales en segundo plano (ligera demora para no interferir con el primer frame)
        Future(() async {
          await Future.delayed(const Duration(milliseconds: 500));
          final syncSw = Stopwatch()..start();
          try {
            // Cortocircuito: si no hay cambios locales, omitir sync inicial
            final hasPending = await SessionAuthorityService.instance
                .hasLocalPendingChanges();
            if (!hasPending) {
              debugPrint(
                '[LOGIN][$req] No hay cambios locales; se omite sync inicial.',
              );
              return;
            }
            final ctx = navigatorKey.currentContext;
            if (ctx != null) {
              final clientProvider = Provider.of<ClientProvider>(
                ctx,
                listen: false,
              );
              final txProvider = Provider.of<TransactionProvider>(
                ctx,
                listen: false,
              );
              await Future.wait([
                clientProvider.syncPendingClients(user.id),
                txProvider.syncPendingTransactions(user.id),
              ]);
              debugPrint(
                '[LOGIN][$req] Background sync completada en ${syncSw.elapsedMilliseconds}ms',
              );
            }
          } catch (e) {
            debugPrint('[LOGIN][$req] Error en background sync: $e');
          }
        });
      }
    } on AuthException catch (e) {
      debugPrint(
        '[LOGIN][$req] AuthException: ${e.message} (t+${sw.elapsedMilliseconds}ms)',
      );
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
          return;
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
            _error =
                e.message.toLowerCase().contains('invalid login credentials')
                ? 'Credenciales incorrectas. Verifica tu email y contraseña.'
                : e.message;
          });
        }
      }
    } catch (e) {
      debugPrint(
        '[LOGIN][$req] Error inesperado en login: $e (t+${sw.elapsedMilliseconds}ms)',
      );
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
      debugPrint(
        '[LOGIN][$req] Fin login (setState loading=false) total=${sw.elapsedMilliseconds}ms',
      );
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    final req = 'G${DateTime.now().millisecondsSinceEpoch}';
    final sw = Stopwatch()..start();
    debugPrint('[LOGIN-GOOGLE][$req] Inicio login con Google');
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
      '[LOGIN-GOOGLE][$req] Iniciando login con Google (Android, OAuth Web Client ID)...',
    );
    try {
      final googleSignIn = GoogleSignIn.instance;
      debugPrint('[LOGIN-GOOGLE][$req] googleSignIn.initialize...');
      final initSw = Stopwatch()..start();
      await googleSignIn.initialize(
        serverClientId:
            '1059073312131-hj2t8nus9buk7ii3j7cj37bptsfonh8k.apps.googleusercontent.com',
      );
      debugPrint(
        '[LOGIN-GOOGLE][$req] googleSignIn.initialize completado en ${initSw.elapsedMilliseconds}ms',
      );
      debugPrint('[LOGIN-GOOGLE][$req] googleSignIn.authenticate...');
      GoogleSignInAccount? googleUser;
      try {
        final gauthSw = Stopwatch()..start();
        googleUser = await googleSignIn.authenticate();
        debugPrint(
          '[LOGIN-GOOGLE][$req] authenticate seleccionó: email=${googleUser.email}, id=${googleUser.id} en ${gauthSw.elapsedMilliseconds}ms',
        );
        debugPrint('[LOGIN-GOOGLE][$req] googleUser (raw): $googleUser');
      } catch (e) {
        debugPrint(
          '[LOGIN-GOOGLE][$req] googleSignIn.authenticate lanzó excepción: $e',
        );
        rethrow;
      }

      GoogleSignInAuthentication? googleAuth;
      try {
        final tokSw = Stopwatch()..start();
        googleAuth = googleUser.authentication;
        debugPrint(
          '[LOGIN-GOOGLE][$req] googleUser.authentication completado en ${tokSw.elapsedMilliseconds}ms',
        );
        // Evitar imprimir el token completo para no saturar logs
        final idTokDbg = googleAuth.idToken;
        if (idTokDbg != null) {
          final preview = idTokDbg.length > 12
              ? idTokDbg.substring(0, 12)
              : idTokDbg;
          debugPrint(
            '[LOGIN-GOOGLE][$req] googleAuth.idToken(preview): $preview...',
          );
        }
      } catch (e) {
        debugPrint(
          '[LOGIN-GOOGLE][$req] googleUser.authentication lanzó excepción: $e',
        );
        setState(() {
          _loading = false;
          _error = 'No se pudo obtener el token de Google.';
        });
        return;
      }

      final idToken = googleAuth.idToken;
      if (idToken == null) {
        debugPrint(
          '[LOGIN-GOOGLE][$req] idToken es null después de seleccionar cuenta.',
        );
        setState(() {
          _loading = false;
          _error = 'No se pudo obtener el token de Google.';
        });
        return;
      }
      debugPrint(
        '[LOGIN-GOOGLE][$req] Llamando a Supabase signInWithIdToken...',
      );
      final authSw = Stopwatch()..start();
      final res = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      debugPrint(
        '[LOGIN-GOOGLE][$req] signInWithIdToken completó en ${authSw.elapsedMilliseconds}ms',
      );
      final user = res.user;
      if (user == null) {
        debugPrint('[LOGIN-GOOGLE][$req] Supabase devolvió user == null');
        setState(() {
          _loading = false;
          _error = 'No se pudo iniciar sesión con Google.';
        });
        return;
      }
      // Guardar usuario en Hive para saludo offline
      final hiveSw = Stopwatch()..start();
      final sessionBox = await Hive.openBox('session');
      debugPrint(
        '[LOGIN-GOOGLE][$req] Hive.openBox(session) ${hiveSw.elapsedMilliseconds}ms',
      );
      final userMeta = user.userMetadata;
      final userName =
          (userMeta != null &&
              userMeta['name'] != null &&
              userMeta['name'].toString().trim().isNotEmpty)
          ? userMeta['name']
          : null;
      final saveSw = Stopwatch()..start();
      await sessionBox.put('userName', userName ?? '');
      // Guarda email normalizado para consistencia con el botón offline
      final normalizedEmail = (user.email ?? '').trim().toLowerCase();
      await sessionBox.put('email', normalizedEmail);
      debugPrint(
        '[LOGIN-GOOGLE][$req] Guardado en Hive (userName/email) ${saveSw.elapsedMilliseconds}ms',
      );
      if (!mounted) return;

      // Verificación de sesión única por dispositivo
      try {
        final evalSw = Stopwatch()..start();
        final state = await SessionAuthorityService.instance.evaluate(
          userId: user.id,
          hasInternet: true,
        );
        debugPrint(
          '[LOGIN-GOOGLE][$req] evaluate() => $state en ${evalSw.elapsedMilliseconds}ms',
        );
        if (state == AuthorityState.conflict) {
          final proceed = await SessionAuthorityService.instance
              // ignore: use_build_context_synchronously
              .handleConflictDialog(context, user.id, isLoginFlow: true);
          debugPrint(
            '[LOGIN-GOOGLE][$req] handleConflictDialog() result=$proceed',
          );
          if (!proceed) {
            setState(() {
              _loading = false;
            });
            return;
          }
        } else {
          // Marcar autorizado y hacer bind en segundo plano (idempotente si ya coincide)
          final markSw = Stopwatch()..start();
          await SessionAuthorityService.instance.markSessionFlag('authorized');
          debugPrint(
            '[LOGIN-GOOGLE][$req] markSessionFlag("authorized") ${markSw.elapsedMilliseconds}ms',
          );
          final localId = await SessionAuthorityService.instance
              .getOrCreateLocalDeviceId();
          Future.microtask(() async {
            try {
              final bindSw = Stopwatch()..start();
              await SessionAuthorityService.instance.setServerDeviceId(
                user.id,
                localId,
              );
              await sessionBox.put('device_bound', true);
              debugPrint(
                '[LOGIN-GOOGLE][$req] setServerDeviceId + flag device_bound en ${bindSw.elapsedMilliseconds}ms (bg)',
              );
            } catch (_) {}
          });
        }
      } catch (_) {}
      debugPrint(
        '[LOGIN-GOOGLE][$req] Login con Google exitoso, navegando a dashboard t+${sw.elapsedMilliseconds}ms',
      );
      // Navegar primero
      // ignore: use_build_context_synchronously
      Navigator.of(context).pushReplacementNamed('/dashboard');
      return;
      // Iniciar escucha en microtask para no bloquear UI
      Future.microtask(() {
        debugPrint(
          '[LOGIN-GOOGLE][$req] Iniciando listener realtime de device_id (microtask)',
        );
        final ctx = navigatorKey.currentContext ?? context;
        SessionAuthorityService.instance.listenToDeviceIdChanges(user.id, ctx);
      });
      // Sincronizar en segundo plano (paralelo) con pequeña demora para no afectar el primer frame
      Future(() async {
        await Future.delayed(const Duration(milliseconds: 500));
        final syncSw = Stopwatch()..start();
        try {
          // Cortocircuito: si no hay cambios locales, omitir sync inicial
          final hasPending = await SessionAuthorityService.instance
              .hasLocalPendingChanges();
          if (!hasPending) {
            debugPrint(
              '[LOGIN-GOOGLE][$req] No hay cambios locales; se omite sync inicial.',
            );
            return;
          }
          final ctx = navigatorKey.currentContext;
          if (ctx != null) {
            final clientProvider = Provider.of<ClientProvider>(
              ctx,
              listen: false,
            );
            final txProvider = Provider.of<TransactionProvider>(
              ctx,
              listen: false,
            );
            await Future.wait([
              clientProvider.syncPendingClients(user.id),
              txProvider.syncPendingTransactions(user.id),
            ]);
            debugPrint(
              '[LOGIN-GOOGLE][$req] Background sync completada en ${syncSw.elapsedMilliseconds}ms',
            );
          }
        } catch (e) {
          debugPrint('[LOGIN-GOOGLE][$req] Error en background sync: $e');
        }
      });
    } catch (e) {
      if (e is GoogleSignInException) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          debugPrint('[LOGIN-GOOGLE][$req] Login cancelado por el usuario');
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
          '[LOGIN-GOOGLE][$req] Error inesperado en login con Google: ${e.toString()}',
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
      debugPrint(
        '[LOGIN-GOOGLE][$req] Fin login Google (setState loading=false) total=${sw.elapsedMilliseconds}ms',
      );
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
                        // const SizedBox(height: 6),
                        // Botón "Probar como invitado" oculto
                        const SizedBox(height: 6),
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
                        // ...existing code...
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

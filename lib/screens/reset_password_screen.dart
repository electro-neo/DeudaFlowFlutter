import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/toast_helper.dart';
import '../widgets/budgeto_colors.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _reset() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (_passwordController.text.length < 6) {
      setState(() {
        _error = 'La contraseña debe tener al menos 6 caracteres.';
        _loading = false;
      });
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() {
        _error = 'Las contraseñas no coinciden.';
        _loading = false;
      });
      return;
    }
    try {
      final res = await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      // El siguiente uso de context es seguro porque:
      // 1. Se verifica 'if (!mounted) return;' antes de usar context tras el async gap.
      // 2. Este context es el de la clase State, no de un builder externo.
      // Por lo tanto, el warning puede ser ignorado.
      // ignore: use_build_context_synchronously
      if (!mounted) return;
      if (res.user == null) {
        setState(() {
          _error = 'Error al cambiar contraseña';
        });
      } else {
        ToastHelper.showToast(
          context,
          'Contraseña actualizada. Inicia sesión.',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = 'Error al cambiar contraseña: \n${e.toString()}';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Importa los colores y sombras centralizados
    // ignore: unused_import

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kBackgroundGradientStart,
              Color(0xFF4F46E5), // Azul/morado intermedio
              kBackgroundGradientEnd,
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
                    color: kCardBackgroundColor,
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
                          Icons.lock_reset,
                          size: 54,
                          color: kIconColor,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Restablecer contraseña',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: kTitleColor,
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
                          'Ingresa y confirma tu nueva contraseña',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Nueva contraseña',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              size: 20,
                              color: kIconColor,
                            ),
                            filled: true,
                            fillColor: kInputFieldColor,
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmController,
                          decoration: const InputDecoration(
                            labelText: 'Confirmar contraseña',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              size: 20,
                              color: kIconColor,
                            ),
                            filled: true,
                            fillColor: kInputFieldColor,
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
                          child: AnimatedScale(
                            scale: _loading ? 0.98 : 1.0,
                            duration: const Duration(milliseconds: 120),
                            child: ElevatedButton(
                              onPressed: _loading ? null : _reset,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kButtonColor,
                                minimumSize: const Size(0, 42),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 2,
                                shadowColor: kButtonShadowColor,
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
                                      'Restablecer',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
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

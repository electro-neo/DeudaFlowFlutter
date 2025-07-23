import 'package:flutter/material.dart';
import '_animated_tap_to_start.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

// Variable global para almacenar los contactos
List<Contact> globalContacts = [];

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFading = false;

  @override
  void initState() {
    super.initState();
    _initContacts();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation =
        Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        });
  }

  Future<void> _initContacts() async {
    final status = await Permission.contacts.status;
    if (status.isGranted || (await Permission.contacts.request()).isGranted) {
      globalContacts = await FlutterContacts.getContacts(withProperties: true);
      debugPrint(
        '[CONTACTS] Contactos cargados al iniciar: ${globalContacts.length}',
      );
    } else {
      debugPrint('[CONTACTS] Permiso de contactos no concedido al iniciar');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    if (!_isFading) {
      setState(() {
        _isFading = true;
      });
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Container(
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
          child: FadeTransition(
            opacity: _animation,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Bienvenido',
                    style: TextStyle(
                      fontSize: 36,
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
                  const SizedBox(height: 16),
                  const Text(
                    'Comienza a gestionar tus deudas y clientes aquí.',
                    style: TextStyle(fontSize: 20, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  AnimatedTapToStart(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

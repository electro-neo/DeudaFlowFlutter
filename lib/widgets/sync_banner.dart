import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../providers/sync_provider.dart';

class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    return _RealConnectivityBanner(sync: sync);
  }
}

class _RealConnectivityBanner extends StatefulWidget {
  final SyncProvider sync;
  const _RealConnectivityBanner({required this.sync});

  @override
  State<_RealConnectivityBanner> createState() =>
      _RealConnectivityBannerState();
}

class _RealConnectivityBannerState extends State<_RealConnectivityBanner> {
  bool? _isReallyOnline;
  @override
  void initState() {
    super.initState();
    _checkRealInternet();
  }

  void _checkRealInternet() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 2));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (mounted) setState(() => _isReallyOnline = online);
    } catch (_) {
      if (mounted) setState(() => _isReallyOnline = false);
    }
    // Repetir cada 5 segundos
    if (mounted) {
      Future.delayed(const Duration(seconds: 5), _checkRealInternet);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar siempre el banner, tanto offline como online
    Color ledColor;
    bool blinking = false;
    String text = '';
    Widget? action;
    if (_isReallyOnline == false) {
      ledColor = Colors.red;
      blinking = false;
      text = 'Offline: Trabajando con datos locales';
    } else {
      switch (widget.sync.status) {
        case SyncStatus.waiting:
          ledColor = Colors.amber;
          blinking = true;
          text = 'Conexión restablecida. Sincronizando datos pendientes…';
          break;
        case SyncStatus.syncing:
          ledColor = Colors.amber;
          blinking = true;
          text = 'Proceso de sincronización ${widget.sync.progress}%';
          break;
        case SyncStatus.success:
          ledColor = Colors.green;
          blinking = false;
          text = 'Sincronizado';
          break;
        case SyncStatus.error:
          ledColor = Colors.red;
          blinking = false;
          text = 'Error de sincronización';
          action = TextButton(
            onPressed: () {
              widget.sync.retrySync(context);
            },
            child: const Text(
              'Reintentar',
              style: TextStyle(color: Colors.white),
            ),
          );
          break;
        default:
          ledColor = Colors.green;
          blinking = false;
          text = 'Sincronizado';
      }
    }
    return _BannerWidget(
      text: text,
      ledColor: ledColor,
      blinking: blinking,
      action: action,
    );
    // Eliminar línea sobrante
  }
}

class _BannerWidget extends StatefulWidget {
  final String text;
  final Color ledColor;
  final bool blinking;
  final Widget? action;
  const _BannerWidget({
    required this.text,
    required this.ledColor,
    required this.blinking,
    this.action,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(
      begin: 1,
      end: 0.3,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.blinking) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _BannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.blinking && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.blinking && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        // Elimina width: double.infinity para que el banner solo use el ancho necesario
        constraints: const BoxConstraints(
          maxWidth:
              260, // Ajuste intermedio para evitar overflow y no ser tan ancho
        ),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) => Opacity(
                opacity: widget.blinking ? _animation.value : 1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.ledColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.text,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1, // Solo una línea
                textAlign: TextAlign.center,
              ),
            ),
            if (widget.action != null) ...[
              const SizedBox(width: 6),
              widget.action!,
            ],
          ],
        ),
      ),
    );
  }
}

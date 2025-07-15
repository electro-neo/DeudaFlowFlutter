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
    Widget? icon;
    // Parpadeo para todos los estados, pero con diferente color
    if (_isReallyOnline == false) {
      ledColor = Colors.red;
      blinking = true;
      icon = null;
      Future.microtask(() async {
        final pendings = await widget.sync.getTotalPendings();
        if (mounted) {
          setState(() {
            if (pendings > 0) {
              icon = const Icon(Icons.sync, color: Colors.white, size: 18);
              text =
                  '${pendings.toString().padLeft(2, '0')} sincronizaciones pendientes';
            } else {
              icon = null;
              text = 'Offline: Trabajando con datos locales';
            }
          });
        }
      });
      text = 'Offline: Trabajando con datos locales';
    } else {
      switch (widget.sync.status) {
        case SyncStatus.waiting:
        case SyncStatus.syncing:
          ledColor = Colors.amber;
          blinking = true;
          icon = const Icon(Icons.sync, color: Colors.white, size: 18);
          Future.microtask(() async {
            final pendings = await widget.sync.getTotalPendings();
            if (mounted) {
              setState(() {
                text = pendings > 0
                    ? '${pendings.toString().padLeft(2, '0')} sincronizaciones pendientes'
                    : (widget.sync.status == SyncStatus.syncing
                          ? 'Proceso de sincronización ${widget.sync.progress}%'
                          : 'Conexión restablecida. Sincronizando datos pendientes…');
              });
            }
          });
          text = widget.sync.status == SyncStatus.syncing
              ? 'Proceso de sincronización ${widget.sync.progress}%'
              : 'Conexión restablecida. Sincronizando datos pendientes…';
          break;
        case SyncStatus.success:
        case SyncStatus.idle:
          ledColor = Colors.green;
          blinking = true;
          icon =null;
          text = 'Sincronizado';
          break;
        case SyncStatus.error:
          ledColor = Colors.red;
          blinking = true;
          icon = const Icon(Icons.sync_problem, color: Colors.white, size: 18);
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
          blinking = true;
          icon = const Icon(Icons.check_circle, color: Colors.white, size: 18);
          text = 'Sincronizado';
      }
    }
    return _BannerWidget(
      text: text,
      ledColor: ledColor,
      blinking: blinking,
      action: action,
      icon: icon,
    );
    // Eliminar línea sobrante
  }
}

class _BannerWidget extends StatefulWidget {
  final String text;
  final Color ledColor;
  final bool blinking;
  final Widget? action;
  final Widget? icon;
  const _BannerWidget({
    required this.text,
    required this.ledColor,
    required this.blinking,
    this.action,
    this.icon,
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
      child: IntrinsicWidth(
        child: Container(
          // Elimina width: double.infinity y maxWidth para que el ancho sea dinámico
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
              if (widget.icon != null) ...[
                const SizedBox(width: 6),
                widget.icon!,
              ],
              const SizedBox(width: 8),
              Flexible(
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
      ),
    );
  }
}

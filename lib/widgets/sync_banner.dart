import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import '../providers/sync_provider.dart';
import '../models/client_hive.dart';
import '../models/transaction_hive.dart';

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
      final prev = _isReallyOnline;
      // Notificar transición sin bloquear UI
      _handleConnectivityChange(prev, online);
      if (mounted) setState(() => _isReallyOnline = online);
    } catch (_) {
      final prev = _isReallyOnline;
      // Notificar transición a offline sin bloquear UI
      _handleConnectivityChange(prev, false);
      if (mounted) setState(() => _isReallyOnline = false);
    }
    // Repetir cada 5 segundos
    if (mounted) {
      Future.delayed(const Duration(seconds: 5), _checkRealInternet);
    }
  }

  /// Marca en Hive cuando pasamos de online -> offline para habilitar
  /// la lógica de "authorized offline" sin tocar otras partes.
  Future<void> _handleConnectivityChange(bool? prev, bool curr) async {
    if (prev == true && curr == false) {
      try {
        final box = await Hive.openBox('session');
        final current = box.get('session_state');
        if (current == 'authorized') {
          await box.put('session_state', 'authorized_offline');
          await box.put('was_authorized_offline', true);
          debugPrint(
            '[SYNC-BANNER] Marcado session_state=authorized_offline y was_authorized_offline=true',
          );
        } else if (current == 'authorized_offline') {
          // Asegurar la bandera incluso si ya quedó en authorized_offline previamente
          await box.put('was_authorized_offline', true);
          debugPrint('[SYNC-BANNER] Refuerzo: was_authorized_offline=true');
        }
      } catch (e) {
        debugPrint('[SYNC-BANNER] Error marcando authorized_offline: $e');
      }
    }
  }

  String _bannerText = '';
  Widget? _bannerIcon;
  Widget? _bannerAction;
  Color _bannerLedColor = Colors.green;
  bool _bannerBlinking = false;

  @override
  Widget build(BuildContext context) {
    // Mostrar siempre el banner, tanto offline como online
    if (_isReallyOnline == false) {
      _bannerLedColor = Colors.red;
      _bannerBlinking = true;
      // 1. Actualización instantánea de la UI (sin delays)
      Future.microtask(() async {
        final pendings = await widget.sync.getTotalPendings();
        if (mounted) {
          setState(() {
            if (pendings > 0) {
              _bannerIcon = const Icon(
                Icons.sync,
                color: Colors.white,
                size: 18,
              );
              _bannerText =
                  '${pendings.toString().padLeft(2, '0')} sincronizaciones pendientes';
            } else {
              _bannerIcon = null;
              _bannerText = 'Offline: Trabajando con datos locales';
            }
            _bannerAction = null;
          });
        }
      });
      // 2. Debug lento SOLO para consola (no afecta UI)
      Future.microtask(() async {
        // Delay inicial para que incluso los mensajes de cantidad 0 sean lentos
        await Future.delayed(const Duration(seconds: 10));
        // Se removieron los prints y las variables de Hive no usadas
        // Se removieron los prints y las variables de pendientes clientes y transacciones
        // Se removieron los prints de debug de pendientes clientes y transacciones
      });
    } else {
      switch (widget.sync.status) {
        case SyncStatus.waiting:
        case SyncStatus.syncing:
          _bannerLedColor = Colors.amber;
          _bannerBlinking = true;
          _bannerIcon = const Icon(Icons.sync, color: Colors.white, size: 18);
          // 1. Actualización instantánea de la UI (sin delays)
          Future.microtask(() async {
            final pendings = await widget.sync.getTotalPendings();
            if (mounted) {
              setState(() {
                _bannerText = pendings > 0
                    ? '${pendings.toString().padLeft(2, '0')} sincronizaciones pendientes'
                    : (widget.sync.status == SyncStatus.syncing
                          ? 'Proceso de sincronización ${widget.sync.progress}%'
                          : 'Conexión restablecida. Sincronizando datos pendientes…');
                _bannerAction = null;
              });
            }
          });
          // 2. Debug lento SOLO para consola (no afecta UI)
          Future.microtask(() async {
            Box<ClientHive> clientBox;
            try {
              clientBox = Hive.box<ClientHive>('clients');
            } catch (e) {
              if (Hive.isBoxOpen('clients')) {
                await Hive.box('clients').close();
              }
              clientBox = await Hive.openBox<ClientHive>('clients');
            }
            Box<TransactionHive> txBox;
            try {
              txBox = Hive.box<TransactionHive>('transactions');
            } catch (e) {
              if (Hive.isBoxOpen('transactions')) {
                await Hive.box('transactions').close();
              }
              txBox = await Hive.openBox<TransactionHive>('transactions');
            }
            final pendingClients = clientBox.values.where((c) {
              final isLocalId = c.id.length != 36;
              return (isLocalId ||
                  c.synced == false ||
                  c.pendingDelete == true);
            }).toList();
            final pendingTxsList = txBox.values.where((t) {
              return t.synced == false || t.pendingDelete == true;
            }).toList();
            debugPrint(
              '[SYNC-BANNER][DEBUG] Pendientes clientes: \u001b[33m${pendingClients.length}\u001b[0m',
            );
            await Future.delayed(const Duration(seconds: 10));
            for (final c in pendingClients) {
              debugPrint(
                '[SYNC-BANNER][CLIENT] id=${c.id} name=${c.name} synced=${c.synced} pendingDelete=${c.pendingDelete}',
              );
              await Future.delayed(const Duration(seconds: 10));
            }
            debugPrint(
              '[SYNC-BANNER][DEBUG] Pendientes transacciones: \u001b[36m${pendingTxsList.length}\u001b[0m',
            );
            await Future.delayed(const Duration(seconds: 10));
            for (final t in pendingTxsList) {
              debugPrint(
                '[SYNC-BANNER][TX] id=${t.id} clientId=${t.clientId} synced=${t.synced} pendingDelete=${t.pendingDelete}',
              );
              await Future.delayed(const Duration(seconds: 10));
            }
          });
          _bannerText = widget.sync.status == SyncStatus.syncing
              ? 'Proceso de sincronización ${widget.sync.progress}%'
              : 'Conexión restablecida. Sincronizando datos pendientes…';
          _bannerAction = null;
          break;
        case SyncStatus.success:
        case SyncStatus.idle:
          _bannerLedColor = Colors.green;
          _bannerBlinking = true;
          _bannerIcon = null;
          _bannerText = 'Sincronizado';
          _bannerAction = null;
          break;
        case SyncStatus.error:
          _bannerLedColor = Colors.red;
          _bannerBlinking = true;
          _bannerIcon = const Icon(
            Icons.sync_problem,
            color: Colors.white,
            size: 18,
          );
          _bannerText = 'Error de sincronización';
          _bannerAction = TextButton(
            onPressed: () {
              widget.sync.retrySync(context);
            },
            child: const Text(
              'Reintentar',
              style: TextStyle(color: Colors.white),
            ),
          );
          break;
      }
    }
    return _BannerWidget(
      text: _bannerText,
      ledColor: _bannerLedColor,
      blinking: _bannerBlinking,
      action: _bannerAction,
      icon: _bannerIcon,
    );
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

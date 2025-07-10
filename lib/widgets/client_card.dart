import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../utils/currency_utils.dart';
import '../providers/currency_provider.dart';

class ClientCard extends StatelessWidget {
  final Client client;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddTransaction;
  final VoidCallback? onViewMovements;
  final VoidCallback? onReceipt;
  const ClientCard({
    super.key,
    required this.client,
    this.onEdit,
    this.onDelete,
    this.onAddTransaction,
    this.onViewMovements,
    this.onReceipt,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<CurrencyProvider>();
    final isMobile =
        Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;

    // Mostrar todos los datos relevantes del cliente
    final balance = client.balance;
    final isDeuda = balance < 0;
    final balanceColor = isDeuda ? Colors.red : Colors.green;
    final balanceText = isDeuda
        ? '-${CurrencyUtils.format(context, balance.abs())}'
        : '+${CurrencyUtils.format(context, balance)}';
    final statusText = balance == 0
        ? 'Sin movimientos'
        : isDeuda
        ? 'Deuda pendiente del cliente'
        : 'Saldo a favor del cliente';

    final symbol = CurrencyUtils.symbol(context);
    final formatted = CurrencyUtils.format(context, client.balance);
    final saldo = '$symbol$formatted';

    Widget card = Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: isMobile ? 0 : 8),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(child: Icon(Icons.person)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (client.email != null && client.email!.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.email,
                                size: 14,
                                color: Colors.black45,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  client.email!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        if (client.phone != null && client.phone!.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 14,
                                color: Colors.black45,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  client.phone!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          saldo,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: balanceColor,
                          ),
                        ),
                      ),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: balanceColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ClientCardActions(
                onEdit: onEdit,
                onDelete: onDelete,
                onAddTransaction: onAddTransaction,
                onViewMovements: onViewMovements,
                onReceipt: onReceipt,
              ),
            ],
          ),
        ),
      ),
    );
    return card;
  }
}

class _ClientCardActions extends StatefulWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddTransaction;
  final VoidCallback? onViewMovements;
  final VoidCallback? onReceipt;
  const _ClientCardActions({
    this.onEdit,
    this.onDelete,
    this.onAddTransaction,
    this.onViewMovements,
    this.onReceipt,
  });

  @override
  State<_ClientCardActions> createState() => _ClientCardActionsState();
}

class _ClientCardActionsState extends State<_ClientCardActions>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _close() {
    if (_open) {
      setState(() {
        _open = false;
        _controller.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Centrar los botones de acción en todas las plataformas (móvil y web)
    return Stack(
      children: [
        if (_open)
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.translucent,
              child: Container(),
            ),
          ),
        // Permite scroll horizontal y evita overflow
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  List<Widget> actions = [];
                  if (_open) {
                    actions = [
                      _ActionBtn(
                        icon: Icons.receipt_long,
                        tooltip: 'Recibo',
                        onTap: () {
                          widget.onReceipt?.call();
                          _close();
                        },
                        delay: 0,
                      ),
                      _ActionBtn(
                        icon: Icons.edit,
                        tooltip: 'Editar',
                        onTap: () {
                          widget.onEdit?.call();
                          _close();
                        },
                        delay: 40,
                      ),
                      _ActionBtn(
                        icon: Icons.delete,
                        tooltip: 'Eliminar',
                        onTap: () {
                          widget.onDelete?.call();
                          _close();
                        },
                        delay: 80,
                      ),
                      _ActionBtn(
                        icon: Icons.add,
                        tooltip: 'Agregar deuda/abono',
                        onTap: () {
                          widget.onAddTransaction?.call();
                          _close();
                        },
                        delay: 120,
                      ),
                      _ActionBtn(
                        icon: Icons.list,
                        tooltip: 'Ver movimientos',
                        onTap: () {
                          widget.onViewMovements?.call();
                          _close();
                        },
                        delay: 160,
                      ),
                      IconButton(
                        key: const ValueKey('close'),
                        icon: const Icon(Icons.close),
                        tooltip: 'Cerrar',
                        onPressed: _toggle,
                      ),
                    ];
                  } else {
                    actions = [
                      IconButton(
                        key: const ValueKey('menu'),
                        icon: const Icon(Icons.menu),
                        tooltip: 'Acciones',
                        onPressed: _toggle,
                      ),
                    ];
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: actions,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final int delay;
  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + delay),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(-32 * (1 - value), 0),
            child: IconButton(
              icon: Icon(icon),
              tooltip: tooltip,
              onPressed: onTap,
            ),
          ),
        );
      },
    );
  }
}

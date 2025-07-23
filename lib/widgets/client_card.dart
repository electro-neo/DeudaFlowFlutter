import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../models/client_hive.dart';
import '../models/client.dart';
import '../utils/currency_utils.dart';
import '../providers/currency_provider.dart';
import 'client_details_modal.dart';

class ClientCard extends StatelessWidget {
  final ClientHive client;
  final String userId;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddTransaction;
  final void Function(String clientId)? onViewMovements;
  final VoidCallback? onReceipt;
  const ClientCard({
    super.key,
    required this.client,
    required this.userId,
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
    // Si el cliente no tiene transacciones, el balance debe ser 0
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final hasTransactions = txProvider.transactions.any(
      (tx) => tx.clientId == client.id,
    );
    final balance = hasTransactions ? client.balance : 0.0;
    final isDeuda = balance < 0;
    final balanceColor = isDeuda ? Colors.red : Colors.green;
    // balanceText no se usa, se elimina para evitar warning
    String statusText = balance == 0
        ? 'Sin movimientos'
        : isDeuda
        ? 'Deuda pendiente del cliente'
        : 'Saldo a favor del cliente';
    String? syncText;
    IconData? syncIcon;
    Color? syncColor;
    if (client.pendingDelete) {
      syncText = 'Pendiente de eliminar';
      syncIcon = Icons.delete_forever;
      syncColor = Colors.red[700];
    } else if (!client.synced) {
      syncText = 'Pendiente por sincronizar';
      syncIcon = Icons.sync;
      syncColor = Colors.orange[800];
    } else if (client.synced) {
      syncText = 'Sincronizado';
      syncIcon = Icons.cloud_done;
      syncColor = Colors.green[700];
    }

    final symbol = CurrencyUtils.symbol(context);
    final formatted = CurrencyUtils.format(context, balance);
    final saldo = '$symbol$formatted';

    if (isMobile) {
      // Nombre ocupa el espacio disponible, monto y estado alineados a la derecha, y abre modal con los datos y botones al tocar
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => ClientDetailsModal(
              client: Client.fromHive(client),
              userId: userId,
              onEdit: onEdit,
              onDelete: onDelete,
              onAddTransaction: onAddTransaction,
              onViewMovements: onViewMovements != null
                  ? ((_) => onViewMovements!(client.id))
                  : null,
              onReceipt: onReceipt,
            ),
          );
        },
        child: Card(
          color: const Color.fromARGB(
            255,
            255,
            255,
            255,
          ), // Cambia aquí el color de fondo del cuadro
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 0,
          ), //aqui se fusiona container y card
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 8),
                Container(
                  constraints: BoxConstraints(maxWidth: 100),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Text(
                      client.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              saldo,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: balanceColor,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 12,
                                color: balanceColor,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          if (syncText != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: syncColor != null
                                        ? Color.fromARGB(
                                            (0.10 * 255).round(),
                                            (syncColor.r * 255.0).round() &
                                                0xff,
                                            (syncColor.g * 255.0).round() &
                                                0xff,
                                            (syncColor.b * 255.0).round() &
                                                0xff,
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Icon(
                                        syncIcon,
                                        size: 10,
                                        color: syncColor,
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        syncText,
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: syncColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // WEB/ESCRITORIO: Card completa y menú hamburguesa
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
                          if (syncText != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Icon(syncIcon, size: 13, color: syncColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    syncText,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: syncColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
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
                  onViewMovements: onViewMovements != null
                      ? (() => onViewMovements!(client.id))
                      : null,
                  onReceipt: onReceipt,
                ),
              ],
            ),
          ),
        ),
      );
    }
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
    // isMobile no se usa, se elimina para evitar warning
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
        // Centrado absoluto del botón hamburguesa y acciones
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Center(
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
                        if ((context is Element && context.mounted) ||
                            context is! Element) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Cliente marcado para eliminar. Se eliminará definitivamente al sincronizar.',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
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
      ],
    );
  }

  // --- Widget de acción animada para el menú hamburguesa ---
}

// --- Widget de acción animada para el menú hamburguesa ---
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

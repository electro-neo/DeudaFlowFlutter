import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client_hive.dart';
import '../models/client.dart';
import '../utils/currency_utils.dart';
import '../providers/currency_provider.dart';
import '../providers/transaction_provider.dart';
import 'client_details_modal.dart';
import 'sync_message_state.dart';

// --- ExpandableClientCard y su estado deben estar al tope del archivo para evitar errores de anidación ---
class ExpandableClientCard extends StatefulWidget {
  final ClientHive client;
  final String userId;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddTransaction;
  final void Function(String clientId)? onViewMovements;
  final VoidCallback? onReceipt;
  final String? syncText;
  final IconData? syncIcon;
  final Color? syncColor;
  final SyncMessageState? syncMessage;
  final bool expanded;
  final VoidCallback? onExpand;
  const ExpandableClientCard({
    super.key,
    required this.client,
    required this.userId,
    this.expanded = false,
    this.onExpand,
    this.onEdit,
    this.onDelete,
    this.onAddTransaction,
    this.onViewMovements,
    this.onReceipt,
    this.syncText,
    this.syncIcon,
    this.syncColor,
    this.syncMessage,
  });

  @override
  State<ExpandableClientCard> createState() => _ExpandableClientCardState();
}

class _ExpandableClientCardState extends State<ExpandableClientCard> {
  bool _isAnimating = false;

  void _handleExpand() {
    if (widget.onExpand != null) {
      setState(() => _isAnimating = true);
      widget.onExpand!();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _isAnimating = false);
      });
    }
  }

  void _openModal() {
    if (_isAnimating) return;
    showDialog(
      context: context,
      builder: (_) => ClientDetailsModal(
        client: Client.fromHive(widget.client),
        userId: widget.userId,
        onEdit: widget.onEdit == null
            ? null
            : () {
                if (_isAnimating) return;
                widget.onEdit!();
              },
        onDelete: widget.onDelete == null
            ? null
            : () {
                if (_isAnimating) return;
                widget.onDelete!();
              },
        onAddTransaction: widget.onAddTransaction == null
            ? null
            : () {
                if (_isAnimating) return;
                widget.onAddTransaction!();
              },
        onViewMovements: widget.onViewMovements == null
            ? null
            : ((id) {
                if (_isAnimating) return;
                widget.onViewMovements!(widget.client.id);
              }),
        onReceipt: widget.onReceipt == null
            ? null
            : () {
                if (_isAnimating) return;
                widget.onReceipt!();
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final currencyProvider = Provider.of<CurrencyProvider>(
      context,
      // listen: false, // Elimina esto para que escuche cambios y reconstruya
    );
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    // --- Balance USD real usando anchorUsdValue (ya con signo correcto) ---
    final clientTxs = txProvider.transactions.where(
      (t) => t.clientId == client.id,
    );
    // Suma: si es "deuda" resta, si es "abono" suma
    double usdBalance = 0.0;
    for (var t in clientTxs) {
      final value = t.anchorUsdValue ?? 0.0;
      final type = t.type.toLowerCase();
      if (type == 'debt') {
        usdBalance -= value;
      } else if (type == 'payment') {
        usdBalance += value;
      }
    }
    // Color según balance USD
    Color balanceColor;
    if (usdBalance < 0) {
      balanceColor = Colors.red;
    } else if (usdBalance > 0) {
      balanceColor = Colors.green;
    } else {
      balanceColor = Colors.black87;
    }
    // Siempre muestra USD primero, luego los equivalentes
    final List<MapEntry<String, double>> balancesList = [
      MapEntry('USD', usdBalance),
      ...currencyProvider.availableCurrencies
          .where((code) => code != 'USD')
          .map((code) {
            final rate = currencyProvider.exchangeRates[code] ?? 1.0;
            return MapEntry(code, usdBalance * rate);
          }),
    ];
    final firstLetter = client.name.isNotEmpty
        ? client.name[0].toUpperCase()
        : '?';
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _openModal,
                  child: CircleAvatar(
                    backgroundColor: Colors.indigo.shade50,
                    child: Text(
                      firstLetter,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _openModal,
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
                if (widget.syncMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.syncMessage!.color.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.syncMessage!.icon,
                          size: 13,
                          color: widget.syncMessage!.color,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          widget.syncMessage!.message,
                          style: TextStyle(
                            fontSize: 10,
                            color: widget.syncMessage!.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (widget.syncText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.syncColor?.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.syncIcon,
                          size: 13,
                          color: widget.syncColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          widget.syncText!,
                          style: TextStyle(
                            fontSize: 10,
                            color: widget.syncColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                IconButton(
                  icon: AnimatedRotation(
                    turns: widget.expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.expand_more),
                  ),
                  onPressed: _handleExpand,
                  tooltip: widget.expanded ? 'Ocultar balance' : 'Ver balance',
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(key: ValueKey('collapsed')),
            secondChild: Padding(
              key: const ValueKey('expanded'),
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Datos cliente (izquierda) - Se reemplaza IntrinsicWidth por Expanded
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(
                        left: 16,
                        top: 8,
                        bottom: 8,
                        right: 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 16,
                                color: Colors.black45,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Teléfono',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 22.0,
                              top: 2,
                              bottom: 0,
                            ),
                            child: Text(
                              (client.phone != null && client.phone!.isNotEmpty)
                                  ? client.phone!
                                  : 'Sin información',
                              style: const TextStyle(fontSize: 14),
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.home,
                                size: 16,
                                color: Colors.black45,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Dirección',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 22.0,
                              top: 2,
                              bottom: 0,
                            ),
                            child: Text(
                              (client.address != null &&
                                      client.address!.isNotEmpty)
                                  ? client.address!
                                  : 'Sin información',
                              style: const TextStyle(fontSize: 14),
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Balance (derecha, ancho fijo, scroll si hay más de 4 monedas)
                  SizedBox(
                    width: 190, // Ajusta el ancho según sea necesario
                    child: Container(
                      margin: const EdgeInsets.only(
                        right: 16,
                        top: 8,
                        bottom: 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 22,
                              decoration: BoxDecoration(
                                color: Colors.indigo.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.only(
                                right: 0,
                                left: 0,
                                top: 0,
                                bottom: 0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Balance',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      letterSpacing: 0.5,
                                      color: Colors.indigo,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ],
                              ),
                            ),
                            if (balancesList.length > 3)
                              SizedBox(
                                height:
                                    4 *
                                    18.0, // USD + 3 monedas visibles, luego scroll
                                child: Scrollbar(
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    child: Table(
                                      columnWidths: const {
                                        0: IntrinsicColumnWidth(),
                                        1: FlexColumnWidth(),
                                      },
                                      defaultVerticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      children: [
                                        ...balancesList.map(
                                          (e) => TableRow(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 2,
                                                  right: 8,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Text(
                                                    e.key,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                      color: Colors.indigo,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 2,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Text(
                                                    CurrencyUtils.format(
                                                      context,
                                                      e.value.abs(),
                                                    ),
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15,
                                                      color: balanceColor,
                                                    ),
                                                    textAlign: TextAlign.right,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else
                              Table(
                                columnWidths: const {
                                  0: IntrinsicColumnWidth(),
                                  1: FlexColumnWidth(),
                                },
                                defaultVerticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                children: [
                                  ...balancesList.map(
                                    (e) => TableRow(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 2,
                                            right: 8,
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              e.key,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: Colors.indigo,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 2,
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              CurrencyUtils.format(
                                                context,
                                                e.value.abs(),
                                              ),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: balanceColor,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: widget.expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

// --- Fin de ExpandableClientCard ---

// Versión solo móvil: usa ExpandableClientCard siempre

class ClientCard extends StatelessWidget {
  final ClientHive client;
  final String userId;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddTransaction;
  final void Function(String clientId)? onViewMovements;
  final VoidCallback? onReceipt;
  final SyncMessageState? syncMessage;

  const ClientCard({
    super.key,
    required this.client,
    required this.userId,
    this.onEdit,
    this.onDelete,
    this.onAddTransaction,
    this.onViewMovements,
    this.onReceipt,
    this.syncMessage,
  });

  @override
  Widget build(BuildContext context) {
    // Si hay mensaje temporal, úsalo; si no, usa el mensaje por defecto centralizado (puede ser null)
    final SyncMessageState? effectiveSync =
        syncMessage ?? SyncMessageState.fromClient(client);
    return ExpandableClientCard(
      key: ValueKey('${client.id}_${client.pendingDelete}'),
      client: client,
      userId: userId,
      onEdit: onEdit,
      onDelete: onDelete,
      onAddTransaction: onAddTransaction,
      onViewMovements: onViewMovements,
      onReceipt: onReceipt,
      syncText: null, // Solo usa syncMessage
      syncIcon: null,
      syncColor: null,
      syncMessage: effectiveSync,
    );
  }
}

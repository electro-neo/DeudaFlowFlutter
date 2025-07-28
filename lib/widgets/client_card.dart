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
  const ExpandableClientCard({
    super.key,
    required this.client,
    required this.userId,
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
  bool _expanded = false;
  bool _isAnimating = false;

  void _toggleExpand() {
    setState(() {
      _isAnimating = true;
      _expanded = !_expanded;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _isAnimating = false);
    });
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
      listen: false,
    );
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final availableCurrencies = currencyProvider.availableCurrencies;
    // --- Balance USD real usando anchorUsdValue ---
    final clientTxs = txProvider.transactions.where(
      (t) => t.clientId == client.id,
    );
    final usdBalance = clientTxs.fold<double>(
      0.0,
      (sum, t) => sum + (t.anchorUsdValue ?? 0.0),
    );
    final balances = <String, double>{};
    balances['USD'] = usdBalance;
    // Para cada moneda, suma los amount de las transacciones en esa moneda
    for (final code in availableCurrencies) {
      if (code != 'USD') {
        final sumInCurrency = clientTxs
            .where((t) => t.currencyCode.toUpperCase() == code)
            .fold<double>(0.0, (sum, t) => sum + t.amount);
        balances[code] = sumInCurrency;
      }
    }
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
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.expand_more),
                  ),
                  onPressed: _toggleExpand,
                  tooltip: _expanded ? 'Ocultar balance' : 'Ver balance',
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
                  // Datos cliente (izquierda)
                  IntrinsicWidth(
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
                  // Balance (derecha, ancho fijo)
                  SizedBox(
                    width: 180,
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
                            Table(
                              columnWidths: const {
                                0: IntrinsicColumnWidth(),
                                1: FlexColumnWidth(),
                              },
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              children: [
                                ...balances.entries.map(
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
                                              e.value,
                                            ),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: e.value < 0
                                                  ? Colors.red
                                                  : Colors.green,
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
            crossFadeState: _expanded
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

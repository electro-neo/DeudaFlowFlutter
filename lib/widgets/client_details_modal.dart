import 'package:flutter/material.dart';
import '../models/client.dart';
import 'package:provider/provider.dart';
import '../widgets/transaction_form.dart';
import '../providers/transaction_provider.dart';
import '../providers/client_provider.dart';
import '../widgets/general_receipt_modal.dart';
import 'package:characters/characters.dart';
import '../utils/string_sanitizer.dart';
// import '../providers/tab_provider.dart';
// import '../providers/transaction_filter_provider.dart';

class ClientDetailsModal extends StatelessWidget {
  final Client client;
  final String userId;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddTransaction;
  final void Function(String clientId)? onViewMovements;
  final VoidCallback? onReceipt;

  const ClientDetailsModal({
    super.key,
    required this.client,
    required this.userId,
    this.onEdit,
    this.onDelete,
    this.onAddTransaction,
    this.onViewMovements,
    this.onReceipt,
  });

  // Botón reutilizable compacto con fondo y marco
  Widget _actionBtn({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double size = 36, // tamaño del botón
    double iconSize = 18, // tamaño del ícono
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(
        color: color.withValues(alpha: 0.50),
        width: 1,
      ), // 50% opacidad
    );

    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.09), // 9% opacidad (traslúcido)
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Icon(icon, color: color, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final String firstLetter = client.name.trim().isNotEmpty
        ? client.name.trim().characters.first.toUpperCase()
        : '?';
    final String safeName = StringSanitizer.sanitizeForText(client.name);
    final String safePhone = StringSanitizer.sanitizeForText(
      (client.phone != null && client.phone!.isNotEmpty)
          ? client.phone!
          : 'Sin información',
    );
    final String safeAddress = StringSanitizer.sanitizeForText(
      (client.address != null && client.address!.isNotEmpty)
          ? client.address!
          : 'Sin información',
    );
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información del cliente
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.indigo.shade50,
                  child: Text(
                    StringSanitizer.sanitizeForText(firstLetter),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    safeName.isNotEmpty ? safeName : 'Sin información',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Teléfono
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.black45),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Teléfono:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        safePhone,
                        style: const TextStyle(fontSize: 16),
                        enableInteractiveSelection: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Dirección
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.home, size: 16, color: Colors.black45),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dirección:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        safeAddress,
                        style: const TextStyle(fontSize: 16),
                        enableInteractiveSelection: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Una sola fila con los 5 botones compactos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _actionBtn(
                  tooltip: 'Recibo',
                  icon: Icons.receipt_long,
                  color: Colors.deepPurple,
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    Future.delayed(Duration.zero, () {
                      // ignore: use_build_context_synchronously
                      final txProvider = Provider.of<TransactionProvider>(
                        // ignore: use_build_context_synchronously
                        rootContext,
                        listen: false,
                      );
                      final clientData = [
                        {
                          'client': client,
                          'transactions': txProvider.transactions
                              .where((tx) => tx.clientId == client.id)
                              .toList(),
                        },
                      ];
                      showDialog(
                        // ignore: use_build_context_synchronously
                        context: rootContext,
                        builder: (_) =>
                            GeneralReceiptModal(clientData: clientData),
                      );
                    });
                  },
                ),
                _actionBtn(
                  tooltip: 'Editar',
                  icon: Icons.edit,
                  color: Colors.blue,
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    if (onEdit != null) {
                      Future.delayed(Duration.zero, onEdit!);
                    }
                  },
                ),
                _actionBtn(
                  tooltip: 'Eliminar',
                  icon: Icons.delete,
                  color: Colors.red,
                  onPressed: () {
                    debugPrint(
                      '[CLIENT_DETAILS_MODAL] Botón Eliminar PRESIONADO para cliente: id=${client.id}, name=${client.name}',
                    );
                    Navigator.of(context, rootNavigator: true).pop();
                    if (onDelete != null) {
                      Future.delayed(Duration.zero, onDelete!);
                    }
                  },
                ),
                _actionBtn(
                  tooltip: 'Agregar deuda/abono',
                  icon: Icons.add,
                  color: Colors.green,
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    Future.delayed(Duration.zero, () {
                      showDialog(
                        // ignore: use_build_context_synchronously
                        context: rootContext,
                        builder: (dialogContext) => Builder(
                          builder: (innerContext) {
                            return TransactionForm(
                              userId: userId,
                              initialClient: client,
                              onClose: () => Navigator.of(
                                dialogContext,
                                rootNavigator: true,
                              ).pop(),
                              onSave: (tx) async {
                                final txProvider =
                                    Provider.of<TransactionProvider>(
                                      dialogContext,
                                      listen: false,
                                    );
                                final clientProvider =
                                    Provider.of<ClientProvider>(
                                      dialogContext,
                                      listen: false,
                                    );
                                final scaffoldMessenger = ScaffoldMessenger.of(
                                  dialogContext,
                                );
                                await txProvider.addTransaction(
                                  tx,
                                  userId,
                                  client.id,
                                );
                                await txProvider.loadTransactions(userId);
                                await clientProvider.loadClients(userId);
                                // Cierre del diálogo: lo manejará TransactionForm vía onClose.
                                try {
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Transacción guardada correctamente',
                                      ),
                                    ),
                                  );
                                } catch (_) {}
                              },
                            );
                          },
                        ),
                      );
                    });
                  },
                ),
                _actionBtn(
                  tooltip: 'Ver movimientos',
                  icon: Icons.list,
                  color: Colors.orange,
                  onPressed: () {
                    debugPrint(
                      '[CLIENT_DETAILS_MODAL] Botón Ver movimientos PRESIONADO para cliente: ${client.id}',
                    );
                    Navigator.of(context, rootNavigator: true).pop();
                    if (onViewMovements != null) {
                      Future.delayed(
                        Duration.zero,
                        () => onViewMovements!(client.id),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

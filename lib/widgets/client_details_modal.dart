import 'package:flutter/material.dart';
import '../models/client.dart';
import 'package:provider/provider.dart';
import '../widgets/transaction_form.dart';
import '../providers/transaction_provider.dart';
import '../providers/client_provider.dart';
import '../widgets/general_receipt_modal.dart';
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

  @override
  Widget build(BuildContext context) {
    final rootContext = Navigator.of(context, rootNavigator: true).context;
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
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    client.name.isNotEmpty ? client.name : 'Sin información',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.black45),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Teléfono: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: SelectableText(
                          (client.phone != null && client.phone!.isNotEmpty)
                              ? client.phone!
                              : 'Sin información',
                          style: const TextStyle(fontSize: 16),
                          enableInteractiveSelection: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.home, size: 16, color: Colors.black45),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dirección: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: SelectableText(
                          (client.address != null && client.address!.isNotEmpty)
                              ? client.address!
                              : 'Sin información',
                          style: const TextStyle(fontSize: 16),
                          enableInteractiveSelection: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Tooltip(
                  message: 'Recibo',
                  child: IconButton(
                    icon: const Icon(Icons.receipt_long, size: 26),
                    color: Colors.deepPurple,
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      Future.delayed(Duration.zero, () {
                        final txProvider = Provider.of<TransactionProvider>(
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
                          context: rootContext,
                          builder: (_) =>
                              GeneralReceiptModal(clientData: clientData),
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(width: 0),
                Tooltip(
                  message: 'Editar',
                  child: IconButton(
                    icon: const Icon(Icons.edit, size: 26),
                    color: Colors.blue,
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      if (onEdit != null) {
                        Future.delayed(Duration.zero, onEdit!);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 0),
                Tooltip(
                  message: 'Eliminar',
                  child: IconButton(
                    icon: const Icon(Icons.delete, size: 26),
                    color: Colors.red,
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      if (onDelete != null) {
                        Future.delayed(Duration.zero, onDelete!);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 0),
                Tooltip(
                  message: 'Agregar deuda/abono',
                  child: IconButton(
                    icon: const Icon(Icons.add, size: 26),
                    color: Colors.green,
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      Future.delayed(Duration.zero, () {
                        // Envolver TransactionForm con Consumer<CurrencyProvider> para asegurar acceso
                        showDialog(
                          context: rootContext,
                          builder: (dialogContext) => Builder(
                            builder: (innerContext) {
                              // Si CurrencyProvider está en el árbol, úsalo; si no, muestra igual
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
                                  final navigator = Navigator.of(
                                    dialogContext,
                                    rootNavigator: true,
                                  );
                                  final scaffoldMessenger =
                                      ScaffoldMessenger.of(dialogContext);
                                  await txProvider.addTransaction(
                                    tx,
                                    userId,
                                    client.id,
                                  );
                                  await txProvider.loadTransactions(userId);
                                  await clientProvider.loadClients(userId);
                                  if (navigator.mounted && navigator.canPop()) {
                                    navigator.pop();
                                  }
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
                ),
                const SizedBox(width: 0),
                Tooltip(
                  message: 'Ver movimientos',
                  child: IconButton(
                    icon: const Icon(Icons.list, size: 26),
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

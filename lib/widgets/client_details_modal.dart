import 'package:flutter/material.dart';
import '../models/client.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_filter_provider.dart';
import '../screens/transactions_screen.dart';
import '../widgets/transaction_form.dart';
import '../providers/transaction_provider.dart';
import '../providers/client_provider.dart';
import '../widgets/general_receipt_modal.dart';

class ClientDetailsModal extends StatelessWidget {
  final Client client;
  final String userId;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddTransaction;
  final VoidCallback? onViewMovements;
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    client.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (client.email != null && client.email!.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.email, size: 16, color: Colors.black45),
                  const SizedBox(width: 6),
                  Expanded(child: Text(client.email!)),
                ],
              ),
            if (client.phone != null && client.phone!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.phone, size: 16, color: Colors.black45),
                    const SizedBox(width: 6),
                    Expanded(child: Text(client.phone!)),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            // Botones de acción SIEMPRE visibles, sin hamburguesa, responsivos
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.receipt_long),
                  tooltip: 'Recibo',
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    Future.delayed(Duration.zero, () {
                      final txProvider = Provider.of<TransactionProvider>(
                        context,
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
                        context: context,
                        builder: (_) =>
                            GeneralReceiptModal(clientData: clientData),
                      );
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Editar',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Eliminar',
                  onPressed: () async {
                    Navigator.of(context, rootNavigator: true).pop();
                    // Limpieza local de clientes nunca sincronizados marcados para eliminar
                    final provider = Provider.of<ClientProvider>(
                      context,
                      listen: false,
                    );
                    await provider.cleanLocalPendingDeletedClients();
                    if (onDelete != null) {
                      Future.delayed(Duration.zero, onDelete!);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Agregar deuda/abono',
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    Future.delayed(Duration.zero, () {
                      showDialog(
                        context: context,
                        builder: (dialogContext) => TransactionForm(
                          userId: userId,
                          initialClient: client,
                          onClose: () => Navigator.of(
                            dialogContext,
                            rootNavigator: true,
                          ).pop(),
                          onSave: (tx) async {
                            // Guarda la transacción y refresca clientes para actualizar el balance
                            final txProvider = Provider.of<TransactionProvider>(
                              dialogContext,
                              listen: false,
                            );
                            final clientProvider = Provider.of<ClientProvider>(
                              dialogContext,
                              listen: false,
                            );
                            await txProvider.addTransaction(
                              tx,
                              userId,
                              client.id,
                            );
                            await txProvider.loadTransactions(userId);
                            await clientProvider.loadClients(userId);
                            if (Navigator.of(
                              dialogContext,
                              rootNavigator: true,
                            ).canPop()) {
                              Navigator.of(
                                dialogContext,
                                rootNavigator: true,
                              ).pop();
                            }
                            // Opcional: mostrar un snackbar de éxito
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Transacción guardada correctamente',
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.list),
                  tooltip: 'Ver movimientos',
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    if (onViewMovements != null) {
                      Future.delayed(Duration.zero, onViewMovements!);
                    } else {
                      final navigator = Navigator.of(
                        context,
                        rootNavigator: true,
                      );
                      final filterProvider =
                          Provider.of<TransactionFilterProvider>(
                            context,
                            listen: false,
                          );
                      filterProvider.setClientId(client.id);
                      Future.delayed(Duration.zero, () {
                        // Verifica si el contexto sigue montado antes de usarlo
                        if (navigator.mounted) {
                          navigator.push(
                            MaterialPageRoute(
                              builder: (_) => TransactionsScreen(
                                userId: userId,
                                initialClientId: client.id,
                              ),
                            ),
                          );
                        }
                      });
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

import 'package:flutter/material.dart';
import '../models/client.dart';

class ClientDetailsModal extends StatelessWidget {
  final Client client;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddTransaction;
  final VoidCallback? onViewMovements;
  final VoidCallback? onReceipt;

  const ClientDetailsModal({
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
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                IconButton(
                  icon: const Icon(Icons.receipt_long),
                  tooltip: 'Recibo',
                  onPressed: onReceipt,
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Editar',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Eliminar',
                  onPressed: onDelete,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Agregar deuda/abono',
                  onPressed: onAddTransaction,
                ),
                IconButton(
                  icon: const Icon(Icons.list),
                  tooltip: 'Ver movimientos',
                  onPressed: onViewMovements,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

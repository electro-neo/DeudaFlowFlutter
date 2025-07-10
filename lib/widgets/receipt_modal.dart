import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/client.dart';
import '../models/transaction.dart';
import '../utils/pdf_utils.dart';

class ReceiptModal extends StatelessWidget {
  final Client client;
  final List<Transaction> transactions;
  const ReceiptModal({
    super.key,
    required this.client,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    DateTime? fromDate;
    DateTime? toDate;
    List<Transaction> filteredTransactions = transactions;
    return StatefulBuilder(
      builder: (context, setState) {
        filteredTransactions = transactions.where((tx) {
          final txDate = tx.date;
          final afterFrom = fromDate == null || !txDate.isBefore(fromDate!);
          final beforeTo = toDate == null || !txDate.isAfter(toDate!);
          return afterFrom && beforeTo;
        }).toList();
        return AlertDialog(
          title: Text('Recibo del cliente ${client.name}'),
          content: SizedBox(
            width: 350,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ID: ${client.id}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            fromDate == null
                                ? 'Desde'
                                : '${fromDate!.day.toString().padLeft(2, '0')}/${fromDate!.month.toString().padLeft(2, '0')}/${fromDate!.year}',
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: fromDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setState(() => fromDate = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            toDate == null
                                ? 'Hasta'
                                : '${toDate!.day.toString().padLeft(2, '0')}/${toDate!.month.toString().padLeft(2, '0')}/${toDate!.year}',
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: toDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) setState(() => toDate = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...filteredTransactions.map(
                    (tx) => ListTile(
                      title: Text(
                        '${tx.type == 'debt' ? 'Deuda' : 'Abono'}: ${tx.amount.toStringAsFixed(2)}',
                      ),
                      subtitle: Text(tx.description),
                      trailing: Text('${tx.date.toLocal()}'.split(' ')[0]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Saldo actual: ${client.balance.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final isMobileOrSmall =
                          (Theme.of(context).platform ==
                                  TargetPlatform.android ||
                              Theme.of(context).platform ==
                                  TargetPlatform.iOS) ||
                          MediaQuery.of(context).size.width < 600;
                      if (isMobileOrSmall && !kIsWeb) {
                        return ElevatedButton.icon(
                          icon: const Icon(Icons.share),
                          label: const Text('Compartir'),
                          onPressed: () async {
                            // Exportar y compartir el PDF
                            await exportAndShareClientReceiptPDF(
                              client,
                              filteredTransactions,
                            );
                          },
                        );
                      } else {
                        return ElevatedButton(
                          onPressed: () => exportClientReceiptToPDF(
                            client,
                            filteredTransactions,
                          ),
                          child: const Text('Exportar a PDF'),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}

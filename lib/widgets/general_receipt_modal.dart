import 'package:flutter/material.dart';
import '../models/client.dart';
import '../utils/pdf_utils.dart';
import 'package:flutter/foundation.dart';

/// Estructura: [{client: Client, transactions: List<Transaction>}]

class GeneralReceiptModal extends StatefulWidget {
  final List<Map<String, dynamic>> clientData;
  const GeneralReceiptModal({super.key, required this.clientData});

  @override
  State<GeneralReceiptModal> createState() => _GeneralReceiptModalState();
}

class _GeneralReceiptModalState extends State<GeneralReceiptModal> {
  DateTime? fromDate;
  DateTime? toDate;

  List<Map<String, dynamic>> filteredClientBalances() {
    return widget.clientData
        .map((entry) {
          final c = entry['client'] as Client;
          final txs = entry['transactions'] as List<dynamic>?;
          final filteredTxs = (txs ?? []).where((tx) {
            final txDate = tx.date;
            if (fromDate != null && toDate != null) {
              final from = DateTime(
                fromDate!.year,
                fromDate!.month,
                fromDate!.day,
                0,
                0,
                0,
              );
              final to = DateTime(
                toDate!.year,
                toDate!.month,
                toDate!.day,
                23,
                59,
                59,
                999,
              );
              return !txDate.isBefore(from) && !txDate.isAfter(to);
            } else if (fromDate != null) {
              final from = DateTime(
                fromDate!.year,
                fromDate!.month,
                fromDate!.day,
                0,
                0,
                0,
              );
              return !txDate.isBefore(from);
            } else if (toDate != null) {
              final to = DateTime(
                toDate!.year,
                toDate!.month,
                toDate!.day,
                23,
                59,
                59,
                999,
              );
              return !txDate.isAfter(to);
            }
            return true;
          }).toList();
          final balance = filteredTxs.isEmpty
              ? 0.0
              : filteredTxs.fold<double>(0, (sum, tx) {
                  if (tx.type == 'deuda') {
                    return sum - (tx.amount as num).toDouble();
                  } else {
                    return sum + (tx.amount as num).toDouble();
                  }
                });
          return {
            'client': c,
            'balance': balance,
            'hasMovements': filteredTxs.isNotEmpty,
            'filteredTxs': filteredTxs,
          };
        })
        .where((e) => true)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredClientBalances();
    String title;
    if (widget.clientData.length == 1 &&
        widget.clientData[0]['client'] != null) {
      final Client c = widget.clientData[0]['client'] as Client;
      title = 'Recibo del cliente ${c.name}';
    } else {
      title = 'Recibo General de Clientes';
    }

    // Detect platform correctamente
    final platform = Theme.of(context).platform;
    final bool isMobile =
        !kIsWeb &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      fromDate == null
                          ? 'Desde'
                          : '${fromDate!.day.toString().padLeft(2, '0')}/${fromDate!.month.toString().padLeft(2, '0')}/${fromDate!.year}',
                      style: const TextStyle(fontWeight: FontWeight.normal),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(width: 2),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fromDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => fromDate = picked);
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
                      style: const TextStyle(fontWeight: FontWeight.normal),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(width: 2),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: toDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => toDate = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              const Text('No hay movimientos en el rango seleccionado.'),
            ...filtered.map((e) {
              final client = e['client'];
              final phone =
                  (client.phone != null &&
                      client.phone.toString().trim().isNotEmpty)
                  ? client.phone.toString()
                  : 'Sin Información';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nombre: ${client.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Teléfono: $phone'),
                  Text('ID: ${client.id}'),
                  const SizedBox(height: 12),
                ],
              );
            }),
            if (filtered.isNotEmpty)
              ElevatedButton(
                onPressed: () async {
                  if (isMobile) {
                    await exportAndShareGeneralReceiptWithMovementsPDF(
                      filtered,
                    );
                  } else {
                    await exportGeneralReceiptWithMovementsPDF(filtered);
                  }
                },
                child: Text(isMobile ? 'Compartir Recibo' : 'Imprimir'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

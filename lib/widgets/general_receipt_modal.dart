import 'package:flutter/material.dart';
import '../models/client.dart';
import '../utils/pdf_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../utils/currency_utils.dart';

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
              final inRange = !txDate.isBefore(from) && !txDate.isAfter(to);
              return inRange;
            } else if (fromDate != null) {
              final from = DateTime(
                fromDate!.year,
                fromDate!.month,
                fromDate!.day,
                0,
                0,
                0,
              );
              final inRange = !txDate.isBefore(from);
              return inRange;
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
              final inRange = !txDate.isAfter(to);
              return inRange;
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24), // Puedes reducir horizontal para permitir más ancho
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
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
        ],
      ),
      content: SizedBox(
        width: 350, // <-- Ajusta aquí el ancho del modal
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (filtered.isEmpty)
                const Text('No hay movimientos en el rango seleccionado.'),
              ...filtered.map((e) {
                final client = e['client'];
                final phone =
                    (client.phone != null &&
                        client.phone.toString().trim().isNotEmpty)
                    ? client.phone.toString()
                    : 'Sin Información';
                final filteredTxs = e['filteredTxs'] as List<dynamic>;
                final currencyProvider = Provider.of<CurrencyProvider>(
                  context,
                  listen: false,
                );
                final convertCurrency = currencyProvider.currency == 'USD';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: [
                          const TextSpan(text: 'Nombre: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: client.name ?? ''),
                        ],
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: [
                          const TextSpan(text: 'Teléfono: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: phone),
                        ],
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: [
                          const TextSpan(text: 'ID: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: client.id != null ? client.id.toString() : ''),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (filteredTxs.isEmpty)
                      const Text(
                        'No hay movimientos en el rango seleccionado.',
                        style: TextStyle(color: Colors.red),
                      ),
                    if (filteredTxs.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...filteredTxs.map((tx) {
                            String tipo = tx.type;
                            if (tipo == 'payment') {
                              tipo = 'Abono';
                            } else if (tipo == 'debt') {
                              tipo = 'Deuda';
                            }
                            // Se usa CurrencyUtils.format que ya se encarga de la conversión
                            final rawMonto = CurrencyUtils.format(
                              context,
                              tx.amount,
                            );
                            // Obtener símbolo de moneda si es USD
                            final currencySymbol = CurrencyUtils.symbol(
                              context,
                            );
                            // Asegurar que el símbolo esté al inicio si es USD
                            final monto =
                                currencySymbol.isNotEmpty &&
                                    !rawMonto.trim().startsWith(currencySymbol)
                                ? '$currencySymbol$rawMonto'
                                : rawMonto;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2.0,
                              ),
                              child: Text(
                                '• $tipo - $monto - ${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }),
                        ],
                      ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (filtered.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      child: ElevatedButton.icon(
                        icon: Icon(isMobile ? Icons.share : Icons.print),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        onPressed: () async {
                          final currencyProvider =
                              Provider.of<CurrencyProvider>(
                                context,
                                listen: false,
                              );
                          final convertCurrency =
                              currencyProvider.currency == 'USD';
                          final conversionRate = currencyProvider.rate;
                          // Usar el símbolo de dólar correcto
                          final currencySymbol = convertCurrency ? '\$' : '';
                          if (isMobile) {
                            await exportAndShareGeneralReceiptWithMovementsPDF(
                              filtered,
                              convertCurrency: convertCurrency,
                              conversionRate: conversionRate,
                              currencySymbol: currencySymbol,
                            );
                          } else {
                            await exportGeneralReceiptWithMovementsPDF(
                              filtered,
                              convertCurrency: convertCurrency,
                              conversionRate: conversionRate,
                              currencySymbol: currencySymbol,
                            );
                          }
                        },
                        label: Text(isMobile ? 'Compartir Recibo' : 'Imprimir'),
                      ),
                    ),
                  ],
                ),
              if (filtered.isNotEmpty) const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 180, // <-- Ajusta aquí el ancho del botón Cerrar
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      label: const Text('Cerrar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

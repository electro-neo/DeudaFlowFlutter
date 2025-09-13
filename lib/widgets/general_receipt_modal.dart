import 'package:flutter/material.dart';
import '../models/client.dart';
import '../utils/pdf_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../utils/currency_utils.dart';
import '../utils/string_sanitizer.dart';
import '../services/ad_service.dart';

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

          // Ordenar: más recientes primero
          DateTime parseDate(dynamic d) {
            if (d is DateTime) return d;
            return DateTime.tryParse(d.toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0);
          }

          filteredTxs.sort(
            (a, b) => parseDate(b.date).compareTo(parseDate(a.date)),
          );

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
    final currencyProvider = Provider.of<CurrencyProvider>(
      context,
      listen: false,
    );
    final selectedCurrency = currencyProvider.currency;
    // FIX: Se usa el método getRateFor para obtener la tasa correcta.
    final conversionRate = currencyProvider.getRateFor(selectedCurrency) ?? 1.0;
    final filtered = filteredClientBalances();
    String title;
    if (widget.clientData.length == 1 &&
        widget.clientData[0]['client'] != null) {
      final Client c = widget.clientData[0]['client'] as Client;
      title = 'Recibo del cliente ${StringSanitizer.sanitizeForText(c.name)}';
    } else {
      title = 'Recibo General de Clientes';
    }

    // Detect platform correctamente
    final platform = Theme.of(context).platform;
    final bool isMobile =
        !kIsWeb &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 24,
      ), // Puedes reducir horizontal para permitir más ancho
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
                final client = e['client'] as Client;
                final name = StringSanitizer.sanitizeForText(client.name);
                final phone =
                    (client.phone != null &&
                        client.phone.toString().trim().isNotEmpty)
                    ? StringSanitizer.sanitizeForText(client.phone.toString())
                    : 'Sin Información';
                final filteredTxs = e['filteredTxs'] as List<dynamic>;
                final baseTextStyle = Theme.of(context).textTheme.bodyMedium;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre
                    RichText(
                      textAlign: TextAlign.left,
                      textWidthBasis: TextWidthBasis.parent,
                      text: TextSpan(
                        style: baseTextStyle,
                        children: [
                          const TextSpan(
                            text: 'Nombre: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: name),
                        ],
                      ),
                    ),
                    // Teléfono
                    RichText(
                      textAlign: TextAlign.left,
                      textWidthBasis: TextWidthBasis.parent,
                      text: TextSpan(
                        style: baseTextStyle,
                        children: [
                          const TextSpan(
                            text: 'Teléfono: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: phone),
                        ],
                      ),
                    ),
                    // ID
                    RichText(
                      textAlign: TextAlign.left,
                      textWidthBasis: TextWidthBasis.parent,
                      text: TextSpan(
                        style: baseTextStyle,
                        children: [
                          const TextSpan(
                            text: 'ID: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: StringSanitizer.sanitizeForText(
                              client.id.toString(),
                            ),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (filteredTxs.isEmpty)
                      Container(
                        width: double.infinity,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No hay movimientos en el rango seleccionado.',
                          style: (baseTextStyle ?? const TextStyle()).copyWith(
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),

                    if (filteredTxs.isNotEmpty)
                      Container(
                        width: double.infinity,
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...filteredTxs.map((tx) {
                              String tipo = tx.type;
                              if (tipo == 'payment') {
                                tipo = 'Abono';
                              } else if (tipo == 'debt') {
                                tipo = 'Deuda';
                              }

                              final usdValue = tx.anchorUsdValue ?? tx.amount;
                              final formattedDate =
                                  '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}';
                              final usdString = CurrencyUtils.format(
                                context,
                                usdValue,
                                currencyCode: 'USD',
                              );

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Fecha: $formattedDate',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                      textAlign: TextAlign.left,
                                    ),
                                    const SizedBox(height: 2),
                                    // Tipo (label + valor)
                                    RichText(
                                      textAlign: TextAlign.left,
                                      text: TextSpan(
                                        style:
                                            baseTextStyle?.copyWith(
                                              fontSize: 14,
                                            ) ??
                                            const TextStyle(fontSize: 14),
                                        children: [
                                          const TextSpan(
                                            text: 'Tipo: ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          TextSpan(text: tipo),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      usdString,
                                      style: const TextStyle(fontSize: 14),
                                      textAlign: TextAlign.left,
                                    ),
                                    if (selectedCurrency != 'USD' &&
                                        conversionRate > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        CurrencyUtils.format(
                                          context,
                                          usdValue * conversionRate,
                                          currencyCode: selectedCurrency,
                                        ),
                                        style: const TextStyle(fontSize: 14),
                                        textAlign: TextAlign.left,
                                      ),
                                    ],
                                    const Divider(height: 16),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
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
                          // Obtener monedas registradas y tasas
                          final registeredCurrencies =
                              currencyProvider.availableCurrencies;
                          final rates = Map.fromEntries(
                            registeredCurrencies.map(
                              (symbol) => MapEntry(
                                symbol,
                                currencyProvider.getRateFor(symbol) ?? 1.0,
                              ),
                            ),
                          );
                          // Diálogo de selección de monedas
                          List<String> selected = [];
                          await showDialog(
                            context: context,
                            builder: (ctx) {
                              return StatefulBuilder(
                                builder: (ctx, setStateDialog) {
                                  return AlertDialog(
                                    title: const Text(
                                      'Selecciona monedas (máximo 2)',
                                    ),
                                    content: Wrap(
                                      spacing: 8,
                                      children: registeredCurrencies.map((
                                        symbol,
                                      ) {
                                        final isSelected = selected.contains(
                                          symbol,
                                        );
                                        return ChoiceChip(
                                          label: Text(symbol),
                                          selected: isSelected,
                                          onSelected: (val) {
                                            setStateDialog(() {
                                              if (val) {
                                                if (selected.length < 2) {
                                                  selected.add(symbol);
                                                }
                                              } else {
                                                selected.remove(symbol);
                                              }
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: selected.isEmpty
                                            ? null
                                            : () => Navigator.of(ctx).pop(),
                                        child: const Text('Aceptar'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                          // Construir la lista de monedas seleccionadas con símbolo y tasa
                          final selectedCurrencies = selected
                              .map(
                                (symbol) => {
                                  'symbol': symbol,
                                  'rate': rates[symbol] ?? 1.0,
                                },
                              )
                              .toList();
                          // Pedir que el usuario vea un anuncio recompensado
                          final allowed = await AdService.instance
                              .showRewardedAd(context);
                          if (!allowed) {
                            // Si el usuario no ganó la recompensa, mostrar mensaje
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Necesitas ver el anuncio completo para exportar el recibo.',
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                          if (isMobile) {
                            await exportAndShareGeneralReceiptWithMovementsPDF(
                              filtered,
                              selectedCurrencies: selectedCurrencies,
                            );
                          } else {
                            await exportGeneralReceiptWithMovementsPDF(
                              filtered,
                              selectedCurrencies: selectedCurrencies,
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

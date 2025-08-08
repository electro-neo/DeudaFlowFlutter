import 'package:flutter/material.dart';

import '../models/client.dart';
import 'sync_message_state.dart';

class TransactionCard extends StatelessWidget {
  final dynamic transaction;
  final Client client;
  final String Function(dynamic) format;
  final bool clientPendingDelete;
  final bool isOffline;
  final List<String> availableCurrencies;
  final Map<String, double> exchangeRates;
  final String selectedCurrency;
  final void Function(String) onCurrencySelected;
  final SyncMessageStateTX? syncMessage;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.client,
    required this.format,
    required this.clientPendingDelete,
    required this.isOffline,
    required this.availableCurrencies,
    required this.exchangeRates,
    required this.selectedCurrency,
    required this.onCurrencySelected,
    this.syncMessage,
  });

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    // Lógica corregida:
    // 1. Prioriza el mensaje temporal (ej. "Sincronizando", "Sincronizado").
    // 2. Si no hay mensaje temporal, calcula el mensaje por defecto basado en el estado de la transacción.
    final SyncMessageStateTX? syncMsg;
    if (syncMessage != null) {
      // Si hay un mensaje temporal proporcionado, úsalo siempre.
      syncMsg = syncMessage;
    } else {
      // Si no hay mensaje temporal, determina el mensaje por defecto.
      syncMsg = SyncMessageStateTX.fromTransaction(
        t,
        clientPendingDelete: clientPendingDelete,
        isOffline: isOffline,
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(
              255,
              11,
              11,
              11,
            ).withAlpha((0.25 * 255).toInt()),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- ICONO IZQUIERDA ---
            CircleAvatar(
              backgroundColor: t.type == 'debt'
                  ? const Color(0xFFFFE5E5)
                  : const Color(0xFFE5FFE8),
              radius: 16,
              child: Icon(
                t.type == 'debt' ? Icons.arrow_downward : Icons.arrow_upward,
                color: t.type == 'debt' ? Colors.red : Colors.green,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),

            // --- CONTENIDO PRINCIPAL ---
            Expanded(
              child: Column(
                children: [
                  // --- ROW 1: NOMBRE CLIENTE ---
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      client.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // --- ROW 2: DESCRIPCIÓN Y FECHA ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          t.description != null &&
                                  t.description is String &&
                                  t.description.isNotEmpty
                              ? t.description[0].toUpperCase() +
                                    t.description.substring(1)
                              : 'Sin descripción',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // --- ROW 3: MONTO / BALANCE ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            () {
                              final usdValue =
                                  t.anchorUsdValue ?? t.amount ?? 0.0;
                              if (selectedCurrency == 'USD') {
                                return 'USD ${usdValue.toStringAsFixed(2)}';
                              } else {
                                final rate =
                                    exchangeRates[selectedCurrency] ?? 1.0;
                                final convertedValue = usdValue * rate;
                                return '${convertedValue.toStringAsFixed(2)} $selectedCurrency';
                              }
                            }(),
                            style: TextStyle(
                              color: t.type == 'payment'
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          if (selectedCurrency != 'USD')
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'USD ${(t.anchorUsdValue ?? t.amount ?? 0.0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // --- MENSAJE DE SINCRONIZACIÓN (ABAJO) ---
                  if (syncMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 1),
                      child: Row(
                        children: [
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: syncMsg.color.withAlpha(
                                (0.09 * 255).toInt(),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  syncMsg.icon,
                                  size: 12,
                                  color: syncMsg.color,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  syncMsg.message,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: syncMsg.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

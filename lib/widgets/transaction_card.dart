import 'package:flutter/material.dart';
import '../models/client.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final t = transaction;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: t.type == 'debt'
                      ? const Color(0xFFFFE5E5)
                      : const Color(0xFFE5FFE8),
                  radius: 16, // reducido de 22
                  child: Icon(
                    t.type == 'debt'
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    color: t.type == 'debt' ? Colors.red : Colors.green,
                    size: 16, // reducido de 24
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              t.description != null &&
                                      t.description is String &&
                                      t.description.isNotEmpty
                                  ? t.description[0].toUpperCase() +
                                        t.description.substring(1)
                                  : '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Siempre mostrar el valor USD fijo
                              Text(
                                'USD ' +
                                    ((t.anchorUsdValue ?? t.amount)
                                            ?.toStringAsFixed(2) ??
                                        '0.00'),
                                style: TextStyle(
                                  color: t.type == 'payment'
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                              // Valor convertido a moneda local (solo si no es USD)
                              if (selectedCurrency != 'USD')
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    () {
                                      final usd = t.anchorUsdValue ?? t.amount;
                                      final rate =
                                          exchangeRates[selectedCurrency] ??
                                          1.0;
                                      final converted = usd * rate;
                                      return '${converted.toStringAsFixed(2)} $selectedCurrency';
                                    }(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Cliente y fecha en columna
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client.name,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.black45,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                      if (clientPendingDelete && isOffline)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 1),
                          child: Row(
                            children: [
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withAlpha(
                                    (0.09 * 255).toInt(),
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.delete_forever,
                                      size: 12,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'Pendiente por eliminar',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (t.synced == false)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 1),
                          child: Row(
                            children: [
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withAlpha(
                                    (0.09 * 255).toInt(),
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.sync,
                                      size: 10,
                                      color: Colors.orange,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'Pendiente por sincronizar',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.orange,
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
            // Centered Sincronizado message at the bottom
            if (t.synced == true)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha((0.09 * 255).toInt()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.cloud_done, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'Sincronizado',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

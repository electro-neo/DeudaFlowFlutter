import 'package:flutter/material.dart';

import '../models/client.dart';

import '../providers/transaction_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/general_receipt_modal.dart';

class GeneralReceiptScreen extends StatelessWidget {
  final List<Client> clients;
  const GeneralReceiptScreen({super.key, required this.clients});

  @override
  Widget build(BuildContext context) {
    final transactions = context.watch<TransactionProvider>().transactions;
    return Scaffold(
      appBar: AppBar(title: const Text('Recibo General')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Asociar transacciones reales a cada cliente
            final clientData = clients
                .map(
                  (c) => {
                    'client': c,
                    'transactions': transactions
                        .where((tx) => tx.clientId == c.id)
                        .toList(),
                  },
                )
                .toList();
            showDialog(
              context: context,
              builder: (_) => GeneralReceiptModal(clientData: clientData),
            );
          },
          child: const Text('Ver Recibo General'),
        ),
      ),
    );
  }
}

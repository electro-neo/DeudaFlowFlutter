import 'package:flutter/material.dart';
import '../models/client.dart';
import '../models/transaction.dart';
import '../widgets/receipt_modal.dart';

class ReceiptScreen extends StatelessWidget {
  final Client client;
  final List<Transaction> transactions;
  const ReceiptScreen({super.key, required this.client, required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Recibo de ${client.name}')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => ReceiptModal(client: client, transactions: transactions),
            );
          },
          child: const Text('Ver Recibo'),
        ),
      ),
    );
  }
}

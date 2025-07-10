import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/client.dart';
import '../models/transaction.dart';

// --- PDF builder para recibo general con movimientos filtrados ---
pw.Document buildGeneralReceiptWithMovementsPDF(
  List<Map<String, dynamic>> filtered,
) {
  final pdf = pw.Document();
  double totalDeuda = 0;
  double totalAbono = 0;
  pdf.addPage(
    pw.MultiPage(
      build: (context) {
        List<pw.Widget> widgets = [
          pw.Text(
            'Recibo General de Clientes',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
        ];
        for (final e in filtered) {
          final client = e['client'] as Client;
          final txs = e['filteredTxs'] as List<dynamic>;
          for (final tx in txs) {
            if (tx.type == 'deuda' || tx.type == 'debt') {
              totalDeuda += (tx.amount as num).toDouble();
            } else if (tx.type == 'abono' || tx.type == 'payment') {
              totalAbono += (tx.amount as num).toDouble();
            }
          }
          widgets.addAll([
            pw.Text(
              '${client.name} (ID: ${client.id})',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Teléfono: ${(client.phone != null &&
                          client.phone.toString().trim().isNotEmpty)
                      ? client.phone.toString()
                      : 'Sin Información'}',
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 4),
            if (txs.isEmpty) pw.Text('Sin movimientos en el rango.'),
            if (txs.isNotEmpty)
              pw.Table.fromTextArray(
                headers: ['Tipo', 'Descripción', 'Fecha', 'Monto'],
                data: txs
                    .map(
                      (tx) => [
                        tx.type == 'deuda' || tx.type == 'debt'
                            ? 'Deuda'
                            : 'Abono',
                        tx.description,
                        tx.date.toLocal().toString().split(' ')[0],
                        (tx.amount as num).toStringAsFixed(2),
                      ],
                    )
                    .toList(),
              ),
            pw.SizedBox(height: 12),
          ]);
        }
        widgets.add(
          pw.Text(
            'Total Deuda: ${totalDeuda.toStringAsFixed(2)}   /   Total Abono: ${totalAbono.toStringAsFixed(2)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        );
        return widgets;
      },
    ),
  );
  return pdf;
}

// --- PDF builder común para recibo general ---
pw.Document buildGeneralReceiptPDF(List<Client> clients) {
  final pdf = pw.Document();
  double totalDeuda = 0;
  double totalAbono = 0;
  pdf.addPage(
    pw.MultiPage(
      build: (context) {
        List<pw.Widget> widgets = [
          pw.Text(
            'Recibo General de Clientes',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
        ];
        for (final client in clients) {
          widgets.addAll([
            pw.Text(
              '${client.name} (ID: ${client.id})',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Teléfono: ${(client.phone != null && client.phone.toString().trim().isNotEmpty) ? client.phone.toString() : 'Sin Información'}',
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 4),
            pw.Table.fromTextArray(
              headers: ['Saldo'],
              data: [
                [client.balance.toStringAsFixed(2)],
              ],
            ),
            pw.SizedBox(height: 12),
          ]);
          if (client.balance < 0) {
            totalDeuda += client.balance.abs();
          } else {
            totalAbono += client.balance;
          }
        }
        widgets.add(
          pw.Text(
            'Total Deuda: ${totalDeuda.toStringAsFixed(2)} / Total Abono: ${totalAbono.toStringAsFixed(2)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        );
        return widgets;
      },
    ),
  );
  return pdf;
}

Future<void> exportAndShareClientReceiptPDF(
  Client client,
  List<Transaction> transactions,
) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Recibo de ${client.name}',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('ID: ${client.id}'),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: ['Tipo', 'Monto', 'Descripción', 'Fecha'],
            data: transactions
                .map(
                  (tx) => [
                    tx.type == 'debt' ? 'Deuda' : 'Abono',
                    tx.amount.toStringAsFixed(2),
                    tx.description,
                    tx.date.toLocal().toString().split(' ')[0],
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Saldo actual: ${client.balance.toStringAsFixed(2)}'),
        ],
      ),
    ),
  );
  final bytes = await pdf.save();
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/recibo_cliente_${client.id}.pdf');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)], text: 'Recibo de ${client.name}');
}

Future<void> exportGeneralReceiptWithMovementsPDF(
  List<Map<String, dynamic>> filtered,
) async {
  final pdf = buildGeneralReceiptWithMovementsPDF(filtered);
  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}

Future<void> exportAndShareGeneralReceiptWithMovementsPDF(
  List<Map<String, dynamic>> filtered,
) async {
  final pdf = buildGeneralReceiptWithMovementsPDF(filtered);
  final bytes = await pdf.save();
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/recibo_general.pdf');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([
    XFile(file.path),
  ], text: 'Recibo General de Clientes');
}

Future<void> exportClientReceiptToPDF(
  Client client,
  List<Transaction> transactions,
) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Recibo de ${client.name}',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('ID: ${client.id}'),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: ['Tipo', 'Monto', 'Descripción', 'Fecha'],
            data: transactions
                .map(
                  (tx) => [
                    tx.type == 'debt' ? 'Deuda' : 'Abono',
                    tx.amount.toStringAsFixed(2),
                    tx.description,
                    tx.date.toLocal().toString().split(' ')[0],
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Saldo actual: ${client.balance.toStringAsFixed(2)}'),
        ],
      ),
    ),
  );
  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}

Future<void> exportGeneralReceiptToPDF(List<Client> clients) async {
  final pdf = buildGeneralReceiptPDF(clients);
  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}

Future<void> exportAndShareGeneralReceiptPDF(List<Client> clients) async {
  final pdf = buildGeneralReceiptPDF(clients);
  final bytes = await pdf.save();
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/recibo_general.pdf');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([
    XFile(file.path),
  ], text: 'Recibo General de Clientes');
}

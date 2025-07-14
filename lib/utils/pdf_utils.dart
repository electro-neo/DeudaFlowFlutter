import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/client.dart';
import '../models/transaction.dart';

// --- Utilidad para conversión y formateo de moneda en PDF ---
double convertAmount(num value, bool convert, double? rate) {
  if (convert && rate != null && rate > 0) {
    return value.toDouble() / rate;
  }
  return value.toDouble();
}

String formatAmount(
  num value,
  bool convert,
  double? rate, {
  String symbol = '',
  int decimals = 2,
}) {
  final converted = convertAmount(value, convert, rate);
  final parts = converted.toStringAsFixed(decimals).split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.',
  );
  final decPart = parts.length > 1 ? ',${parts[1]}' : '';
  // Usar el símbolo proporcionado (puede estar vacío para moneda local)
  final safeSymbol = symbol;
  return '$safeSymbol$intPart$decPart';
}

// --- PDF builder para recibo general con movimientos filtrados ---
pw.Document buildGeneralReceiptWithMovementsPDF(
  List<Map<String, dynamic>> filtered, {
  bool convertCurrency = false,
  double? conversionRate,
  String currencySymbol = '',
}) {
  final pdf = pw.Document();
  double totalDeudaGeneral = 0;
  double totalAbonoGeneral = 0;
  pdf.addPage(
    pw.MultiPage(
      build: (context) {
        List<pw.Widget> widgets = [
          pw.Text(
            filtered.length == 1
                ? 'Recibo general de ${(filtered[0]['client'] as Client).name}'
                : 'Recibo General de Clientes',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          if (convertCurrency && conversionRate != null && conversionRate > 0)
            pw.Text(
              'Nota: Todos los montos han sido convertidos a la tasa $conversionRate.',
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
            ),
          pw.SizedBox(height: 10),
        ];
        for (final e in filtered) {
          final client = e['client'] as Client;
          final txs = e['filteredTxs'] as List<dynamic>;
          double totalDeuda = 0;
          double totalAbono = 0;
          for (final tx in txs) {
            if (tx.type == 'deuda' || tx.type == 'debt') {
              totalDeuda += convertAmount(
                tx.amount as num,
                convertCurrency,
                conversionRate,
              );
              totalDeudaGeneral += convertAmount(
                tx.amount as num,
                convertCurrency,
                conversionRate,
              );
            } else if (tx.type == 'abono' || tx.type == 'payment') {
              totalAbono += convertAmount(
                tx.amount as num,
                convertCurrency,
                conversionRate,
              );
              totalAbonoGeneral += convertAmount(
                tx.amount as num,
                convertCurrency,
                conversionRate,
              );
            }
          }
          if (filtered.length == 1) {
            widgets.addAll([
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Nombre Cliente: ',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.TextSpan(text: client.name),
                  ],
                ),
              ),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Teléfono: ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.TextSpan(
                      text:
                          (client.phone != null &&
                              client.phone.toString().trim().isNotEmpty)
                          ? client.phone.toString()
                          : 'Sin Información',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Correo: ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.TextSpan(
                      text:
                          (client.email != null &&
                              client.email.toString().trim().isNotEmpty)
                          ? client.email.toString()
                          : 'Sin Información',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'ID Cliente: ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.TextSpan(
                      text: client.id,
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              if (txs.isEmpty) pw.Text('Sin movimientos en el rango.'),
              if (txs.isNotEmpty)
                pw.TableHelper.fromTextArray(
                  headers: ['Tipo', 'Descripción', 'Fecha', 'Monto'],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  data: txs
                      .map(
                        (tx) => [
                          tx.type == 'deuda' || tx.type == 'debt'
                              ? 'Deuda'
                              : 'Abono',
                          tx.description,
                          tx.date.toLocal().toString().split(' ')[0],
                          formatAmount(
                            tx.amount as num,
                            convertCurrency,
                            conversionRate,
                            symbol: currencySymbol,
                          ),
                        ],
                      )
                      .toList(),
                ),
              if (txs.isNotEmpty)
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Total Deuda: ${formatAmount(totalDeuda, false, null, symbol: currencySymbol)}   /   Total Abono: ${formatAmount(totalAbono, false, null, symbol: currencySymbol)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              pw.SizedBox(height: 12),
            ]);
          } else {
            widgets.addAll([
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Nombre Cliente: ',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.TextSpan(text: client.name),
                  ],
                ),
              ),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Teléfono: ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.TextSpan(
                      text:
                          (client.phone != null &&
                              client.phone.toString().trim().isNotEmpty)
                          ? client.phone.toString()
                          : 'Sin Información',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Correo: ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.TextSpan(
                      text:
                          (client.email != null &&
                              client.email.toString().trim().isNotEmpty)
                          ? client.email.toString()
                          : 'Sin Información',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'ID Cliente: ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.TextSpan(
                      text: client.id,
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              if (txs.isEmpty) pw.Text('Sin movimientos en el rango.'),
              if (txs.isNotEmpty)
                pw.TableHelper.fromTextArray(
                  headers: ['Tipo', 'Descripción', 'Fecha', 'Monto'],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  data: txs
                      .map(
                        (tx) => [
                          tx.type == 'deuda' || tx.type == 'debt'
                              ? 'Deuda'
                              : 'Abono',
                          tx.description,
                          tx.date.toLocal().toString().split(' ')[0],
                          formatAmount(
                            tx.amount as num,
                            convertCurrency,
                            conversionRate,
                            symbol: currencySymbol,
                          ),
                        ],
                      )
                      .toList(),
                ),
              if (txs.isNotEmpty)
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Total Deuda: ${formatAmount(totalDeuda, false, null, symbol: currencySymbol)}   /   Total Abono: ${formatAmount(totalAbono, false, null, symbol: currencySymbol)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              pw.SizedBox(height: 12),
            ]);
          }
        }
        if (filtered.length > 1) {
          widgets.add(
            pw.Text(
              'Total deuda general: ${formatAmount(totalDeudaGeneral, false, null, symbol: currencySymbol)}   /   Total abono general: ${formatAmount(totalAbonoGeneral, false, null, symbol: currencySymbol)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
          );
        }
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
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
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
          pw.TableHelper.fromTextArray(
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
  List<Map<String, dynamic>> filtered, {
  bool convertCurrency = false,
  double? conversionRate,
  String currencySymbol = '',
}) async {
  final pdf = buildGeneralReceiptWithMovementsPDF(
    filtered,
    convertCurrency: convertCurrency,
    conversionRate: conversionRate,
    currencySymbol: currencySymbol,
  );
  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}

Future<void> exportAndShareGeneralReceiptWithMovementsPDF(
  List<Map<String, dynamic>> filtered, {
  bool convertCurrency = false,
  double? conversionRate,
  String currencySymbol = '',
}) async {
  final pdf = buildGeneralReceiptWithMovementsPDF(
    filtered,
    convertCurrency: convertCurrency,
    conversionRate: conversionRate,
    currencySymbol: currencySymbol,
  );
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
          pw.TableHelper.fromTextArray(
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

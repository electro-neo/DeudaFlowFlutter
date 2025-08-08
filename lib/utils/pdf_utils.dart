import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/client.dart';
import '../models/transaction.dart';
import 'package:pdf/pdf.dart';

// --- Constantes de la aplicación para el PDF ---
const String appName = 'DeudaFlow';
const String appVersion = '1.0.0'; // Puedes cambiar esto por la versión real

// --- Utilidad para formateo de moneda en PDF ---
// Se simplifica para solo formatear. La conversión se hace antes de llamar.
String formatAmount(num value, {String symbol = '', int decimals = 2}) {
  final parts = value.toStringAsFixed(decimals).split('.');
  // FIX: Formato con punto para miles y coma para decimales (estándar LATAM/España)
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.', // Cambiado a punto
  );
  final decPart = parts.length > 1 ? ',${parts[1]}' : ''; // Cambiado a coma
  final safeSymbol = symbol.isNotEmpty ? '$symbol ' : '';
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
  // Totales generales siempre en USD
  double totalDeudaGeneralUSD = 0;
  double totalAbonoGeneralUSD = 0;

  final now = DateTime.now();
  final fechaRecibo =
      'Fecha del recibo: '
      '${now.day.toString().padLeft(2, '0')}/'
      '${now.month.toString().padLeft(2, '0')}/'
      '${now.year} '
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}';

  pdf.addPage(
    pw.MultiPage(
      header: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            filtered.length == 1
                ? 'Recibo de ${(filtered[0]['client'] as Client).name}'
                : 'Recibo General de Clientes',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            fechaRecibo,
            style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
          ),
        ],
      ),
      build: (context) {
        List<pw.Widget> widgets = [
          if (convertCurrency && conversionRate != null && conversionRate > 0)
            pw.Text(
              'Nota: Los montos en $currencySymbol son calculados a una tasa de $conversionRate.',
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
            ),
          pw.SizedBox(height: 10),
        ];

        for (final e in filtered) {
          final client = e['client'] as Client;
          final txs = e['filteredTxs'] as List<dynamic>;
          // Totales por cliente en USD
          double totalDeudaUSD = 0;
          double totalAbonoUSD = 0;

          for (final tx in txs) {
            final usdValue = (tx.anchorUsdValue ?? tx.amount) as num;
            if (tx.type == 'deuda' || tx.type == 'debt') {
              totalDeudaUSD += usdValue;
            } else if (tx.type == 'abono' || tx.type == 'payment') {
              totalAbonoUSD += usdValue;
            }
          }

          totalDeudaGeneralUSD += totalDeudaUSD;
          totalAbonoGeneralUSD += totalAbonoUSD;

          // --- BLOQUE DE INFORMACIÓN DEL CLIENTE ---
          widgets.add(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
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
                            (client.address != null &&
                                client.address.toString().trim().isNotEmpty)
                            ? client.address.toString()
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
              ],
            ),
          );
          if (txs.isEmpty) {
            widgets.add(pw.Text('Sin movimientos en el rango de fechas.'));
          }
          if (txs.isNotEmpty) {
            // --- TABLA DE TRANSACCIONES ---
            final headers = ['Fecha', 'Descripción', 'Tipo', 'Monto USD'];
            if (convertCurrency) {
              headers.add('Monto $currencySymbol');
            }

            widgets.add(
              pw.Table.fromTextArray(
                headers: headers,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(color: PdfColors.blue),
                cellStyle: pw.TextStyle(fontSize: 10),
                data: txs.map((tx) {
                  final usdValue = (tx.anchorUsdValue ?? tx.amount) as num;
                  final row = [
                    tx.date.toLocal().toString().split(' ')[0],
                    tx.description,
                    tx.type == 'deuda' || tx.type == 'debt' ? 'Deuda' : 'Abono',
                    formatAmount(usdValue, symbol: 'USD'),
                  ];
                  if (convertCurrency) {
                    row.add(
                      formatAmount(
                        usdValue * conversionRate!,
                        symbol: currencySymbol,
                      ),
                    );
                  }
                  return row;
                }).toList(),
              ),
            );

            // --- TOTALES POR CLIENTE ---
            widgets.add(pw.SizedBox(height: 8));
            widgets.add(
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // --- Columna Total Deuda ---
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Total Deuda:',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          formatAmount(totalDeudaUSD, symbol: 'USD'),
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                        if (convertCurrency) ...[
                          pw.SizedBox(height: 1),
                          pw.Text(
                            formatAmount(
                              totalDeudaUSD * conversionRate!,
                              symbol: currencySymbol,
                            ),
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                    pw.SizedBox(width: 24), // Espacio entre columnas
                    // --- Columna Total Abono ---
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Total Abono:',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          formatAmount(totalAbonoUSD, symbol: 'USD'),
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                        if (convertCurrency) ...[
                          pw.SizedBox(height: 1),
                          pw.Text(
                            formatAmount(
                              totalAbonoUSD * conversionRate!,
                              symbol: currencySymbol,
                            ),
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
          widgets.add(pw.SizedBox(height: 12));
        }

        // --- TOTALES GENERALES ---
        if (filtered.length > 1) {
          widgets.add(pw.Divider());
          widgets.add(pw.SizedBox(height: 8));
          widgets.add(
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // --- Columna Total Deuda General ---
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Total deuda general:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        formatAmount(totalDeudaGeneralUSD, symbol: 'USD'),
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      if (convertCurrency) ...[
                        pw.SizedBox(height: 1),
                        pw.Text(
                          formatAmount(
                            totalDeudaGeneralUSD * conversionRate!,
                            symbol: currencySymbol,
                          ),
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  pw.SizedBox(width: 24), // Espacio entre columnas
                  // --- Columna Total Abono General ---
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Total abono general:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        formatAmount(totalAbonoGeneralUSD, symbol: 'USD'),
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      if (convertCurrency) ...[
                        pw.SizedBox(height: 1),
                        pw.Text(
                          formatAmount(
                            totalAbonoGeneralUSD * conversionRate!,
                            symbol: currencySymbol,
                          ),
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        }
        return widgets;
      },
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'Comienza a gestionar tus deudas y clientes aquí con ',
              style: pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(width: 2),
            pw.Text(
              '$appName v$appVersion',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(width: 6),
            pw.Text('puedes descargarla en ', style: pw.TextStyle(fontSize: 9)),
            pw.SizedBox(width: 2),
            pw.Text(
              'Play Store',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
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
          pw.Table.fromTextArray(
            headers: ['Fecha', 'Descripción', 'Tipo', 'Monto'],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: PdfColors.blue),
            cellStyle: pw.TextStyle(fontSize: 10),
            data: transactions
                .map(
                  (tx) => [
                    tx.date.toLocal().toString().split(' ')[0],
                    tx.description,
                    tx.type == 'debt' ? 'Deuda' : 'Abono',
                    tx.amount.toStringAsFixed(2),
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
  // Sanitizar el nombre del cliente para el archivo
  final safeName = client.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final file = File('${dir.path}/Recibo de Cliente ($safeName).pdf');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: 'Recibo de ${client.name}'),
  );
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
  String fileName;
  String shareText;
  if (filtered.length == 1) {
    final client = filtered[0]['client'] as Client;
    final safeName = client.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    fileName = 'Recibo de Cliente $safeName.pdf';
    shareText = 'Recibo de ${client.name}';
  } else {
    fileName = 'Recibo General de Clientes.pdf';
    shareText = 'Recibo General de Clientes';
  }
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: shareText),
  );
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

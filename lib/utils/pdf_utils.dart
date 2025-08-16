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

String getCurrencyLabel(String symbol) {
  if (symbol == 'COP') return 'COP(Pesos)';
  if (symbol == 'VES') return 'VES(Bs)';
  return symbol;
}

// --- PDF builder para recibo general con movimientos filtrados ---
pw.Document buildGeneralReceiptWithMovementsPDF(
  List<Map<String, dynamic>> filtered, {
  required List<Map<String, dynamic>>
  selectedCurrencies, // [{symbol: 'USD', rate: 1.0}, ...]
}) {
  final pdf = pw.Document();
  // Totales generales por moneda seleccionada
  final Map<String, double> totalDeudaGeneral = {
    for (var c in selectedCurrencies) c['symbol']: 0.0,
  };
  final Map<String, double> totalAbonoGeneral = {
    for (var c in selectedCurrencies) c['symbol']: 0.0,
  };

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
        List<pw.Widget> widgets = [];
        // Mostrar nota de tasa de conversión para cada moneda seleccionada distinta de USD
        for (final currency in selectedCurrencies) {
          if (currency['symbol'] != 'USD') {
            widgets.add(
              pw.Text(
                'Nota: Los montos en ${getCurrencyLabel(currency['symbol'])} son calculados a una tasa de ${currency['rate']}.',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            );
          }
        }
        widgets.add(pw.SizedBox(height: 10));

        for (final e in filtered) {
          final client = e['client'] as Client;
          final txs = e['filteredTxs'] as List<dynamic>;
          // Totales por cliente en cada moneda
          Map<String, double> totalDeuda = {};
          Map<String, double> totalAbono = {};
          for (final currency in selectedCurrencies) {
            totalDeuda[currency['symbol']] = 0;
            totalAbono[currency['symbol']] = 0;
          }
          for (final tx in txs) {
            for (final currency in selectedCurrencies) {
              final symbol = currency['symbol'];
              final rate = currency['rate'] as num;
              final usdValue = (tx.anchorUsdValue ?? tx.amount) as num;
              final value = usdValue * rate;
              if (tx.type == 'deuda' || tx.type == 'debt') {
                totalDeuda[symbol] = (totalDeuda[symbol] ?? 0) + value;
              } else if (tx.type == 'abono' || tx.type == 'payment') {
                totalAbono[symbol] = (totalAbono[symbol] ?? 0) + value;
              }
            }
          }
          // Sumar totales generales para cada moneda seleccionada
          for (final currency in selectedCurrencies) {
            final symbol = currency['symbol'];
            totalDeudaGeneral[symbol] =
                (totalDeudaGeneral[symbol] ?? 0) + (totalDeuda[symbol] ?? 0);
            totalAbonoGeneral[symbol] =
                (totalAbonoGeneral[symbol] ?? 0) + (totalAbono[symbol] ?? 0);
          }
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
                        text: 'Dirección: ',
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
            // Orden descendente por fecha (más recientes primero)
            final sortedTxs = List<dynamic>.from(txs)
              ..sort((a, b) {
                final DateTime da = a.date is DateTime
                    ? a.date as DateTime
                    : DateTime.tryParse(a.date.toString()) ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                final DateTime db = b.date is DateTime
                    ? b.date as DateTime
                    : DateTime.tryParse(b.date.toString()) ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                return db.compareTo(da);
              });
            // --- TABLA DE TRANSACCIONES ---
            final headers = ['Fecha', 'Descripción', 'Tipo'];
            for (final currency in selectedCurrencies) {
              headers.add('Monto ${getCurrencyLabel(currency['symbol'])}');
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
                cellAlignments: {
                  for (int i = 3; i < 3 + selectedCurrencies.length; i++)
                    i: pw.Alignment.centerRight,
                },
                data: sortedTxs.map((tx) {
                  final row = [
                    (tx.date is DateTime
                            ? (tx.date as DateTime)
                            : DateTime.tryParse(tx.date.toString()) ??
                                  DateTime.now())
                        .toLocal()
                        .toString()
                        .split(' ')
                        .first,
                    tx.description,
                    tx.type == 'deuda' || tx.type == 'debt' ? 'Deuda' : 'Abono',
                  ];
                  for (final currency in selectedCurrencies) {
                    final usdValue = (tx.anchorUsdValue ?? tx.amount) as num;
                    final rate = currency['rate'] as num;
                    row.add(
                      formatAmount(usdValue * rate, symbol: currency['symbol']),
                    );
                  }
                  return row;
                }).toList(),
              ),
            );
            // --- TOTALES POR CLIENTE ---
            widgets.add(pw.SizedBox(height: 8));
            final Map<String, double> saldoPendiente = {};
            for (final currency in selectedCurrencies) {
              final symbol = currency['symbol'];
              saldoPendiente[symbol] =
                  (totalDeuda[symbol] ?? 0) - (totalAbono[symbol] ?? 0);
            }
            // Estructura: dos columnas, una para deuda pendiente y otra para total abonado, cada una con la lista de monedas debajo
            widgets.add(
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Columna izquierda: Total Abonado
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Total Abonado:',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          for (final currency in selectedCurrencies)
                            pw.Text(
                              '${getCurrencyLabel(currency['symbol'])} '
                              '${formatAmount(totalAbono[currency['symbol']] ?? 0, symbol: "")}',
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 32),
                    // Columna derecha: Deuda Pendiente (resaltada)
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.only(bottom: 2),
                            decoration: pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(
                                  color: PdfColors.blue,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: pw.Text(
                              // Si todas las monedas tienen saldo 0, mostrar "Sin deuda"
                              saldoPendiente.values.every((v) => v == 0)
                                  ? 'Sin deuda:'
                                  : saldoPendiente.values.every((v) => v < 0)
                                  ? 'Saldo a favor del cliente:'
                                  : 'Deuda Pendiente:',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 14,
                                color: PdfColors.blue,
                              ),
                            ),
                          ),
                          for (final currency in selectedCurrencies)
                            pw.Text(
                              '${getCurrencyLabel(currency['symbol'])} '
                              '${formatAmount(saldoPendiente[currency['symbol']]!.abs(), symbol: "")}',
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
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
                  // --- Columna Total Abono General (izquierda) ---
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
                      for (final currency in selectedCurrencies)
                        pw.Text(
                          formatAmount(
                            totalAbonoGeneral[currency['symbol']] ?? 0,
                            symbol: getCurrencyLabel(currency['symbol']),
                          ),
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  pw.SizedBox(width: 24), // Espacio entre columnas
                  // --- Columna Total Deuda General (derecha) ---
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
                      for (final currency in selectedCurrencies)
                        pw.Text(
                          formatAmount(
                            totalDeudaGeneral[currency['symbol']] ?? 0,
                            symbol: getCurrencyLabel(currency['symbol']),
                          ),
                          style: const pw.TextStyle(fontSize: 12),
                        ),
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
      build: (context) {
        // Orden descendente por fecha
        final sorted = List<Transaction>.from(transactions)
          ..sort((a, b) => b.date.compareTo(a.date));
        return pw.Column(
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
              data: sorted
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
        );
      },
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
  required List<Map<String, dynamic>> selectedCurrencies,
}) async {
  final pdf = buildGeneralReceiptWithMovementsPDF(
    filtered,
    selectedCurrencies: selectedCurrencies,
  );
  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}

Future<void> exportAndShareGeneralReceiptWithMovementsPDF(
  List<Map<String, dynamic>> filtered, {
  required List<Map<String, dynamic>> selectedCurrencies,
}) async {
  final pdf = buildGeneralReceiptWithMovementsPDF(
    filtered,
    selectedCurrencies: selectedCurrencies,
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
  List<Transaction> transactions, {
  required List<Map<String, dynamic>> selectedCurrencies,
}) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      build: (context) {
        // Orden descendente por fecha
        final sorted = List<Transaction>.from(transactions)
          ..sort((a, b) => b.date.compareTo(a.date));
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Recibo de ${client.name}',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('ID: ${client.id}'),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: [
                'Fecha',
                'Descripción',
                'Tipo',
                ...selectedCurrencies.map(
                  (c) => 'Monto ${getCurrencyLabel(c['symbol'])}',
                ),
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColors.blue),
              cellStyle: pw.TextStyle(fontSize: 10),
              cellAlignments: {
                for (int i = 3; i < 3 + selectedCurrencies.length; i++)
                  i: pw.Alignment.centerRight,
              },
              data: sorted
                  .map(
                    (tx) => [
                      tx.date.toLocal().toString().split(' ')[0],
                      tx.description,
                      tx.type == 'debt' ? 'Deuda' : 'Abono',
                      ...selectedCurrencies.map(
                        (c) => formatAmount(
                          (tx.anchorUsdValue ?? tx.amount) * (c['rate'] as num),
                          symbol: c['symbol'],
                        ),
                      ),
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 10),
            // Mostrar saldo actual en cada moneda seleccionada
            ...selectedCurrencies.map((c) {
              final symbol = c['symbol'];
              final rate = c['rate'] as num;
              return pw.Text(
                'Saldo actual (${getCurrencyLabel(symbol)}): ${formatAmount(client.balance * rate, symbol: symbol)}',
              );
            }),
          ],
        );
      },
    ),
  );
  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}

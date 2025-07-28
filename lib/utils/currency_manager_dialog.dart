import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';

class CurrencyManagerDialog extends StatefulWidget {
  const CurrencyManagerDialog({super.key});

  @override
  State<CurrencyManagerDialog> createState() => _CurrencyManagerDialogState();
}

class _CurrencyManagerDialogState extends State<CurrencyManagerDialog> {
  late List<String> currencies;
  late Map<String, TextEditingController> rates;
  // Usar el listado de monedas permitidas desde CurrencyProvider
  List<String> get allPossibleCurrencies => CurrencyProvider.allowedCurrencies;
  String? selectedCurrency;
  final TextEditingController newRateController = TextEditingController();
  String? addError;
  bool showAddFields = false;
  late ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    final currencyProvider = context.read<CurrencyProvider>();
    currencies = currencyProvider.availableCurrencies
        .where((c) => c != 'USD')
        .toList();
    rates = {
      for (final c in currencies)
        c: TextEditingController(
          text: currencyProvider.exchangeRates[c]?.toString() ?? '',
        ),
    };
  }

  @override
  void dispose() {
    for (final ctrl in rates.values) {
      ctrl.dispose();
    }
    newRateController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = context.watch<CurrencyProvider>();
    currencies = currencyProvider.availableCurrencies
        .where((c) => c != 'USD')
        .toList();
    // Usar los controladores solo para edición temporal, pero mostrar el valor real desde currencyProvider.exchangeRates
    rates = {
      for (final c in currencies)
        c: TextEditingController(
          text: currencyProvider.exchangeRates[c]?.toString() ?? '',
        ),
    };
    final alreadyRegistered = {...currencies, 'USD'};
    final availableToAdd =
        allPossibleCurrencies
            .where((code) => !alreadyRegistered.contains(code))
            .toList()
          ..sort();

    void showCurrencyPickerDialog() async {
      String? picked;
      await showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Selecciona una moneda'),
            content: SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: null,
                items: availableToAdd
                    .map(
                      (code) =>
                          DropdownMenuItem(value: code, child: Text(code)),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    Navigator.of(ctx).pop();
                    setState(() {
                      selectedCurrency = val;
                      showAddFields = true;
                      addError = null;
                    });
                  }
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                menuMaxHeight:
                    240, // 5-6 items aprox, pero permite scroll en todo el listado
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text('Cancelar'),
              ),
              // Eliminado el botón Seleccionar
            ],
          );
        },
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.attach_money_rounded, color: Colors.indigo),
          SizedBox(width: 8),
          Text(
            'Gestión de monedas',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Puedes registrar cualquier cantidad de monedas adicionales a USD (sin repetir). Aquí puedes fijar la tasa, cambiarla manualmente o eliminar monedas para agregar nuevas.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 340,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: Scrollbar(
                  thumbVisibility: true,
                  controller: scrollController,
                  child: ListView(
                    controller: scrollController,
                    shrinkWrap: true,
                    children: [
                      ...currencies.map(
                        (c) => Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        flex: 2,
                                        child: TextField(
                                          controller: rates[c],
                                          decoration: InputDecoration(
                                            labelText: 'Tasa $c a USD',
                                            border: const OutlineInputBorder(),
                                            filled: true,
                                            fillColor: Colors.white,
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 8,
                                                ),
                                            labelStyle: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                          style: const TextStyle(fontSize: 15),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          onTap: () {
                                            // Al enfocar, actualizar el controlador con el valor real
                                            final real =
                                                currencyProvider
                                                    .exchangeRates[c]
                                                    ?.toString() ??
                                                '';
                                            if (rates[c]!.text != real) {
                                              rates[c]!.text = real;
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.indigo,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(36, 36),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 0,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed: () {
                                          final val = double.tryParse(
                                            rates[c]!.text.replaceAll(',', '.'),
                                          );
                                          if (val != null) {
                                            currencyProvider.setRateForCurrency(
                                              c,
                                              val,
                                            );
                                            setState(() {});
                                          }
                                        },
                                        child: const Icon(Icons.save, size: 18),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        tooltip: 'Eliminar moneda',
                                        onPressed: () {
                                          currencyProvider.removeManualCurrency(
                                            c,
                                          );
                                          setState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (showAddFields && selectedCurrency != null)
                        Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        flex: 2,
                                        child: TextField(
                                          controller: newRateController,
                                          decoration: InputDecoration(
                                            labelText:
                                                'Tasa $selectedCurrency a USD',
                                            border: const OutlineInputBorder(),
                                            filled: true,
                                            fillColor: Colors.white,
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 8,
                                                ),
                                            labelStyle: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                          style: const TextStyle(fontSize: 15),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.indigo,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(36, 36),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 0,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed: () {
                                          final code = selectedCurrency;
                                          final rateText = newRateController
                                              .text
                                              .replaceAll(',', '.');
                                          final rate = double.tryParse(
                                            rateText,
                                          );
                                          if (code == null || code.isEmpty) {
                                            setState(
                                              () => addError =
                                                  'Selecciona una moneda',
                                            );
                                            return;
                                          }
                                          if (rate == null || rate <= 0) {
                                            setState(
                                              () => addError = 'Tasa inválida',
                                            );
                                            return;
                                          }
                                          currencyProvider.addManualCurrency(
                                            code,
                                          );
                                          currencyProvider.setRateForCurrency(
                                            code,
                                            rate,
                                          );
                                          setState(() {
                                            showAddFields = false;
                                            selectedCurrency = null;
                                            newRateController.clear();
                                            addError = null;
                                          });
                                        },
                                        child: const Icon(Icons.save, size: 18),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        tooltip: 'Eliminar moneda',
                                        onPressed: () {
                                          setState(() {
                                            selectedCurrency = null;
                                            newRateController.clear();
                                            addError = null;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (addError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 2),
                          child: Text(
                            addError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
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
      actions: [
        TextButton(
          onPressed: showCurrencyPickerDialog,
          child: const Text('Agregar Moneda'),
        ),
        // Eliminar el botón Cancelar del widget principal
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

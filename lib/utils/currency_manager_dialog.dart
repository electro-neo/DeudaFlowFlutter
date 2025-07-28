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
    // Solo actualizar la lista de monedas, pero no los controladores
    final newCurrencies = currencyProvider.availableCurrencies
        .where((c) => c != 'USD')
        .toList();
    // Agregar controladores para nuevas monedas
    for (final c in newCurrencies) {
      if (!rates.containsKey(c)) {
        rates[c] = TextEditingController(
          text: currencyProvider.exchangeRates[c]?.toString() ?? '',
        );
      }
    }
    // Eliminar controladores de monedas que ya no están
    for (final c in rates.keys.toList()) {
      if (!newCurrencies.contains(c)) {
        rates[c]?.dispose();
        rates.remove(c);
      }
    }
    currencies = newCurrencies;
    final alreadyRegistered = {...currencies, 'USD'};
    final availableToAdd = allPossibleCurrencies
        .where((code) => !alreadyRegistered.contains(code))
        .toList();

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
            content: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: SizedBox(
                width: 160,
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
                      horizontal: 6,
                      vertical: 6,
                    ),
                  ),
                  menuMaxHeight: 200, // Más compacto
                ),
              ),
            ),
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
      content: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight * 0.7;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SizedBox(
              width: 340,
              child: Scrollbar(
                thumbVisibility: true,
                controller: scrollController,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxHeight,
                  ),
                  child: ListView(
                    controller: scrollController,
                    shrinkWrap: true,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(
                          top: 8,
                          left: 2,
                          right: 2,
                          bottom: 4,
                        ),
                        child: Text(
                          'Puedes registrar cualquier cantidad de monedas adicionales (sin repetir). Aquí puedes fijar la tasa, cambiarla manualmente o eliminar monedas para agregar nuevas.',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ),
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
                                    crossAxisAlignment: CrossAxisAlignment.center,
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
                                            labelStyle: const TextStyle(fontSize: 13),
                                          ),
                                          style: const TextStyle(fontSize: 15),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        tooltip: 'Eliminar moneda',
                                        onPressed: () {
                                          currencyProvider.removeManualCurrency(c);
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
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        flex: 2,
                                        child: TextField(
                                          controller: newRateController,
                                          decoration: InputDecoration(
                                            labelText: 'Tasa $selectedCurrency a USD',
                                            border: const OutlineInputBorder(),
                                            filled: true,
                                            fillColor: Colors.white,
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 8,
                                                ),
                                            labelStyle: const TextStyle(fontSize: 13),
                                          ),
                                          style: const TextStyle(fontSize: 15),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          onChanged: (text) {
                                            final code = selectedCurrency;
                                            final rate = double.tryParse(
                                              text.replaceAll(',', '.'),
                                            );
                                            if (code == null || code.isEmpty) {
                                              setState(() => addError = 'Selecciona una moneda');
                                              return;
                                            }
                                            if (rate == null || rate <= 0) {
                                              setState(() => addError = 'Tasa inválida');
                                              return;
                                            }
                                            currencyProvider.addManualCurrency(code);
                                            currencyProvider.setRateForCurrency(code, rate);
                                            setState(() {
                                              showAddFields = false;
                                              selectedCurrency = null;
                                              newRateController.clear();
                                              addError = null;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
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
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: showCurrencyPickerDialog,
          child: const Text('Agregar Moneda'),
        ),
        TextButton(
          onPressed: () {
            // Guardar todas las tasas al cerrar
            for (final c in currencies) {
              final text = rates[c]?.text.trim() ?? '';
              final val = double.tryParse(text.replaceAll(',', '.'));
              if (val != null && val > 0) {
                currencyProvider.setRateForCurrency(c, val);
              }
            }
            Navigator.of(context).pop();
          },
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

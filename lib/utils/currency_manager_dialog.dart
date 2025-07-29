import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/scale_on_tap.dart';

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
    currencies = List<String>.from(
      currencyProvider.availableCurrencies.where((c) => c != 'USD'),
    );
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
    // Si se está agregando una nueva moneda, NO mostrarla en currencies (solo en la card especial)
    if (showAddFields && selectedCurrency != null) {
      currencies = currencies.where((c) => c != selectedCurrency).toList();
      // Asegurar que haya un solo controlador para la nueva moneda
      if (!rates.containsKey(selectedCurrency)) {
        rates[selectedCurrency!] = TextEditingController();
      }
    }

    // Eliminar la card visual temporal si el usuario cancela el agregado
    if (!showAddFields &&
        selectedCurrency != null &&
        currencies.contains(selectedCurrency) &&
        !currencyProvider.availableCurrencies.contains(selectedCurrency)) {
      currencies = currencies.where((c) => c != selectedCurrency).toList();
      if (rates.containsKey(selectedCurrency)) {
        rates[selectedCurrency!]?.dispose();
        rates.remove(selectedCurrency);
      }
    }
    // Para el dropdown, solo mostrar monedas realmente registradas y no la temporal
    final alreadyRegistered = {
      ...currencyProvider.availableCurrencies.where((c) => c != 'USD'),
      'USD',
    };
    final availableToAdd = allPossibleCurrencies
        .where((code) => !alreadyRegistered.contains(code))
        .toList();

    void showCurrencyPickerDialog() async {
      // String? picked; // Removed unused local variable 'picked'.
      await showDialog(
        context: context,
        builder: (ctx) {
          final theme = Theme.of(context);
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
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color:
                            Theme.of(context)
                                .inputDecorationTheme
                                .enabledBorder
                                ?.borderSide
                                .color ??
                            theme.colorScheme.primary,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color:
                            Theme.of(context)
                                .inputDecorationTheme
                                .enabledBorder
                                ?.borderSide
                                .color ??
                            theme.colorScheme.primary,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color:
                            Theme.of(context)
                                .inputDecorationTheme
                                .focusedBorder
                                ?.borderSide
                                .color ??
                            theme.colorScheme.secondary,
                        width: 2,
                      ),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
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

    // Envolver el AlertDialog en un WillPopScope para interceptar el cierre por tap en la sombra
    void saveAllRates() {
      final currencyProvider = Provider.of<CurrencyProvider>(
        context,
        listen: false,
      );
      // Guardar tasas de las monedas existentes
      for (final c in rates.keys) {
        final text = rates[c]?.text.trim() ?? '';
        final val = double.tryParse(text.replaceAll(',', '.'));
        if (val != null && val > 0) {
          currencyProvider.setRateForCurrency(c, val);
        }
      }
      // Si hay una moneda nueva en proceso de agregar
      if (showAddFields && selectedCurrency != null) {
        final text = newRateController.text.trim();
        final val = double.tryParse(text.replaceAll(',', '.'));
        if (val != null && val > 0) {
          currencyProvider.addManualCurrency(selectedCurrency!);
          currencyProvider.setRateForCurrency(selectedCurrency!, val);
          // Reordenar la lista para que la nueva moneda esté al principio
          final current = currencyProvider.availableCurrencies.toList();
          if (current.contains(selectedCurrency!)) {
            current.remove(selectedCurrency!);
            current.insert(0, selectedCurrency!);
            // Si el provider lo permite, actualiza la lista
            try {
              currencyProvider.availableCurrencies
                ..clear()
                ..addAll(current);
            } catch (_) {
              // Si no es posible, lo manejamos localmente en el widget
            }
          }
        }
      }
      // Actualizar la lista de monedas y controladores
      setState(() {
        currencies = currencyProvider.availableCurrencies
            .where((c) => c != 'USD')
            .toList();
        // Si se acaba de agregar una nueva moneda, mostrarla primero
        if (selectedCurrency != null && currencies.contains(selectedCurrency)) {
          currencies.remove(selectedCurrency);
          currencies.insert(0, selectedCurrency!);
        }
        for (final c in currencies) {
          if (!rates.containsKey(c)) {
            rates[c] = TextEditingController(
              text: currencyProvider.exchangeRates[c]?.toString() ?? '',
            );
          }
        }
        // Limpiar campos de agregar
        showAddFields = false;
        selectedCurrency = null;
        newRateController.clear();
        addError = null;
      });
    }

    return WillPopScope(
      onWillPop: () async {
        // Si el usuario cierra el dialog sin guardar, limpiar la card temporal
        setState(() {
          if (showAddFields &&
              selectedCurrency != null &&
              !currencyProvider.availableCurrencies.contains(
                selectedCurrency,
              )) {
            if (rates.containsKey(selectedCurrency)) {
              rates[selectedCurrency!]?.dispose();
              rates.remove(selectedCurrency);
            }
            showAddFields = false;
            selectedCurrency = null;
            newRateController.clear();
            addError = null;
          }
        });
        saveAllRates();
        return true; // Permitir el cierre
      },
      child: StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                        constraints: BoxConstraints(maxHeight: maxHeight),
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
                                'Puedes registrar cualquier cantidad de monedas. Aquí puedes fijar la tasa, cambiarla manualmente o eliminar monedas para agregar nuevas.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                  border:
                                                      const OutlineInputBorder(),
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
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                ),
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
                                                currencyProvider
                                                    .removeManualCurrency(c);
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                  border:
                                                      const OutlineInputBorder(),
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
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                ),
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
                );
              },
            ),
            actions: [
              // Botón Agregar Moneda
              ScaleOnTap(
                onTap: showCurrencyPickerDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Agregar Moneda',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              // Espacio mínimo
              const SizedBox(width: 8),
              // Botón Cerrar/Guardar
              ScaleOnTap(
                onTap: () {
                  saveAllRates();
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    showAddFields && selectedCurrency != null
                        ? 'Guardar'
                        : 'Cerrar',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: (showAddFields && selectedCurrency != null)
                          ? 13.5
                          : 15,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

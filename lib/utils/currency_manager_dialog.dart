import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/currency_provider.dart';
import '../widgets/scale_on_tap.dart';

class CurrencyManagerDialog extends StatefulWidget {
  const CurrencyManagerDialog({super.key});

  /// Llama a este método para mostrar el modal desde cualquier parte:
  /// await CurrencyManagerDialog.show(context);
  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CurrencyManagerDialog(),
    );
  }

  @override
  State<CurrencyManagerDialog> createState() => _CurrencyManagerDialogState();
}

class _CurrencyManagerDialogState extends State<CurrencyManagerDialog> {
  late List<String> currencies;
  late Map<String, TextEditingController> rates;
  String? selectedCurrency;
  final TextEditingController newCurrencyController = TextEditingController();
  final TextEditingController newRateController = TextEditingController();
  String? addError;
  bool showAddFields = false;
  late ScrollController scrollController;
  bool _hasChanges = false;
  final Set<String> _pendingDeletions = {};

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

  final List<TextInputFormatter> _rateInputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
  ];

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
    // Si se está agregando una nueva moneda, mostrarla de primera en currencies (lista para escribir la tasa)
    if (showAddFields &&
        selectedCurrency != null &&
        !currencies.contains(selectedCurrency)) {
      currencies = currencies.where((c) => c != selectedCurrency).toList();
      currencies.insert(0, selectedCurrency!);
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
    void showCurrencyPickerDialog() async {
      await showDialog(
        context: context,
        builder: (ctx) {
          final theme = Theme.of(context);
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Agregar moneda'),
            content: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newCurrencyController,
                    decoration: InputDecoration(
                      labelText: 'Código (ej: Eur)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 11,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      String code = newCurrencyController.text.trim();
                      if (code.isEmpty || code.toUpperCase() == 'USD') {
                        setState(() {
                          addError = 'Código inválido.';
                        });
                        return;
                      }
                      // Solo primera letra mayúscula, resto minúscula
                      code =
                          code.substring(0, 1).toUpperCase() +
                          code.substring(1).toLowerCase();
                      if (currencyProvider.availableCurrencies.contains(code)) {
                        setState(() {
                          addError = 'Ya existe esa moneda.';
                        });
                        return;
                      }
                      Navigator.of(ctx).pop();
                      setState(() {
                        selectedCurrency = code;
                        showAddFields = true;
                        addError = null;
                        newCurrencyController.clear();
                      });
                    },
                    child: const Text('Continuar'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    @override
    void dispose() {
      newCurrencyController.dispose();
      // ...existing code...
    }

    // Envolver el AlertDialog en un WillPopScope para interceptar el cierre por tap en la sombra
    void saveAllRates() {
      final currencyProvider = Provider.of<CurrencyProvider>(
        context,
        listen: false,
      );

      // 1. Procesar las eliminaciones pendientes primero
      for (final c in _pendingDeletions) {
        // Si la moneda eliminada es la seleccionada, volver a USD
        if (currencyProvider.currency == c) {
          currencyProvider.setCurrency('USD');
        }
        currencyProvider.removeManualCurrency(c);
      }

      // 2. Guardar tasas de las monedas existentes (que no se eliminaron)
      for (final c in rates.keys) {
        if (_pendingDeletions.contains(c)) continue;
        final text = rates[c]?.text.trim() ?? '';
        final val = double.tryParse(text.replaceAll(',', '.'));
        if (val != null && val > 0) {
          currencyProvider.setRateForCurrency(c, val);
        }
      }

      // 3. Si hay una moneda nueva en proceso de agregar
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
            try {
              currencyProvider.availableCurrencies
                ..clear()
                ..addAll(current);
            } catch (_) {}
          }
        }
      }

      // 4. Actualizar la UI y limpiar el estado
      setState(() {
        // La lista de monedas se actualizará en la próxima reconstrucción desde el provider
        showAddFields = false;
        selectedCurrency = null;
        newRateController.clear();
        addError = null;
        _hasChanges = false;
        _pendingDeletions.clear(); // Limpiar las eliminaciones pendientes
      });
    }

    // Modal tipo BottomSheet personalizado
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollSheetController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).dialogTheme.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(
                  255,
                  255,
                  255,
                  255,
                ).withValues(alpha: (0.08 * 255).toDouble()),
                blurRadius: 0,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.attach_money_rounded, color: Colors.indigo),
                      SizedBox(width: 8),
                      Text(
                        'Gestión de monedas',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Puedes registrar cualquier cantidad de monedas. Aquí puedes fijar la tasa, cambiarla manualmente o eliminar monedas para agregar nuevas.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: true,
                      controller: scrollController,
                      child: ListView(
                        controller: scrollController,
                        children: [
                          ...currencies.where((c) => !_pendingDeletions.contains(c)).map((
                            c,
                          ) {
                            final isNew =
                                showAddFields && selectedCurrency == c;
                            return Card(
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
                                              readOnly: true,
                                              enableInteractiveSelection: false,
                                              controller: isNew
                                                  ? newRateController
                                                  : rates[c],
                                              onTap: () async {
                                                final controller = isNew
                                                    ? newRateController
                                                    : rates[c];
                                                final res = await showDialog<String?>(
                                                  context: context,
                                                  builder: (ctx) {
                                                    final editCtrl =
                                                        TextEditingController(
                                                          text:
                                                              controller
                                                                  ?.text ??
                                                              '',
                                                        );
                                                    return AlertDialog(
                                                      title: Text(
                                                        'Editar tasa $c',
                                                      ),
                                                      content: TextField(
                                                        controller: editCtrl,
                                                        keyboardType:
                                                            const TextInputType.numberWithOptions(
                                                              decimal: true,
                                                            ),
                                                        inputFormatters:
                                                            _rateInputFormatters,
                                                        decoration:
                                                            const InputDecoration(
                                                              labelText:
                                                                  'Tasa a USD',
                                                            ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                ctx,
                                                              ).pop(null),
                                                          child: const Text(
                                                            'Cancelar',
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed: () {
                                                            final text =
                                                                editCtrl.text
                                                                    .trim();
                                                            Navigator.of(
                                                              ctx,
                                                            ).pop(
                                                              text.isNotEmpty
                                                                  ? text
                                                                  : null,
                                                            );
                                                          },
                                                          child: const Text(
                                                            'Guardar',
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                                if (res != null &&
                                                    res.isNotEmpty) {
                                                  // Actualizar el campo visible
                                                  if (controller != null) {
                                                    controller.text = res;
                                                  }

                                                  // Parsear y persistir inmediatamente en el provider
                                                  final parsed =
                                                      double.tryParse(
                                                        res.replaceAll(
                                                          ',',
                                                          '.',
                                                        ),
                                                      );
                                                  final currencyProvider =
                                                      Provider.of<
                                                        CurrencyProvider
                                                      >(context, listen: false);
                                                  if (parsed != null &&
                                                      parsed > 0) {
                                                    if (isNew &&
                                                        selectedCurrency !=
                                                            null) {
                                                      currencyProvider
                                                          .addManualCurrency(
                                                            selectedCurrency!,
                                                          );
                                                      currencyProvider
                                                          .setRateForCurrency(
                                                            selectedCurrency!,
                                                            parsed,
                                                          );
                                                      try {
                                                        final current =
                                                            currencyProvider
                                                                .availableCurrencies
                                                                .toList();
                                                        if (current.contains(
                                                          selectedCurrency!,
                                                        )) {
                                                          current.remove(
                                                            selectedCurrency!,
                                                          );
                                                          current.insert(
                                                            0,
                                                            selectedCurrency!,
                                                          );
                                                          currencyProvider
                                                              .availableCurrencies
                                                            ..clear()
                                                            ..addAll(current);
                                                        }
                                                      } catch (_) {}

                                                      setState(() {
                                                        showAddFields = false;
                                                        selectedCurrency = null;
                                                        newRateController
                                                            .clear();
                                                        addError = null;
                                                        _hasChanges = false;
                                                      });
                                                    } else {
                                                      currencyProvider
                                                          .setRateForCurrency(
                                                            c,
                                                            parsed,
                                                          );
                                                      setState(() {
                                                        _hasChanges = false;
                                                      });
                                                    }
                                                  } else {
                                                    setState(() {
                                                      _hasChanges = true;
                                                    });
                                                  }
                                                }
                                              },
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
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              color: Colors.indigo,
                                              size: 20,
                                            ),
                                            tooltip: 'Editar tasa',
                                            onPressed: () async {
                                              final controller = isNew
                                                  ? newRateController
                                                  : rates[c];
                                              final res = await showDialog<String?>(
                                                context: context,
                                                builder: (ctx) {
                                                  final editCtrl =
                                                      TextEditingController(
                                                        text:
                                                            controller?.text ??
                                                            '',
                                                      );
                                                  return AlertDialog(
                                                    title: Text(
                                                      'Editar tasa $c',
                                                    ),
                                                    content: TextField(
                                                      controller: editCtrl,
                                                      keyboardType:
                                                          const TextInputType.numberWithOptions(
                                                            decimal: true,
                                                          ),
                                                      inputFormatters:
                                                          _rateInputFormatters,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText:
                                                                'Tasa a USD',
                                                          ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              ctx,
                                                            ).pop(null),
                                                        child: const Text(
                                                          'Cancelar',
                                                        ),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed: () {
                                                          final text = editCtrl
                                                              .text
                                                              .trim();
                                                          Navigator.of(ctx).pop(
                                                            text.isNotEmpty
                                                                ? text
                                                                : null,
                                                          );
                                                        },
                                                        child: const Text(
                                                          'Guardar',
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                              if (res != null &&
                                                  res.isNotEmpty) {
                                                // Actualizar el campo visible
                                                final controller = isNew
                                                    ? newRateController
                                                    : rates[c];
                                                if (controller != null) {
                                                  controller.text = res;
                                                }

                                                // Parsear y persistir inmediatamente en el provider
                                                final parsed = double.tryParse(
                                                  res.replaceAll(',', '.'),
                                                );
                                                final currencyProvider =
                                                    Provider.of<
                                                      CurrencyProvider
                                                    >(context, listen: false);
                                                if (parsed != null &&
                                                    parsed > 0) {
                                                  if (isNew &&
                                                      selectedCurrency !=
                                                          null) {
                                                    // Agregar la moneda y asignar la tasa de inmediato
                                                    currencyProvider
                                                        .addManualCurrency(
                                                          selectedCurrency!,
                                                        );
                                                    currencyProvider
                                                        .setRateForCurrency(
                                                          selectedCurrency!,
                                                          parsed,
                                                        );
                                                    // Reordenar para ponerla al principio (igual que saveAllRates)
                                                    try {
                                                      final current =
                                                          currencyProvider
                                                              .availableCurrencies
                                                              .toList();
                                                      if (current.contains(
                                                        selectedCurrency!,
                                                      )) {
                                                        current.remove(
                                                          selectedCurrency!,
                                                        );
                                                        current.insert(
                                                          0,
                                                          selectedCurrency!,
                                                        );
                                                        currencyProvider
                                                            .availableCurrencies
                                                          ..clear()
                                                          ..addAll(current);
                                                      }
                                                    } catch (_) {}

                                                    // Limpiar estado de "agregar"
                                                    setState(() {
                                                      showAddFields = false;
                                                      selectedCurrency = null;
                                                      newRateController.clear();
                                                      addError = null;
                                                      _hasChanges =
                                                          false; // ya persistido
                                                    });
                                                  } else {
                                                    // Moneda existente: persistir directamente
                                                    currencyProvider
                                                        .setRateForCurrency(
                                                          c,
                                                          parsed,
                                                        );
                                                    setState(() {
                                                      _hasChanges =
                                                          false; // ya persistido
                                                    });
                                                  }
                                                } else {
                                                  // Valor inválido: marcar cambio en UI pero no persistir
                                                  setState(() {
                                                    _hasChanges = true;
                                                  });
                                                }
                                              }
                                            },
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
                                              if (isNew) {
                                                setState(() {
                                                  selectedCurrency = null;
                                                  newRateController.clear();
                                                  addError = null;
                                                  showAddFields = false;
                                                });
                                              } else {
                                                final currencyProvider =
                                                    Provider.of<
                                                      CurrencyProvider
                                                    >(context, listen: false);
                                                currencyProvider
                                                    .removeManualCurrency(c);
                                                setState(() {
                                                  rates[c]?.dispose();
                                                  rates.remove(c);
                                                  currencies.remove(c);
                                                  _hasChanges = true;
                                                });
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ScaleOnTap(
                          onTap: showCurrencyPickerDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Agregar Moneda',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ScaleOnTap(
                          onTap: () {
                            saveAllRates();
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              (showAddFields && selectedCurrency != null) ||
                                      _hasChanges
                                  ? 'Guardar'
                                  : 'Cerrar',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize:
                                    (showAddFields &&
                                            selectedCurrency != null) ||
                                        _hasChanges
                                    ? 13.5
                                    : 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

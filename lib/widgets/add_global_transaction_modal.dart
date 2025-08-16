import 'package:flutter/material.dart';
import '../widgets/budgeto_colors.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../models/transaction.dart';
import '../providers/client_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/currency_provider.dart';

class AddGlobalTransactionModal extends StatelessWidget {
  final String userId;
  final Widget? child;
  const AddGlobalTransactionModal({
    super.key,
    required this.userId,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: MediaQuery.of(context).size.height * 0.95,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: child ?? _GlobalTransactionForm(userId: userId),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GlobalTransactionForm extends StatefulWidget {
  final String userId;
  const _GlobalTransactionForm({required this.userId});

  @override
  State<_GlobalTransactionForm> createState() => _GlobalTransactionFormState();
}

class _GlobalTransactionFormState extends State<_GlobalTransactionForm> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _type;
  String? _currencyCode;
  // FIX: Normalizar la fecha inicial a medianoche para evitar que la hora interfiera con el ordenamiento.
  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  Client? _selectedClient;
  String? _error;
  bool _loading = false;
  final _rateController = TextEditingController();
  bool _rateFieldVisible = false;

  // Usar logger en vez de print para errores y advertencias
  Future<void> _save() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    void logError(String message) {
      debugPrint('[GlobalTransactionForm ERROR] $message');
    }

    if (_selectedClient == null) {
      setState(() {
        _error = 'Debes seleccionar un cliente';
        _loading = false;
      });
      logError('Debes seleccionar un cliente');
      return;
    }
    if (_type == null) {
      setState(() {
        _error = 'Debes seleccionar Deuda o Abono';
        _loading = false;
      });
      logError('Debes seleccionar Deuda o Abono');
      return;
    }
    if (_currencyCode == null || _currencyCode!.isEmpty) {
      setState(() {
        _error = 'Debes seleccionar una moneda';
        _loading = false;
      });
      logError('Debes seleccionar una moneda');
      return;
    }
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _error = 'Monto inválido';
        _loading = false;
      });
      logError('Monto inválido');
      return;
    }
    final descText = _descriptionController.text.trim();
    if (descText.isEmpty) {
      setState(() {
        _error = 'Descripción obligatoria';
        _loading = false;
      });
      logError('Descripción obligatoria');
      return;
    }
    if (descText.length > 30) {
      setState(() {
        _error = 'La descripción no puede tener más de 30 caracteres';
        _loading = false;
      });
      logError('Descripción muy larga');
      return;
    }
    // Validar y guardar tasa solo si el campo está visible
    if (_rateFieldVisible) {
      final rateText = _rateController.text.replaceAll(',', '.');
      final rateValue = double.tryParse(rateText);
      if (rateValue == null || rateValue <= 0) {
        setState(() {
          _error = 'Ingrese una tasa válida';
          _loading = false;
        });
        logError('Tasa inválida');
        return;
      } else {
        final currencyProvider = Provider.of<CurrencyProvider>(
          context,
          listen: false,
        );
        // Agregar la moneda manualmente si no existe
        if (_currencyCode != null) {
          final codeUC = _currencyCode!.toUpperCase();
          if (!currencyProvider.availableCurrencies.contains(codeUC)) {
            currencyProvider.addManualCurrency(codeUC);
          }
          currencyProvider.setRateForCurrency(codeUC, rateValue);
        }
      }
    }

    // Se eliminó la validación de límite de monedas no-USD. Ahora se pueden crear transacciones con cualquier cantidad de monedas diferentes a USD.

    try {
      final now = DateTime.now();
      String randomLetters(int n) {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        final rand = DateTime.now().microsecondsSinceEpoch;
        return List.generate(
          n,
          (i) => chars[(rand >> (i * 5)) % chars.length],
        ).join();
      }

      final localId =
          randomLetters(2) + DateTime.now().millisecondsSinceEpoch.toString();
      // --- Cálculo de anchorUsdValue ---
      double? anchorUsdValue;
      final currencyProvider = Provider.of<CurrencyProvider>(
        context,
        listen: false,
      );
      double? rate;
      if (_currencyCode != null) {
        final codeUC = _currencyCode!.toUpperCase();
        rate = currencyProvider.exchangeRates[codeUC];
        if (rate != null && rate > 0) {
          anchorUsdValue = amount / rate;
          debugPrint(
            '\u001b[41m[GLOBAL_FORM][CALC] amount=$amount, currency=$_currencyCode, rate=$rate, anchorUsdValue=$anchorUsdValue\u001b[0m',
          );
        } else if (codeUC == 'USD') {
          anchorUsdValue = amount;
          debugPrint(
            '\u001b[41m[GLOBAL_FORM][CALC] amount=$amount, currency=USD, anchorUsdValue=$anchorUsdValue\u001b[0m',
          );
        } else {
          anchorUsdValue = null;
          debugPrint(
            '\u001b[41m[GLOBAL_FORM][CALC][WARN] No rate for currency=$_currencyCode, anchorUsdValue=null\u001b[0m',
          );
        }
      } else {
        anchorUsdValue = null;
      }
      // FIX: Asegurar que la fecha de la transacción siempre se guarde sin la hora (a medianoche).
      // La hora real de creación se guarda en `createdAt`. Esto es crucial para la consistencia del ordenamiento.
      final normalizedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

      final transaction = Transaction(
        id: localId, // id local único
        clientId: _selectedClient!.id,
        userId: widget.userId,
        type: _type!,
        amount: amount,
        description: _descriptionController.text,
        date: normalizedDate,
        createdAt: now,
        localId: localId,
        currencyCode: _currencyCode!, // safe because already validated
        anchorUsdValue: anchorUsdValue,
      );
      debugPrint(
        '\u001b[41m[GLOBAL_FORM][SAVE] id=$localId, amount=$amount, currency=$_currencyCode, anchorUsdValue=$anchorUsdValue\u001b[0m',
      );
      // Guardar usando TransactionProvider
      final txProvider = Provider.of<TransactionProvider>(
        context,
        listen: false,
      );
      await txProvider.addTransaction(
        transaction,
        widget.userId,
        _selectedClient!.id,
      );
      // --- FIX: Recargar clientes Y transacciones para reconstruir la lista ---
      // Es crucial recargar ambas listas para que la UI refleje el nuevo
      // estado inmediatamente y con el orden correcto. La lista de transacciones
      // necesita ser reconstruida para mostrar el nuevo ítem.
      if (!mounted) return;
      final clientProvider = Provider.of<ClientProvider>(
        context,
        listen: false,
      );
      // Se recargan las transacciones para que la nueva aparezca inmediatamente.
      await txProvider.loadTransactions(widget.userId);
      // Se recargan los clientes para actualizar los saldos.
      await clientProvider.loadClients(widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transacción guardada correctamente')),
        );
        Future.delayed(const Duration(milliseconds: 350), () {
          // ignore: use_build_context_synchronously
          if (Navigator.of(context).canPop()) {
            // ignore: use_build_context_synchronously
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error inesperado: $e';
        _loading = false;
      });
      logError('Error inesperado: $e');
      return;
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ignore: use_build_context_synchronously
  // Se protege el uso de context tras el async gap con mounted
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final clients = context.watch<ClientProvider>().clients;
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = "";
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    // final availableCurrencies = currencyProvider.availableCurrencies; // Eliminada variable no usada
    final allowedCurrencies = CurrencyProvider.allowedCurrencies;
    // Eliminada variable no usada: nonUsdCurrencies
    final codeUC = _currencyCode?.toUpperCase();
    final rateMissing =
        codeUC != null &&
        codeUC != 'USD' &&
        (currencyProvider.exchangeRates[codeUC] == null ||
            currencyProvider.exchangeRates[codeUC] == 0);
    _rateFieldVisible = rateMissing;
    final rateValid =
        double.tryParse(_rateController.text.replaceAll(',', '.')) != null &&
        double.parse(_rateController.text.replaceAll(',', '.')) > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Título principal (antes subtítulo contextual)
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            'Agregar Transacción para',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ),
        // Campo Cliente (debajo del subtítulo contextual)
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Autocomplete<Client>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return clients;
              }
              return clients.where(
                (Client c) =>
                    c.name.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    ) ||
                    (c.address?.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        ) ??
                        false) ||
                    (c.phone?.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        ) ??
                        false),
              );
            },
            displayStringForOption: (Client c) => c.name,
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
                  return SizedBox(
                    height: 40, // Igual que los ítems del menú
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(
                        fontSize: 16,
                      ), // Igual que los ítems
                      decoration: const InputDecoration(
                        labelText: 'Buscar o seleccionar cliente',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                      ),
                    ),
                  );
                },
            onSelected: (Client c) {
              setState(() => _selectedClient = c);
              FocusScope.of(
                context,
              ).unfocus(); // Oculta el teclado al seleccionar un cliente
            },
            optionsViewBuilder: (context, onSelected, options) {
              // Se crea un ScrollController para vincularlo con el Scrollbar y el ListView
              final scrollController = ScrollController();
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: (options.length * 44.0).clamp(44.0, 200.0),
                    ),
                    // Se añade un Scrollbar explícito con el controlador
                    child: Scrollbar(
                      controller: scrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller:
                            scrollController, // Se asigna el controlador a la lista
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final Client c = options.elementAt(index);
                          return InkWell(
                            onTap: () => onSelected(c),
                            child: Container(
                              height:
                                  33, // Menos alto, menos espacio entre ítems
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              alignment: Alignment.centerLeft,
                              // Se reemplaza la Row por un único Text para mostrar solo el nombre
                              child: Text(
                                c.name,
                                style: const TextStyle(fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _type == 'debt'
                  ? Icons.trending_down
                  : _type == 'payment'
                  ? Icons.trending_up
                  : Icons.swap_horiz,
              color: _type == 'debt'
                  ? Colors.red
                  : _type == 'payment'
                  ? Colors.green
                  : Colors.grey,
              size: 32,
            ),
            const SizedBox(width: 8),
            Text(
              _type == 'debt'
                  ? 'Registrar Deuda'
                  : _type == 'payment'
                  ? 'Registrar Abono'
                  : 'Selecciona tipo de movimiento',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: kSliderContainerBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.primary, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToggleTypeButton(
                  selected: _type == 'debt',
                  icon: Icons.trending_down,
                  label: 'Deuda',
                  color: Colors.red,
                  onTap: () => setState(() => _type = 'debt'),
                ),
                SizedBox(width: 45), // Espacio igual que en client_form
                _ToggleTypeButton(
                  selected: _type == 'payment',
                  icon: Icons.trending_up,
                  label: 'Abono',
                  color: Colors.green,
                  onTap: () => setState(() => _type = 'payment'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Monto',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 4),
                    child: Text(
                      symbol,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                  isDense: true,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<String>(
                value: _currencyCode,
                decoration: const InputDecoration(
                  labelText: 'Moneda',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  ...[
                    'USD',
                    ...allowedCurrencies.where((code) => code != 'USD'),
                  ].map(
                    (code) => DropdownMenuItem(value: code, child: Text(code)),
                  ),
                ],
                onChanged: (code) {
                  setState(() {
                    _currencyCode = code;
                    _rateController.text = '';
                  });
                },
                dropdownColor: Colors.white,
                menuMaxHeight: 180,
              ),
            ),
          ],
        ),
        if (_rateFieldVisible)
          Padding(
            padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
            child: TextField(
              controller: _rateController,
              decoration: InputDecoration(
                labelText:
                    'Tasa  {_currencyCode?.toUpperCase() ?? '
                    '} a USD',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.attach_money_rounded),
                errorText: _rateController.text.isNotEmpty && !rateValid
                    ? 'Ingrese una tasa válida (> 0)'
                    : null,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickDate,
          child: AbsorbPointer(
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Fecha',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.event),
                isDense: true,
              ),
              controller: TextEditingController(
                text:
                    '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          maxLength: 30,
          decoration: InputDecoration(
            labelText: 'Descripción',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: Icon(Icons.description),
            isDense: true,
            counterText: '',
          ),
          maxLines: 2,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: _error!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error copiado al portapapeles'),
                  ),
                );
              },
              child: SelectableText(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: _loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(_type == 'debt' ? Icons.save : Icons.check_circle),
            label: Text(
              _loading
                  ? 'Guardando...'
                  : (_type == 'debt' ? 'Guardar Deuda' : 'Guardar Abono'),
            ),
            onPressed: _loading
                ? null
                : () async {
                    await _save();
                  },
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            icon: const Icon(Icons.close),
            label: const Text('Cerrar'),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
      ],
    );
  }
}

class _ToggleTypeButton extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ToggleTypeButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final baseColor = color;
    // .withValues() espera double? para cada canal, así que convertimos a double
    // .withOpacity está deprecado, .withValues es la alternativa, pero para colores simples alpha puede usarse Color.fromARGB
    final selectedColor = Color.fromARGB(
      (0.13 * 255).round(),
      ((baseColor.r * 255.0).round() & 0xff),
      ((baseColor.g * 255.0).round() & 0xff),
      ((baseColor.b * 255.0).round() & 0xff),
    );
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? baseColor : Colors.transparent,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: baseColor, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: baseColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

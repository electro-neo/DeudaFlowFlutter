import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../screens/welcome_screen.dart' as welcome_screen;
import 'package:permission_handler/permission_handler.dart';
import '../widgets/budgeto_colors.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../models/client_hive.dart';
import '../widgets/scale_on_tap.dart';

class ClientForm extends StatefulWidget {
  final Future<ClientHive> Function(ClientHive) onSave;
  final ClientHive? initialClient;
  final String userId;
  final bool readOnlyBalance;

  const ClientForm({
    super.key,
    required this.onSave,
    this.initialClient,
    required this.userId,
    this.readOnlyBalance = false,
  });

  @override
  State<ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends State<ClientForm> {
  // Simulación de almacenamiento de tasas (puedes reemplazar por tu lógica real)
  bool _hasRateForCurrency(String currency) {
    final provider = Provider.of<CurrencyProvider>(context, listen: false);
    return provider.exchangeRates.containsKey(currency.toUpperCase());
  }

  Future<void> _showRegisterRateDialog(String currency) async {
    final controller = TextEditingController();
    double? rate;
    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Registrar tasa para $currency'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Tasa de cambio',
              hintText: 'Ej: 36.5',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                final value = double.tryParse(text);
                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ingresa una tasa válida.')),
                  );
                  return;
                }
                rate = value;
                Navigator.of(ctx).pop(rate);
              },
              child: Text('Guardar'),
            ),
          ],
        );
      },
    );
    if (result != null) {
      final provider = Provider.of<CurrencyProvider>(context, listen: false);
      provider.setRateForCurrency(currency, result);
      // Asegura que la moneda esté en availableCurrencies si no hay transacción aún
      final upper = currency.toUpperCase();
      if (!provider.availableCurrencies.contains(upper)) {
        provider.addManualCurrency(upper);
      }
      setState(() {}); // Para refrescar el widget
    }
  }

  Future<Contact?> _selectContactModal(BuildContext context) async {
    List<Contact> contacts = welcome_screen.globalContacts;
    bool loading = contacts.isEmpty;
    String search = '';
    Contact? selectedContact;
    int currentPage = 0; // <-- Ahora persiste entre setModalState

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (loading) {
              return SizedBox(
                height: 350,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            List<Contact> filtered = contacts
                .where(
                  (c) =>
                      c.displayName.toLowerCase().contains(
                        search.toLowerCase(),
                      ) ||
                      (c.phones.isNotEmpty &&
                          c.phones.first.number.contains(search)),
                )
                .toList();
            int pageSize = 50;
            int pageCount = (filtered.length / pageSize).ceil();
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Buscar contacto',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setModalState(() => search = val);
                      },
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(child: Text('No se encontraron contactos'))
                        : ListView.builder(
                            itemCount: (filtered.length > pageSize
                                ? pageSize
                                : filtered.length - currentPage * pageSize >
                                      pageSize
                                ? pageSize
                                : filtered.length - currentPage * pageSize),
                            itemBuilder: (ctx, i) {
                              final c = filtered[i + currentPage * pageSize];
                              final phone = c.phones.isNotEmpty
                                  ? c.phones.first.number
                                  : '';
                              return ListTile(
                                title: Text(c.displayName),
                                subtitle: Text(phone),
                                onTap: () {
                                  selectedContact = c;
                                  Navigator.of(ctx).pop();
                                },
                              );
                            },
                          ),
                  ),
                  if (pageCount > 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back),
                            onPressed: currentPage > 0
                                ? () => setModalState(() => currentPage--)
                                : null,
                          ),
                          Text('Página ${currentPage + 1} de $pageCount'),
                          IconButton(
                            icon: Icon(Icons.arrow_forward),
                            onPressed: currentPage < pageCount - 1
                                ? () => setModalState(() => currentPage++)
                                : null,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
    return selectedContact;
  }

  // Controla si se muestran los campos de saldo inicial
  bool _showInitialBalanceFields = false;
  String? _initialType; // No seleccionado por defecto
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _balanceController;
  bool _isSaving = false;

  // Lista de monedas (prioridad: USD, VES, COP, EUR, luego otras)
  final List<String> currencyList = [
    'USD',
    'VES',
    'COP',
    'EUR',
    'ARS',
    'BRL',
    'CLP',
    'MXN',
    'PEN',
    'UYU',
    'GBP',
    'CHF',
    'RUB',
    'TRY',
    'JPY',
    'CNY',
    'KRW',
    'INR',
    'SGD',
    'HKD',
    'CAD',
    'AUD',
    'NZD',
    'ZAR',
  ];
  String? _selectedCurrency = 'USD';
  @override
  void initState() {
    super.initState();
    final c = widget.initialClient;
    _nameController = TextEditingController(text: c?.name ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _balanceController = TextEditingController(
      text: c != null ? c.balance.toString() : '',
    );
    if (widget.initialClient != null && widget.readOnlyBalance) {
      // Si es edición, deshabilitar el tipo (deuda/abono) y el balance
      _initialType = c!.balance < 0 ? 'debt' : 'payment';
    } else {
      _initialType = null; // No seleccionado por defecto en registro
    }
  }

  String? _error;

  void _save() async {
    if (!mounted) return;
    // Validaciones antes de mostrar loading
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _error = 'El nombre es obligatorio';
        _isSaving = false;
      });
      return;
    }
    final phoneText = _phoneController.text.trim();
    if (phoneText.isEmpty) {
      setState(() {
        _error = 'El teléfono es obligatorio';
        _isSaving = false;
      });
      return;
    }

    double balance = 0.0;
    String? type = _initialType;
    double? anchorUsdValue;
    // Validar moneda seleccionada
    if (_showInitialBalanceFields) {
      if (_selectedCurrency == null || _selectedCurrency!.isEmpty) {
        setState(() {
          _error = 'Debes seleccionar la moneda.';
          _isSaving = false;
        });
        return;
      }
      if (type == null) {
        setState(() {
          _error = 'Debes seleccionar Deuda o Abono';
          _isSaving = false;
        });
        return;
      }
      final balanceText = _balanceController.text.trim();
      if (balanceText.isEmpty) {
        setState(() {
          _error = 'El saldo es obligatorio';
          _isSaving = false;
        });
        return;
      }
      balance = double.tryParse(balanceText) ?? 0.0;
      if (balance == 0.0 && balanceText != '0' && balanceText != '0.0') {
        setState(() {
          _error = 'Saldo inválido. Solo números y punto decimal.';
          _isSaving = false;
        });
        return;
      }
      // --- Cálculo de anchorUsdValue ---
      final provider = Provider.of<CurrencyProvider>(context, listen: false);
      final rate = provider.exchangeRates[_selectedCurrency!.toUpperCase()];
      if (rate != null && rate > 0) {
        anchorUsdValue = balance / rate;
        debugPrint(
          '\u001b[41m[FORM][CALC] balance=$balance, currency=$_selectedCurrency, rate=$rate, anchorUsdValue=$anchorUsdValue\u001b[0m',
        );
      } else if (_selectedCurrency!.toUpperCase() == 'USD') {
        anchorUsdValue = balance;
        debugPrint(
          '\u001b[41m[FORM][CALC] balance=$balance, currency=USD, anchorUsdValue=$anchorUsdValue\u001b[0m',
        );
      } else {
        anchorUsdValue = null;
        debugPrint(
          '\u001b[41m[FORM][CALC][WARN] No rate for currency=$_selectedCurrency, anchorUsdValue=null\u001b[0m',
        );
      }
    } else {
      // Si no se presionó el botón, balance 0 y tipo null
      balance = 0.0;
      type = null;
      anchorUsdValue = null;
    }
    setState(() {
      _error = null;
      _isSaving = true;
    });
    // Generar un id único local si es nuevo
    String newId =
        widget.initialClient?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final client = ClientHive(
      id: newId,
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      phone: phoneText,
      balance: type == 'debt' ? -balance : balance,
      synced: widget.initialClient?.synced ?? false,
      pendingDelete: widget.initialClient?.pendingDelete ?? false,
      currencyCode: _selectedCurrency ?? 'USD',
      anchorUsdValue: anchorUsdValue, // <-- Ahora sí se pasa correctamente
    );
    debugPrint(
      '\u001b[41m[FORM][SAVE] Cliente id=$newId, balance=$balance, currency=$_selectedCurrency, anchorUsdValue=$anchorUsdValue\u001b[0m',
    );
    try {
      await widget.onSave(client);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('duplicate key value') ||
          msg.contains('already exists')) {
        setState(
          () => _error = 'Ya existe un cliente con ese correo o teléfono.',
        );
      } else if (msg.contains('invalid input syntax for type numeric')) {
        setState(
          () => _error = 'El saldo debe ser un número válido (ej: 1000.00).',
        );
      } else if (msg.contains('PostgrestException')) {
        setState(
          () => _error =
              'Error al guardar los datos. Verifica los campos e inténtalo de nuevo.',
        );
      } else if (msg.contains('unmounted') || msg.contains('defunct')) {
        return;
      } else {
        setState(
          () => _error =
              'No se pudo guardar. Verifica los datos e inténtalo de nuevo.',
        );
      }
      setState(() {
        _isSaving = false;
      });
      return;
    }
    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;
    // Elimina el overlay manual, solo muestra la tarjeta del formulario
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? 400 : 440,
          minWidth: isMobile ? 340 : 380,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: isMobile ? 1.0 : 1.0,
            horizontal: isMobile ? 0.0 : 0.0,
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Datos del cliente',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(
                        0xFF7C3AED,
                      ).withValues(alpha: 0.10 * 255),
                      hoverColor: const Color(
                        0xFF7C3AED,
                      ).withValues(alpha: 0.13 * 255),
                      focusColor: const Color(
                        0xFF7C3AED,
                      ).withValues(alpha: 0.16 * 255),
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Dirección',
                      prefixIcon: const Icon(Icons.home_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(
                        0xFF7C3AED,
                      ).withValues(alpha: 0.10 * 255),
                      hoverColor: const Color(
                        0xFF7C3AED,
                      ).withValues(alpha: 0.13 * 255),
                      focusColor: const Color(
                        0xFF7C3AED,
                      ).withValues(alpha: 0.16 * 255),
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                    ),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.contacts_outlined),
                        tooltip: 'Seleccionar desde contactos',
                        onPressed: () async {
                          final status = await Permission.contacts.status;
                          if (status.isGranted ||
                              (await Permission.contacts.request()).isGranted) {
                            final selected = await _selectContactModal(context);
                            if (selected != null &&
                                selected.phones.isNotEmpty) {
                              _phoneController.text =
                                  selected.phones.first.number;
                              debugPrint(
                                '[CONTACTS] Teléfono seleccionado: ${selected.phones.first.number}',
                              );
                            } else {
                              debugPrint(
                                '[CONTACTS] No se seleccionó contacto o no tiene teléfono',
                              );
                            }
                          } else if (status.isDenied || status.isRestricted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Permiso de contactos denegado o bloqueado.',
                                        maxLines: 2,
                                      ),
                                    ),
                                    TextButton(
                                      child: const Text(
                                        'Ajustes',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: () async {
                                        await openAppSettings();
                                      },
                                    ),
                                    TextButton(
                                      child: const Text(
                                        'Ayuda',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text(
                                              '¿Por qué no funciona el permiso?',
                                            ),
                                            content: const Text(
                                              'Si el permiso de contactos sigue sin funcionar, puede deberse a restricciones del sistema, control parental, o configuraciones de privacidad.\n\nIntenta reiniciar el dispositivo, revisar los permisos en Ajustes, o consultar la documentación de tu sistema operativo. Si el problema persiste, contacta soporte técnico.',
                                            ),
                                            actions: [
                                              TextButton(
                                                child: const Text('Cerrar'),
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.red[700],
                                duration: const Duration(seconds: 6),
                              ),
                            );
                          } else if (status.isPermanentlyDenied) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Permiso de contactos denegado o bloqueado. Debes habilitarlo en Ajustes.',
                                        maxLines: 2,
                                      ),
                                    ),
                                    TextButton(
                                      child: const Text(
                                        'Ajustes',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: () async {
                                        await openAppSettings();
                                      },
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.red[700],
                                duration: const Duration(seconds: 6),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'No se pudo obtener el permiso de contactos.',
                                        maxLines: 2,
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.red[700],
                                duration: const Duration(seconds: 6),
                              ),
                            );
                          }
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(
                        0xFF7C3AED,
                      ).withValues(alpha: 0.10 * 255),
                      hoverColor: const Color(
                        0xFF7C3AED,
                      ).withValues(alpha: 0.13 * 255),
                      focusColor: const Color(
                        0xFF7C3AED,
                      ).withValues(alpha: 0.16 * 255),
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9a-zA-Z+\-() ]'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (!(widget.initialClient != null && widget.readOnlyBalance))
                    if (!_showInitialBalanceFields &&
                        widget.initialClient == null)
                      // Botón para mostrar los campos de saldo inicial
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Center(
                          child: ScaleOnTap(
                            onTap: () => setState(
                              () => _showInitialBalanceFields = true,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: colorScheme.primary,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                'Agregar Saldo Inicial',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5.0),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: kSliderContainerBg,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: colorScheme.primary,
                                width: 1.5,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ToggleTypeButton(
                                  selected: _initialType == 'debt',
                                  icon: Icons.trending_down,
                                  label: 'Deuda',
                                  color: Colors.red,
                                  onTap: () =>
                                      setState(() => _initialType = 'debt'),
                                ),
                                SizedBox(width: 45),
                                _ToggleTypeButton(
                                  selected: _initialType == 'payment',
                                  icon: Icons.trending_up,
                                  label: 'Abono',
                                  color: Colors.green,
                                  onTap: () =>
                                      setState(() => _initialType = 'payment'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _balanceController,
                              decoration: InputDecoration(
                                labelText: 'Monto',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(
                                  Icons.attach_money_outlined,
                                ),
                                filled: true,
                                fillColor: const Color(
                                  0xFF7C3AED,
                                ).withValues(alpha: 0.10 * 255),
                                hoverColor: const Color(
                                  0xFF7C3AED,
                                ).withValues(alpha: 0.13 * 255),
                                focusColor: const Color(
                                  0xFF7C3AED,
                                ).withValues(alpha: 0.16 * 255),
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.auto,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 12,
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'),
                                ),
                              ],
                              enabled:
                                  !(widget.initialClient != null &&
                                      widget.readOnlyBalance),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 110,
                            child: DropdownButtonFormField<String>(
                              value: _selectedCurrency,
                              decoration: const InputDecoration(
                                labelText: 'Moneda',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: currencyList.map((currency) {
                                return DropdownMenuItem<String>(
                                  value: currency,
                                  child: Text(currency),
                                );
                              }).toList(),
                              onChanged: (value) async {
                                if (value == null) return;
                                // Si la moneda no tiene tasa, mostrar el diálogo y solo cambiar si se registra la tasa
                                if (!_hasRateForCurrency(value)) {
                                  final prevCurrency = _selectedCurrency;
                                  await _showRegisterRateDialog(value);
                                  // Si después de registrar, sigue sin tasa (usuario canceló), no cambiar
                                  if (!_hasRateForCurrency(value)) {
                                    // Forzar a que el Dropdown vuelva al valor anterior
                                    setState(() {
                                      _selectedCurrency = prevCurrency;
                                    });
                                    return;
                                  }
                                }
                                setState(() {
                                  _selectedCurrency = value;
                                });
                              },
                              dropdownColor: Colors.white,
                              menuMaxHeight:
                                  180, // Limita la altura del menú desplegable
                            ),
                          ),
                        ],
                      ),
                    ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : (widget.initialClient == null
                                ? const Icon(Icons.save_alt_rounded)
                                : const Icon(Icons.update)),
                      label: Text(
                        _isSaving
                            ? (widget.initialClient == null
                                  ? 'Guardando...'
                                  : 'Actualizando...')
                            : (widget.initialClient == null
                                  ? 'Guardar'
                                  : 'Actualizar Cliente'),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Botón deslizable reutilizable para tipo de saldo/deuda/abono
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
    final selectedColor = baseColor.withValues(alpha: 0.13 * 255);
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

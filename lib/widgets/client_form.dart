import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:azlistview/azlistview.dart';
import 'package:characters/characters.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../screens/welcome_screen.dart' as welcome_screen;
import 'package:permission_handler/permission_handler.dart';
import '../widgets/budgeto_colors.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../models/client_hive.dart';
import '../widgets/scale_on_tap.dart';
import '../utils/currency_utils.dart';
import 'package:intl/intl.dart';

// Formateador de miles en vivo (estilo es-ES), sin forzar decimales mientras se escribe
final NumberFormat _groupFormatEs = NumberFormat.decimalPattern('es');

class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Mantener solo dígitos y separadores
    String filtered = text.replaceAll(RegExp(r"[^0-9.,]"), '');

    // Colapsar múltiples comas a una sola (mantener la primera)
    final firstComma = filtered.indexOf(',');
    if (firstComma >= 0) {
      filtered =
          filtered.substring(0, firstComma + 1) +
          filtered.substring(firstComma + 1).replaceAll(',', '');
    }

    // Eliminar puntos de miles previos
    String noThousands = filtered.replaceAll('.', '');

    // Separar parte entera y decimal
    final parts = noThousands.split(',');
    String intPart = parts.isNotEmpty ? parts[0] : '';
    String decPart = parts.length > 1 ? parts[1] : '';

    // Limitar decimales a 2 mientras se escribe
    if (decPart.length > 2) decPart = decPart.substring(0, 2);

    // Agrupar miles en la parte entera
    String grouped = '';
    if (intPart.isNotEmpty) {
      try {
        grouped = _groupFormatEs.format(int.parse(intPart));
      } catch (_) {
        grouped = intPart; // fallback si excede int, muy raro al escribir
      }
    }

    final hasComma = noThousands.contains(',');
    String result;
    if (hasComma) {
      if (grouped.isEmpty) grouped = '0'; // permite "," inicial -> "0,"
      result = '$grouped,$decPart';
    } else {
      result = grouped;
    }

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
      composing: TextRange.empty,
    );
  }
}

class ClientForm extends StatefulWidget {
  final Future<ClientHive> Function(ClientHive, String?) onSave;
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
    final code = currency.toUpperCase();
    if (code == 'USD') return true;
    final rate = provider.exchangeRates[code];
    return rate != null && rate > 0;
  }

  final TextEditingController _rateController = TextEditingController();
  String? _rateError;
  late final FocusNode _balanceFocusNode;

  Future<Contact?> _selectContactModal(BuildContext context) async {
    List<Contact> contacts = welcome_screen.globalContacts;
    bool loading = contacts.isEmpty;
    String search = '';
    Contact? selectedContact;
    int currentPage = 0; // <-- Ahora persiste entre setModalState
    String activeTag = '';

    // Utilidades de normalización y etiquetas
    String _labelOf(Contact c) {
      final name = c.displayName.trim();
      if (name.isNotEmpty) return name;
      return c.phones.isNotEmpty ? c.phones.first.number : '';
    }

    String _tagFor(String label) {
      if (label.isEmpty) return '#';
      final ch = label.trim().characters.first.toUpperCase();
      final code = ch.codeUnitAt(0);
      // A-Z
      if (code >= 65 && code <= 90) return ch;
      return '#';
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (loading) {
              return SizedBox(
                height: 350,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            // Filtrar contactos: excluir entradas totalmente vacías (sin nombre ni teléfono)
            List<Contact> filtered = contacts.where((c) {
              final label = _labelOf(c).trim();
              final hasPhone =
                  c.phones.isNotEmpty &&
                  (c.phones.first.number.trim().isNotEmpty);
              if (!hasPhone && label.isEmpty) return false;
              if (search.isEmpty) return true;
              final s = search.toLowerCase();
              return label.toLowerCase().contains(s) ||
                  (hasPhone && c.phones.first.number.toLowerCase().contains(s));
            }).toList();

            // Ordenar alfabéticamente por etiqueta visible (case-insensitive)
            filtered.sort(
              (a, b) => _labelOf(
                a,
              ).toLowerCase().compareTo(_labelOf(b).toLowerCase()),
            );

            // Decidir si usar paginación (> 3000)
            final bool usePagination = filtered.length > 3000;
            final int pageSize = usePagination ? 1000 : filtered.length;
            final int pageCount = filtered.isEmpty
                ? 1
                : ((filtered.length - 1) / pageSize).floor() + 1;

            // Cortar por página si aplica
            final int start = (currentPage * pageSize).clamp(
              0,
              filtered.length,
            );
            final int end = (start + pageSize).clamp(0, filtered.length);
            final List<Contact> pageSlice = filtered.isEmpty
                ? []
                : filtered.sublist(start, end);

            // Adaptar a AzListView con índice alfabético
            final List<_ContactItem> items = pageSlice.map((c) {
              final label = _labelOf(c);
              return _ContactItem(
                contact: c,
                name: label,
                phone: c.phones.isNotEmpty ? c.phones.first.number : '',
                tag: _tagFor(label),
              );
            }).toList();

            // Ordenar por tag y preparar cabeceras
            SuspensionUtil.sortListBySuspensionTag(items);
            SuspensionUtil.setShowSuspensionStatus(items);
            final indexTags = SuspensionUtil.getTagIndexList(items);
            if (activeTag.isEmpty || !indexTags.contains(activeTag)) {
              activeTag = indexTags.isNotEmpty ? indexTags.first : '#';
            }

            final screenHeight = MediaQuery.of(ctx).size.height;
            final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
            final isMobile = MediaQuery.of(ctx).size.width < 600;
            final percent = isMobile ? 0.65 : 0.8;
            final maxModalHeight = 520.0;
            final availableHeight = screenHeight - keyboardHeight;
            final modalHeight = [
              screenHeight * percent,
              availableHeight,
              maxModalHeight,
            ].reduce((a, b) => a < b ? a : b);
            return AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardHeight),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: modalHeight,
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
                            setModalState(() {
                              search = val;
                              currentPage = 0;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: items.isEmpty
                            ? const Center(
                                child: Text('No se encontraron contactos'),
                              )
                            : LayoutBuilder(
                                builder: (ctx, constraints) {
                                  final double vh = constraints.maxHeight;
                                  final int tagCount = indexTags.isEmpty
                                      ? 1
                                      : indexTags.length;
                                  // Calcular altura segura por ítem del index bar considerando márgenes,
                                  // para que quepa sin overflow incluso con teclado abierto.
                                  final double vSpacing =
                                      1.0; // espaciado vertical por elemento
                                  final double totalSpacing =
                                      vSpacing * 2 * tagCount;
                                  final double availableForItems = math.max(
                                    0.0,
                                    vh - totalSpacing - 4.0,
                                  );
                                  final double itemH =
                                      (availableForItems / tagCount).clamp(
                                        6.0,
                                        18.0,
                                      );
                                  // Lista + overlay de índice interactivo con "zoom" visual.
                                  return Stack(
                                    children: [
                                      AzListView(
                                        data: items,
                                        itemCount: items.length,
                                        padding: EdgeInsets.zero,
                                        indexBarItemHeight: itemH,
                                        indexBarMargin: EdgeInsets.symmetric(
                                          vertical: vSpacing,
                                        ),
                                        itemBuilder: (ctx, i) {
                                          final item = items[i];
                                          final titleText = item.name.isNotEmpty
                                              ? item.name
                                              : (item.phone.isNotEmpty
                                                    ? item.phone
                                                    : 'Contacto');
                                          return ListTile(
                                            title: Text(titleText),
                                            subtitle:
                                                item.phone.isNotEmpty &&
                                                    item.name != item.phone
                                                ? Text(item.phone)
                                                : null,
                                            onTap: () {
                                              selectedContact = item.contact;
                                              Navigator.of(ctx).pop();
                                            },
                                          );
                                        },
                                        susItemBuilder: (ctx, i) {
                                          final tag = items[i]
                                              .getSuspensionTag();
                                          return _AzHeader(tag: tag);
                                        },
                                        indexBarData: keyboardHeight > 0
                                            ? const <String>[]
                                            : indexTags,
                                        indexBarOptions: const IndexBarOptions(
                                          needRebuild: true,
                                          selectTextStyle: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          selectItemDecoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.deepPurple,
                                          ),
                                        ),
                                        indexHintBuilder: (ctx, hint) {
                                          // Oculta el bubble si el teclado está abierto
                                          final kb = MediaQuery.of(
                                            ctx,
                                          ).viewInsets.bottom;
                                          if (kb > 0) {
                                            return const SizedBox.shrink();
                                          }
                                          // Actualiza la letra activa mientras el usuario interactúa con el índice
                                          if (hint.isNotEmpty) {
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                                  if (mounted) {
                                                    setModalState(
                                                      () => activeTag = hint,
                                                    );
                                                  }
                                                });
                                          }
                                          return Container(
                                            width: 84,
                                            height: 84,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(
                                                0.65,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              hint,
                                              style: const TextStyle(
                                                fontSize: 42,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      // Máscara visual para ocultar el índice nativo pero conservar gestos debajo
                                      if (keyboardHeight <= 0 &&
                                          indexTags.isNotEmpty)
                                        IgnorePointer(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Container(
                                              width: 28,
                                              margin: const EdgeInsets.only(
                                                right: 0,
                                                bottom: 8,
                                              ),
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      // Overlay visual del índice (ventana alrededor del tag activo)
                                      if (keyboardHeight <= 0)
                                        IgnorePointer(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                right: 6.0,
                                                bottom: keyboardHeight > 0
                                                    ? keyboardHeight + 8
                                                    : 8,
                                              ),
                                              child: LayoutBuilder(
                                                builder: (c, cons) {
                                                  final tags = indexTags;
                                                  final int total = tags.length;
                                                  if (total == 0)
                                                    return const SizedBox.shrink();
                                                  final int centerIndex = tags
                                                      .indexOf(activeTag)
                                                      .clamp(0, total - 1);
                                                  const int window =
                                                      11; // 9-11 letras visibles
                                                  int start =
                                                      centerIndex -
                                                      (window ~/ 2);
                                                  if (start < 0) start = 0;
                                                  int end = (start + window);
                                                  if (end > total) {
                                                    end = total;
                                                    start = math.max(
                                                      0,
                                                      end - window,
                                                    );
                                                  }
                                                  final visible = tags.sublist(
                                                    start,
                                                    end,
                                                  );

                                                  return Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: visible.map((t) {
                                                      final isActive =
                                                          t == activeTag;
                                                      return Container(
                                                        margin:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 2,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 2,
                                                              horizontal: 6,
                                                            ),
                                                        decoration: isActive
                                                            ? BoxDecoration(
                                                                color: Colors
                                                                    .deepPurple
                                                                    .withOpacity(
                                                                      0.15,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                              )
                                                            : null,
                                                        child: Text(
                                                          t,
                                                          style: TextStyle(
                                                            fontSize: isActive
                                                                ? 16
                                                                : 12,
                                                            fontWeight: isActive
                                                                ? FontWeight
                                                                      .w700
                                                                : FontWeight
                                                                      .w500,
                                                            color: isActive
                                                                ? Colors
                                                                      .deepPurple
                                                                : Colors.black
                                                                      .withOpacity(
                                                                        0.55,
                                                                      ),
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                      ),
                      SizedBox(
                        height: 40,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (pageCount > 1)
                                IconButton(
                                  icon: Icon(Icons.arrow_back),
                                  onPressed: currentPage > 0
                                      ? () => setModalState(() => currentPage--)
                                      : null,
                                ),
                              if (pageCount > 1)
                                Text('Página ${currentPage + 1} de $pageCount'),
                              if (pageCount > 1)
                                IconButton(
                                  icon: Icon(Icons.arrow_forward),
                                  onPressed: currentPage < pageCount - 1
                                      ? () => setModalState(() => currentPage++)
                                      : null,
                                ),
                              // Botón de sincronizar contactos
                              if (keyboardHeight <= 0)
                                IconButton(
                                  icon: Icon(Icons.sync),
                                  tooltip: 'Sincronizar contactos',
                                  onPressed: () async {
                                    showDialog(
                                      context: ctx,
                                      barrierDismissible: false,
                                      builder: (dctx) => Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                    try {
                                      final status =
                                          await Permission.contacts.status;
                                      if (status.isGranted ||
                                          (await Permission.contacts.request())
                                              .isGranted) {
                                        final systemContacts =
                                            await FlutterContacts.getContacts(
                                              withProperties: true,
                                            );
                                        await welcome_screen.saveContactsToHive(
                                          systemContacts,
                                        );
                                        welcome_screen.globalContacts =
                                            systemContacts;
                                        contacts = systemContacts;
                                        setModalState(() {
                                          currentPage = 0;
                                        });
                                      }
                                    } catch (e) {
                                      debugPrint(
                                        '[SYNC] Error al sincronizar contactos: $e',
                                      );
                                    }
                                    if (Navigator.of(ctx).canPop()) {
                                      Navigator.of(
                                        ctx,
                                      ).pop(); // Cierra el indicador de carga
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Contactos sincronizados correctamente.',
                                        ),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
  late final TextEditingController _initialDescriptionController;
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
  String? _selectedCurrency;
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
    _initialDescriptionController = TextEditingController();
    _balanceFocusNode = FocusNode();
    _balanceFocusNode.addListener(_onBalanceFocusChange);
    if (widget.initialClient != null && widget.readOnlyBalance) {
      // Si es edición, deshabilitar el tipo (deuda/abono) y el balance
      _initialType = c!.balance < 0 ? 'debt' : 'payment';
    } else {
      _initialType = null; // No seleccionado por defecto en registro
    }
  }

  void _onBalanceFocusChange() {
    if (!_balanceFocusNode.hasFocus) {
      final t = _balanceController.text.trim();
      if (t.isEmpty) return;
      // Quitar puntos (miles) y normalizar coma decimal
      String cleaned = t.replaceAll('.', '');
      int commaIdx = cleaned.indexOf(',');
      String intPart;
      String decPart;
      if (commaIdx >= 0) {
        intPart = cleaned.substring(0, commaIdx);
        decPart = cleaned
            .substring(commaIdx + 1)
            .replaceAll(RegExp(r'[^0-9]'), '');
      } else {
        intPart = cleaned;
        decPart = '';
      }
      if (intPart.isEmpty) intPart = '0';
      // Asegurar exactamente 2 decimales
      decPart = (decPart + '00').substring(0, 2);
      String grouped;
      try {
        grouped = _groupFormatEs.format(int.parse(intPart));
      } catch (_) {
        grouped = intPart;
      }
      final result = '$grouped,$decPart';
      _balanceController.value = TextEditingValue(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    }
  }

  @override
  void dispose() {
    _balanceFocusNode.removeListener(_onBalanceFocusChange);
    _balanceFocusNode.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _balanceController.dispose();
    _initialDescriptionController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  String? _error;

  void _save() async {
    final nameText = _nameController.text.trim();
    final phoneText = _phoneController.text.trim();
    // Validación de campos obligatorios
    if (nameText.isEmpty) {
      setState(() {
        _error = 'El nombre es obligatorio.';
        _isSaving = false;
      });
      return;
    }
    if (phoneText.isEmpty) {
      setState(() {
        _error = 'El teléfono es obligatorio.';
        _isSaving = false;
      });
      return;
    }
    double balance = 0.0;
    String? type = _initialType;
    double? anchorUsdValue;
    String? currencyCode;
    String initialDescription = '';
    if (_showInitialBalanceFields) {
      if (_selectedCurrency == null || _selectedCurrency!.isEmpty) {
        setState(() {
          _error = 'Debes seleccionar la moneda.';
          _isSaving = false;
        });
        return;
      }
      currencyCode = _selectedCurrency;
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
      // Normalizar: "1.234,56" -> "1234.56"
      final normalized = balanceText.replaceAll('.', '').replaceAll(',', '.');
      final parsed = double.tryParse(normalized);
      if (parsed == null) {
        setState(() {
          _error = 'Saldo inválido. Usa coma o punto para decimales.';
          _isSaving = false;
        });
        return;
      }
      balance = parsed;
      initialDescription = _initialDescriptionController.text.trim();
      if (initialDescription.isEmpty) {
        setState(() {
          _error = 'Debes agregar una descripción';
          _isSaving = false;
        });
        return;
      }
      // --- Cálculo de anchorUsdValue ---
      final provider = Provider.of<CurrencyProvider>(context, listen: false);
      final codeUC = _selectedCurrency!.toUpperCase();
      double? rate = provider.exchangeRates[codeUC];
      if (codeUC != 'USD' && (rate == null || rate <= 0)) {
        // Si no hay tasa registrada, tomar la del campo manual
        final rateText = _rateController.text.trim().replaceAll(',', '.');
        if (rateText.isEmpty) {
          setState(() {
            _rateError = 'Debes ingresar la tasa para $codeUC.';
            _isSaving = false;
          });
          return;
        }
        final manualRate = double.tryParse(rateText);
        if (manualRate == null || manualRate <= 0) {
          setState(() {
            _rateError = 'Tasa inválida. Solo números mayores a 0.';
            _isSaving = false;
          });
          return;
        }
        // Guardar la tasa en el provider para futuras operaciones
        // Asegura que la moneda exista en el provider (para que aparezca en Currency Manager)
        if (!provider.availableCurrencies.contains(codeUC)) {
          provider.addManualCurrency(codeUC);
        }
        provider.setRateForCurrency(codeUC, manualRate);
        rate = manualRate;
        _rateError = null;
      }
      if (rate != null && rate > 0) {
        anchorUsdValue = CurrencyUtils.normalizeAnchorUsd(balance / rate);
        debugPrint(
          '\u001b[41m[FORM][CALC] balance=$balance, currency=$_selectedCurrency, rate=$rate, anchorUsdValue=$anchorUsdValue\u001b[0m',
        );
      } else if (codeUC == 'USD') {
        anchorUsdValue = CurrencyUtils.normalizeAnchorUsd(balance);
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
      // Si no se muestran los campos de saldo inicial, no se requiere moneda
      balance = 0.0;
      type = null;
      anchorUsdValue = null;
      currencyCode = null;
      initialDescription = '';
    }
    setState(() {
      _error = null;
      _isSaving = true;
    });

    // Generar un id único local si es nuevo
    String newId =
        widget.initialClient?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final name = capitalizeWords(nameText);
    final client = ClientHive(
      id: newId,
      name: name,
      address: _addressController.text.trim(),
      phone: phoneText,
      balance: type == 'debt' ? -balance : balance,
      synced: widget.initialClient?.synced ?? false,
      pendingDelete: widget.initialClient?.pendingDelete ?? false,
      currencyCode: currencyCode ?? 'VES', // Nunca null, por defecto VES
      anchorUsdValue: anchorUsdValue, // Puede ser null si no hay saldo inicial
    );
    debugPrint(
      '\u001b[41m[FORM][SAVE] Cliente id=$newId, balance=$balance, currency=$_selectedCurrency, anchorUsdValue=$anchorUsdValue\u001b[0m',
    );

    // Cerrar el formulario tras 1 segundo, pero seguir guardando en background
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });

    // Guardar en background (sin esperar el cierre del formulario)
    try {
      await widget.onSave(client, initialDescription);
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

  String capitalizeWords(String name) {
    // Usa Characters para no romper pares sustitutos (emoji, acentos compuestos)
    return name
        .trim()
        .split(RegExp(r'\s+'))
        .map((word) {
          final chars = word.characters;
          if (chars.isEmpty) return '';
          final first = chars.first.toUpperCase();
          final rest = chars.skip(1).toString().toLowerCase();
          return '$first$rest';
        })
        .join(' ');
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
                    maxLength: 27,
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
                      counterText: '',
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
                            // ignore: use_build_context_synchronously
                            final selected = await _selectContactModal(context);
                            if (selected != null &&
                                selected.phones.isNotEmpty) {
                              _phoneController.text =
                                  selected.phones.first.number;
                              _nameController.text = selected.displayName;
                              debugPrint(
                                '[CONTACTS] Teléfono seleccionado: ${selected.phones.first.number}',
                              );
                              debugPrint(
                                '[CONTACTS] Nombre seleccionado: ${selected.displayName}',
                              );
                            } else {
                              debugPrint(
                                '[CONTACTS] No se seleccionó contacto o no tiene teléfono',
                              );
                            }
                          } else if (status.isDenied || status.isRestricted) {
                            // ignore: use_build_context_synchronously
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
                            // ignore: use_build_context_synchronously
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
                            // ignore: use_build_context_synchronously
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
                        RegExp(r'[0-9 +\-]'),
                      ), //
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
                                color: colorScheme.primary.withValues(
                                  alpha: 0.08 * 255,
                                ),
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
                                  RegExp(r'[0-9.,]'),
                                ),
                                ThousandsFormatter(),
                              ],
                              focusNode: _balanceFocusNode,
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
                              items: [
                                ...currencyList.map(
                                  (currency) => DropdownMenuItem<String>(
                                    value: currency,
                                    child: Text(currency),
                                  ),
                                ),
                              ],
                              onChanged: (value) async {
                                if (value == null) return;
                                setState(() {
                                  _selectedCurrency = value;
                                  // Limpiar campo de tasa si cambia la moneda
                                  _rateController.clear();
                                  _rateError = null;
                                });
                              },
                              dropdownColor: Colors.white,
                              menuMaxHeight:
                                  180, // Limita la altura del menú desplegable
                            ),
                          ),
                        ],
                      ),
                      // Campo de tasa si la moneda seleccionada no tiene tasa y no es USD
                      if (_selectedCurrency != null &&
                          _selectedCurrency!.toUpperCase() != 'USD' &&
                          !_hasRateForCurrency(_selectedCurrency!))
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 10.0,
                            left: 2.0,
                            right: 2.0,
                          ),
                          child: TextField(
                            controller: _rateController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Tasa',
                              hintText:
                                  'Tasa ${_selectedCurrency?.toUpperCase() ?? ''} a USD',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.currency_exchange),
                              errorText: _rateError,
                              filled: true,
                              fillColor: const Color(
                                0xFF7C3AED,
                              ).withOpacity(0.07),
                              floatingLabelBehavior: FloatingLabelBehavior.auto,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 5.0),
                        child: TextField(
                          controller: _initialDescriptionController,
                          decoration: InputDecoration(
                            labelText: 'Descripción',
                            prefixIcon: const Icon(Icons.description_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: const Color(
                              0xFF7C3AED,
                            ).withOpacity(0.07),
                            floatingLabelBehavior: FloatingLabelBehavior.auto,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 12,
                            ),
                          ),
                          maxLength: 60,
                        ),
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

// Modelo adaptador para AzListView
class _ContactItem extends ISuspensionBean {
  final Contact contact;
  final String name;
  final String phone;
  String tag;
  _ContactItem({
    required this.contact,
    required this.name,
    required this.phone,
    required this.tag,
  });

  @override
  String getSuspensionTag() => tag;
}

// Cabecera visual para cada letra
class _AzHeader extends StatelessWidget {
  final String tag;
  const _AzHeader({required this.tag});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      // width: double.infinity, // Eliminar para evitar BoxConstraints infinite width
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.black12,
      alignment: Alignment.centerLeft,
      child: Text(
        tag,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}

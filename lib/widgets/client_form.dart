import 'package:flutter/material.dart';
import '../widgets/budgeto_colors.dart';
import 'package:flutter/services.dart';
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
  // Controla si se muestran los campos de saldo inicial
  bool _showInitialBalanceFields = false;
  String? _initialType; // No seleccionado por defecto
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _balanceController;
  bool _isSaving = false;
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
    // Si el usuario presionó "Agregar Saldo Inicial", validar los campos
    if (_showInitialBalanceFields) {
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
    } else {
      // Si no se presionó el botón, balance 0 y tipo null
      balance = 0.0;
      type = null;
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
          maxWidth: isMobile ? 380 : 400,
          minWidth: isMobile ? 320 : 340,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: isMobile ? 4.0 : 8.0,
            horizontal: isMobile ? 0.0 : 2.0,
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
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
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                      TextField(
                        controller: _balanceController,
                        decoration: InputDecoration(
                          labelText: 'Monto',
                          prefixIcon: const Icon(Icons.attach_money_outlined),
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        enabled:
                            !(widget.initialClient != null &&
                                widget.readOnlyBalance),
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

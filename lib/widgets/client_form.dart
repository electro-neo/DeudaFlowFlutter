import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/client.dart';

class ClientForm extends StatefulWidget {
  final Future<Client> Function(Client) onSave;
  final Client? initialClient;
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
  String? _initialType; // No seleccionado por defecto
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _balanceController;
  @override
  void initState() {
    super.initState();
    final c = widget.initialClient;
    _nameController = TextEditingController(text: c?.name ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
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
    setState(() => _error = null);
    if (_nameController.text.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _error = 'El nombre es obligatorio');
      return;
    }
    // Validar selección de tipo deuda/abono
    if (widget.initialClient == null && _initialType == null) {
      if (!mounted) return;
      setState(() => _error = 'Debes seleccionar Deuda o Abono');
      return;
    }
    // Validar que el teléfono y el saldo no estén vacíos
    final phoneText = _phoneController.text.trim();
    if (phoneText.isEmpty) {
      if (!mounted) return;
      setState(() => _error = 'El teléfono es obligatorio');
      return;
    }
    final balanceText = _balanceController.text.trim();
    if (balanceText.isEmpty) {
      if (!mounted) return;
      setState(() => _error = 'El saldo es obligatorio');
      return;
    }
    final balance = double.tryParse(balanceText);
    if (balance == null) {
      if (!mounted) return;
      setState(() => _error = 'Saldo inválido. Solo números y punto decimal.');
      return;
    }
    final client = Client(
      id: '',
      name: _nameController.text,
      email: _emailController.text,
      phone: phoneText,
      balance: _initialType == 'debt' ? -balance : balance,
    );
    try {
      await widget.onSave(client);
      // El cierre del modal lo hace el padre (clients_screen.dart)
    } catch (e) {
      // Si el widget ya fue desmontado, no intentes mostrar error
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
        // No mostrar nada si el widget ya no está montado
        return;
      } else {
        setState(
          () => _error =
              'No se pudo guardar. Verifica los datos e inténtalo de nuevo.',
        );
      }
      return;
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
                      fillColor: const Color(0xFF7C3AED).withOpacity(0.10),
                      hoverColor: const Color(0xFF7C3AED).withOpacity(0.13),
                      focusColor: const Color(0xFF7C3AED).withOpacity(0.16),
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF7C3AED).withOpacity(0.10),
                      hoverColor: const Color(0xFF7C3AED).withOpacity(0.13),
                      focusColor: const Color(0xFF7C3AED).withOpacity(0.16),
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
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
                      fillColor: const Color(0xFF7C3AED).withOpacity(0.10),
                      hoverColor: const Color(0xFF7C3AED).withOpacity(0.13),
                      focusColor: const Color(0xFF7C3AED).withOpacity(0.16),
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
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
                      fillColor: const Color(0xFF7C3AED).withOpacity(0.10),
                      hoverColor: const Color(0xFF7C3AED).withOpacity(0.13),
                      focusColor: const Color(0xFF7C3AED).withOpacity(0.16),
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
                      onPressed: _save,
                      icon: widget.initialClient == null
                          ? const Icon(Icons.save_alt_rounded)
                          : const Icon(Icons.update),
                      label: Text(
                        widget.initialClient == null
                            ? 'Guardar'
                            : 'Actualizar Cliente',
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
    final selectedColor = baseColor.withOpacity(0.13);
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

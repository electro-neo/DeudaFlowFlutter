import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction.dart';
import '../models/client.dart';
// import '../providers/currency_provider.dart';
// import '../utils/currency_utils.dart';

class TransactionForm extends StatefulWidget {
  final void Function(Transaction)? onSave;
  final String userId;
  final VoidCallback? onClose;
  final Client? initialClient;
  const TransactionForm({
    super.key,
    required this.userId,
    this.onSave,
    this.onClose,
    this.initialClient,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _type; // No seleccionado por defecto
  DateTime _selectedDate = DateTime.now();
  Client? _selectedClient;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialClient != null) {
      _selectedClient = widget.initialClient;
    }
  }

  // Usar logger en vez de print para errores y advertencias
  Future<void> _save() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    void logError(String message) {
      // Reemplaza por tu logger preferido si tienes uno global, por ejemplo: logger.e(message);
      debugPrint('[TransactionForm ERROR] $message');
    }

    // Validaciones
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
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _error = 'Monto inválido';
        _loading = false;
      });
      logError('Monto inválido');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      setState(() {
        _error = 'Descripción obligatoria';
        _loading = false;
      });
      logError('Descripción obligatoria');
      return;
    }
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
      if (widget.onSave != null) {
        await Future.delayed(
          const Duration(milliseconds: 350),
        ); // Simula espera de guardado
        widget.onSave!(
          Transaction(
            id: localId, // id local único
            clientId: _selectedClient!.id,
            userId: widget.userId,
            type: _type!,
            amount: amount,
            description: _descriptionController.text,
            date: _selectedDate,
            createdAt: now,
            localId: localId,
          ),
        );
      }
      // ignore: use_build_context_synchronously
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Transacción guardada correctamente')),
      );
      // Cierra el modal automáticamente al guardar
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          Navigator.of(context, rootNavigator: true).pop();
        }
      });
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = "";
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Título sin botón X
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Agregar Transacción para ${_selectedClient?.name ?? ''}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    // El campo de cliente se elimina aquí porque el cliente ya se selecciona desde el ClientCard
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
                              : 'Selecciona tipo',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Selector igual al de add_global_transaction_modal.dart
                    Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(
                            red:
                                ((colorScheme.primary.r * 255.0).round() & 0xff)
                                    .toDouble(),
                            green:
                                ((colorScheme.primary.g * 255.0).round() & 0xff)
                                    .toDouble(),
                            blue:
                                ((colorScheme.primary.b * 255.0).round() & 0xff)
                                    .toDouble(),
                            alpha: 0.08 * 255,
                          ),
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
                              selected: _type == 'debt',
                              icon: Icons.trending_down,
                              label: 'Deuda',
                              color: Colors.red,
                              onTap: () => setState(() => _type = 'debt'),
                            ),
                            SizedBox(width: 45), // Igual separación visual
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
                    TextField(
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
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
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
                      decoration: InputDecoration(
                        labelText: 'Descripción',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(Icons.description),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: GestureDetector(
                          onLongPress: () {
                            Clipboard.setData(ClipboardData(text: _error!));
                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Icon(
                                _type == 'debt'
                                    ? Icons.save
                                    : Icons.check_circle,
                              ),
                        label: Text(
                          _loading
                              ? 'Guardando...'
                              : (_type == 'debt'
                                    ? 'Guardar Deuda'
                                    : 'Guardar Abono'),
                        ),
                        onPressed: _loading ? null : _save,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                          side: BorderSide(
                            color: colorScheme.primary,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        icon: const Icon(Icons.close),
                        label: const Text('Cerrar'),
                        onPressed: () {
                          if (widget.onClose != null) {
                            widget.onClose!();
                          } else {
                            Navigator.of(context, rootNavigator: true).pop();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Botón para alternar tipo de transacción (deuda/abono)
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
    // Reemplazo de .withOpacity() deprecado por .withValues para precisión
    final selectedColor = baseColor.withValues(
      red: ((baseColor.r * 255.0).round() & 0xff).toDouble(),
      green: ((baseColor.g * 255.0).round() & 0xff).toDouble(),
      blue: ((baseColor.b * 255.0).round() & 0xff).toDouble(),
      alpha: 0.13 * 255,
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

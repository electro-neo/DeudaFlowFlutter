import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/client.dart';
import '../providers/client_provider.dart';
import '../providers/currency_provider.dart';
import 'package:provider/provider.dart';
import '../utils/currency_utils.dart';

class TransactionForm extends StatefulWidget {
  final void Function(Transaction)? onSave;
  final String clientId;
  final String userId;
  final VoidCallback? onClose;
  const TransactionForm({
    super.key,
    required this.clientId,
    required this.userId,
    this.onSave,
    this.onClose,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _type; // No seleccionado por defecto
  DateTime _selectedDate = DateTime.now();

  String? _error;
  bool _loading = false;

  Future<void> _save() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    if (_type == null) {
      setState(() {
        _error = 'Debes seleccionar Deuda o Abono';
        _loading = false;
      });
      return;
    }
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _error = 'Monto inválido';
        _loading = false;
      });
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      setState(() {
        _error = 'Descripción obligatoria';
        _loading = false;
      });
      return;
    }
    try {
      final now = DateTime.now();
      if (widget.onSave != null) {
        widget.onSave!(
          Transaction(
            id: '',
            clientId: widget.clientId,
            userId: widget.userId,
            type: _type!,
            amount: amount,
            description: _descriptionController.text,
            date: _selectedDate,
            createdAt: now,
          ),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transacción guardada correctamente')),
        );
        // Cerrar automáticamente el modal después de guardar
        Future.delayed(const Duration(milliseconds: 350), () {
          if (widget.onClose != null) {
            widget.onClose!();
          } else {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error inesperado: $e';
        _loading = false;
      });
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
    context.watch<CurrencyProvider>();
    final clientProvider = Provider.of<ClientProvider>(context, listen: false);
    final client = clientProvider.clients.firstWhere(
      (c) => c.id == widget.clientId,
      orElse: () => Client(id: '', name: 'Usuario', balance: 0),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = CurrencyUtils.symbol(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                minWidth: 0,
                minHeight: 0,
                maxHeight: constraints.maxHeight * 0.95,
              ),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20, // Menos separación arriba
                    bottom: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Título sin botón X
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Agregar Transacción para ${client.name}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
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
                                : 'Selecciona tipo',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: GestureDetector(
                          onHorizontalDragEnd: (details) {
                            setState(() {
                              if (_type == 'debt') {
                                _type = 'payment';
                              } else {
                                _type = 'debt';
                              }
                            });
                          },
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
                                  selected: _type == 'debt',
                                  icon: Icons.trending_down,
                                  label: 'Deuda',
                                  color: Colors.red,
                                  onTap: () => setState(() => _type = 'debt'),
                                ),
                                _ToggleTypeButton(
                                  selected: _type == 'payment',
                                  icon: Icons.trending_up,
                                  label: 'Abono',
                                  color: Colors.green,
                                  onTap: () =>
                                      setState(() => _type = 'payment'),
                                ),
                              ],
                            ),
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
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
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
                          onPressed:
                              widget.onClose ??
                              () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

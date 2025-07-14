import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../models/transaction.dart';
import '../providers/client_provider.dart';
import '../providers/transaction_provider.dart';

class AddGlobalTransactionModal extends StatelessWidget {
  final String userId;
  const AddGlobalTransactionModal({super.key, required this.userId});

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
                child: _GlobalTransactionForm(userId: userId),
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
  DateTime _selectedDate = DateTime.now();
  Client? _selectedClient;
  String? _error;
  bool _loading = false;

  Future<void> _save() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    if (_selectedClient == null) {
      setState(() {
        _error = 'Debes seleccionar un cliente';
        _loading = false;
      });
      print('[GlobalTransactionForm ERROR] Debes seleccionar un cliente');
      return;
    }
    if (_type == null) {
      setState(() {
        _error = 'Debes seleccionar Deuda o Abono';
        _loading = false;
      });
      print('[GlobalTransactionForm ERROR] Debes seleccionar Deuda o Abono');
      return;
    }
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _error = 'Monto inválido';
        _loading = false;
      });
      print('[GlobalTransactionForm ERROR] Monto inválido');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      setState(() {
        _error = 'Descripción obligatoria';
        _loading = false;
      });
      print('[GlobalTransactionForm ERROR] Descripción obligatoria');
      return;
    }
    try {
      final now = DateTime.now();
      String _randomLetters(int n) {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        final rand = DateTime.now().microsecondsSinceEpoch;
        return List.generate(
          n,
          (i) => chars[(rand >> (i * 5)) % chars.length],
        ).join();
      }

      final localId =
          _randomLetters(2) + DateTime.now().millisecondsSinceEpoch.toString();
      final transaction = Transaction(
        id: localId, // id local único
        clientId: _selectedClient!.id,
        userId: widget.userId,
        type: _type!,
        amount: amount,
        description: _descriptionController.text,
        date: _selectedDate,
        createdAt: now,
        localId: localId,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transacción guardada correctamente')),
        );
        Future.delayed(const Duration(milliseconds: 350), () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error inesperado: $e';
        _loading = false;
      });
      print('[GlobalTransactionForm ERROR] Error inesperado: $e');
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
    final clients = context.watch<ClientProvider>().clients;
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = "";
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Título principal (antes subtítulo contextual)
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            'Agregar Transacción para ${_selectedClient?.name ?? ''}',
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
                    (c.email?.toLowerCase().contains(
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
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Buscar o seleccionar cliente',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  );
                },
            onSelected: (Client c) => setState(() => _selectedClient = c),
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: (options.length * 44.0).clamp(44.0, 200.0),
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final Client c = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(c),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name),
                                if (c.email != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1.5),
                                    child: Text(
                                      c.email!,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
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
              color: colorScheme.primary.withOpacity(0.08),
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
        TextField(
          controller: _amountController,
          decoration: InputDecoration(
            labelText: 'Monto',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            onPressed: _loading ? null : _save,
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../providers/transaction_filter_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/client.dart';
import '../providers/client_provider.dart';
import '../utils/currency_utils.dart';
import '../utils/no_scrollbar_behavior.dart';

class TransactionsScreen extends StatefulWidget {
  final String userId;
  final String? initialClientId;
  const TransactionsScreen({
    super.key,
    required this.userId,
    this.initialClientId,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final FocusNode _searchFocusNode = FocusNode();
  String? _selectedClientId;
  DateTimeRange? _selectedRange;
  String? _selectedType; // 'debt', 'payment', o null
  String _searchQuery = '';
  bool _loading = true;
  bool _appliedInitialType = false;

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Si el filtro de cliente está seteado en el provider, úsalo como filtro inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final filterProvider = Provider.of<TransactionFilterProvider>(
        context,
        listen: false,
      );
      if (filterProvider.clientId != null &&
          filterProvider.clientId!.isNotEmpty) {
        setState(() {
          _selectedClientId = filterProvider.clientId;
        });
        // Limpiar el filtro para futuros cambios de tab
        filterProvider.setClientId(null);
      } else {
        setState(() {
          _selectedClientId = widget.initialClientId;
        });
      }
      _loadTransactions();
    });
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    await txProvider.loadTransactions(widget.userId);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CurrencyProvider>();
    final txProvider = Provider.of<TransactionProvider>(context);
    final clientProvider = Provider.of<ClientProvider>(context);
    final filterProvider = Provider.of<TransactionFilterProvider>(context);
    String format(num value) => CurrencyUtils.format(context, value);
    final clients = clientProvider.clients;
    var transactions = txProvider.transactions;

    if (!_appliedInitialType && filterProvider.type != null) {
      _appliedInitialType = true;
      _selectedType = filterProvider.type;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        filterProvider.clear();
        if (!mounted) return;
        setState(() {});
      });
    }

    if (_selectedClientId != null && _selectedClientId!.isNotEmpty) {
      transactions = transactions
          .where((t) => t.clientId == _selectedClientId)
          .toList();
    }
    if (_selectedRange != null) {
      transactions = transactions.where((t) {
        return t.date.isAfter(
              _selectedRange!.start.subtract(const Duration(days: 1)),
            ) &&
            t.date.isBefore(_selectedRange!.end.add(const Duration(days: 1)));
      }).toList();
    }
    if (_selectedType != null && _selectedType!.isNotEmpty) {
      transactions = transactions
          .where((t) => t.type == _selectedType)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      transactions = transactions.where((t) {
        final client = clients.firstWhere(
          (c) => c.id == t.clientId,
          orElse: () => Client(id: '', name: '', balance: 0),
        );
        return t.description.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            client.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // --- CORRECCIÓN DE LAYOUT: SafeArea y padding adaptable ---
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;
    final double topPadding = isMobile ? 24.0 : 70.0;
    final double? maxCardWidth = isMobile ? null : 500.0;

    Widget content;
    GestureDetector gestureWrapper({required Widget child}) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          }
        },
        child: child,
      );
    }

    if (isMobile) {
      // En móvil: igualar el ancho y estilo visual del box de clientes
      content = gestureWrapper(
        child: Column(
          children: [
            // Header y filtros
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 10,
                ),
                child: _buildTransactionColumn(format, clients, transactions),
              ),
            ),
          ],
        ),
      );
    } else {
      // En escritorio: Card centrado y ancho máximo
      content = gestureWrapper(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxCardWidth ?? 500.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 24,
                ),
                child: _buildTransactionColumn(format, clients, transactions),
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE6F0FF),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ScrollConfiguration(
                  behavior: NoScrollbarBehavior(),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(0, topPadding, 0, 24),
                      child: content,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // Layout desacoplado, solo para transacciones
  Widget _buildTransactionColumn(
    String Function(num) format,
    List<Client> clients,
    List transactions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            'Transacciones',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple[400],
            ),
          ),
        ),
        const SizedBox(height: 18),
        // Buscador
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5F7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            focusNode: _searchFocusNode,
            decoration: const InputDecoration(
              hintText: 'Buscar por cliente o descripción...',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Colors.black54),
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
        const SizedBox(height: 18),
        // Filtros horizontales
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: DropdownButtonFormField<String>(
                  value: _selectedClientId,
                  decoration: const InputDecoration(
                    labelText: 'Filtrar por cliente',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ...clients.map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedClientId = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: SizedBox(
                height: 52,
                child: DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todos')),
                    DropdownMenuItem(value: 'debt', child: Text('Deuda')),
                    DropdownMenuItem(value: 'payment', child: Text('Abono')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 52,
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.date_range, color: Colors.black87),
                    onPressed: () async {
                      final picked = await showDialog<DateTimeRange>(
                        context: context,
                        builder: (context) {
                          DateTimeRange tempRange =
                              _selectedRange ??
                              DateTimeRange(
                                start: DateTime.now().subtract(
                                  const Duration(days: 7),
                                ),
                                end: DateTime.now(),
                              );
                          return AlertDialog(
                            title: const Text('Selecciona un rango'),
                            content: SizedBox(
                              width: 320,
                              height: 260, // Más bajo
                              child: CalendarDateRangePicker(
                                initialRange: tempRange,
                                onChanged: (range) {
                                  tempRange = range;
                                },
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(tempRange),
                                child: const Text('Aceptar'),
                              ),
                            ],
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() => _selectedRange = picked);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_selectedRange != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Row(
              children: [
                Text(
                  '${_selectedRange!.start.year}-${_selectedRange!.start.month.toString().padLeft(2, '0')}-${_selectedRange!.start.day.toString().padLeft(2, '0')} - '
                  '${_selectedRange!.end.year}-${_selectedRange!.end.month.toString().padLeft(2, '0')}-${_selectedRange!.end.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => setState(() => _selectedRange = null),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        // Listado de transacciones
        transactions.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'No hay transacciones para mostrar',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                separatorBuilder: (_, __) => SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final t = transactions[i];
                  final client = clients.firstWhere(
                    (c) => c.id == t.clientId,
                    orElse: () => Client(id: '', name: '', balance: 0),
                  );
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            backgroundColor: t.type == 'debt'
                                ? Color(0xFFFFE5E5)
                                : Color(0xFFE5FFE8),
                            radius: 22,
                            child: Icon(
                              t.type == 'debt'
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: t.type == 'debt'
                                  ? Colors.red
                                  : Colors.green,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        t.description,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      format(t.amount),
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Cliente: ${client.name}',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          color: Colors.black54,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 22,
                            ),
                            onPressed: () async {
                              final txProvider =
                                  Provider.of<TransactionProvider>(
                                    context,
                                    listen: false,
                                  );
                              try {
                                await txProvider.deleteTransaction(
                                  t.id,
                                  widget.userId,
                                );
                                if (mounted) setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Transacción eliminada correctamente',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error al eliminar: \\${e.toString()}',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            tooltip: 'Eliminar',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }
}

/// Widget simple para seleccionar un rango de fechas en un calendario pequeño
class CalendarDateRangePicker extends StatefulWidget {
  final DateTimeRange initialRange;
  final ValueChanged<DateTimeRange> onChanged;
  const CalendarDateRangePicker({
    super.key,
    required this.initialRange,
    required this.onChanged,
  });

  @override
  State<CalendarDateRangePicker> createState() =>
      _CalendarDateRangePickerState();
}

class _CalendarDateRangePickerState extends State<CalendarDateRangePicker> {
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialRange.start;
    _end = widget.initialRange.end;
  }

  void _onDaySelected(DateTime day) {
    setState(() {
      if (day.isBefore(_start) || day.isAfter(_end)) {
        _start = day;
        _end = day;
      } else if ((day.difference(_start)).abs() <
          (day.difference(_end)).abs()) {
        _start = day;
      } else {
        _end = day;
      }
      if (_end.isBefore(_start)) {
        final temp = _start;
        _start = _end;
        _end = temp;
      }
      widget.onChanged(DateTimeRange(start: _start, end: _end));
    });
  }

  @override
  Widget build(BuildContext context) {
    return CalendarDatePicker(
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      currentDate: DateTime.now(),
      onDateChanged: _onDaySelected,
      selectableDayPredicate: (_) => true,
    );
  }
}

// (Lógica de calendario únicamente, sin métodos de transacciones)

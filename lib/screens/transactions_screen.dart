import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import '../providers/currency_provider.dart';
import '../providers/transaction_filter_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/client.dart';
import '../providers/client_provider.dart';
import '../providers/sync_provider.dart';
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
  // Elimina el flag para que el filtro de tipo siempre se aplique desde el provider

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
      if (!mounted) return;
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
    // --- Sincroniza el id seleccionado si fue reemplazado (por ejemplo, tras sincronización de clientes offline) ---
    final clientProvider = Provider.of<ClientProvider>(context, listen: false);
    if (_selectedClientId != null && _selectedClientId!.isNotEmpty) {
      final exists = clientProvider.clients.any(
        (c) => c.id == _selectedClientId,
      );
      if (!exists) {
        // Buscar cliente por nombre (asumiendo que el nombre no cambió)
        String? clientName;
        // Buscar la transacción con el id antiguo
        final txList = txProvider.transactions
            .where((t) => t.clientId == _selectedClientId)
            .toList();
        if (txList.isNotEmpty) {
          // Buscar el cliente antiguo en la lista de clientes (por id)
          final oldClientList = clientProvider.clients
              .where((c) => c.id == txList.first.clientId)
              .toList();
          if (oldClientList.isNotEmpty) {
            clientName = oldClientList.first.name;
          }
        }
        // Buscar cliente por nombre
        if (clientName != null) {
          final newClientList = clientProvider.clients
              .where((c) => c.name == clientName)
              .toList();
          if (newClientList.isNotEmpty) {
            setState(() {
              _selectedClientId = newClientList.first.id;
            });
          }
        }
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = context.watch<CurrencyProvider>();
    final txProvider = Provider.of<TransactionProvider>(context);
    final clientProvider = Provider.of<ClientProvider>(context);
    final filterProvider = Provider.of<TransactionFilterProvider>(context);
    String format(num value) {
      final isUSD = currencyProvider.currency == 'USD';
      final rate = currencyProvider.rate > 0 ? currencyProvider.rate : 1.0;
      final converted = isUSD ? value.toDouble() / rate : value.toDouble();
      return isUSD
          ? '\$${converted.toStringAsFixed(2)}'
          : converted.toStringAsFixed(2);
    }

    final clients = clientProvider.clients;
    // Filtra transacciones para no mostrar las marcadas como pendingDelete
    var transactions = txProvider.transactions
        .where((t) => t.pendingDelete != true)
        .toList();

    // Validar que el cliente seleccionado exista en la lista
    final clientIds = clients.map((c) => c.id).toList();
    if (_selectedClientId != null && !clientIds.contains(_selectedClientId)) {
      _selectedClientId = null;
    }

    // Siempre sincroniza el filtro de tipo con el provider si viene de fuera
    if (filterProvider.type != null) {
      _selectedType = filterProvider.type;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        filterProvider.setType(null); // Limpia solo el tipo, no el clientId
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
                  color: const Color.fromARGB(
                    255,
                    255,
                    255,
                    255,
                  ).withValues(alpha: 1 * 255),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(
                        255,
                        255,
                        255,
                        255,
                      ).withValues(alpha: 0.08 * 255),
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
    // --- NUEVO: Detectar si el cliente está pendiente por eliminar y si estamos offline ---
    final clientProvider = Provider.of<ClientProvider>(context, listen: false);
    final syncProvider = Provider.of<SyncProvider?>(context, listen: false);
    bool isOffline = false;
    bool clientPendingDelete = false;
    String? selectedClientId = _selectedClientId;
    if (selectedClientId != null && selectedClientId.isNotEmpty) {
      // Buscar el cliente en Hive si no está en la lista visible
      final client = clientProvider.clients.firstWhere(
        (c) => c.id == selectedClientId,
        orElse: () => Client(id: '', name: '', balance: 0),
      );
      if (client.id.isEmpty) {
        // Buscar en Hive directamente
        try {
          final box = Hive.box('clients');
          final hiveClient = box.get(selectedClientId);
          if (hiveClient != null && hiveClient.pendingDelete == true) {
            clientPendingDelete = true;
          }
        } catch (_) {}
      } else {
        // Lógica adicional: si el cliente tiene UUID y está marcado para eliminar offline
        try {
          final box = Hive.box('clients');
          final hiveClient = box.get(selectedClientId);
          if (hiveClient != null &&
              hiveClient.pendingDelete == true &&
              hiveClient.id is String &&
              hiveClient.id.length == 36) {
            clientPendingDelete = true;
          }
        } catch (_) {}
      }
    }
    // Detectar offline
    // Si hay SyncProvider, úsalo; si no, fallback a TransactionProvider
    if (syncProvider != null) {
      isOffline = !syncProvider.isOnline;
    } else {
      // Fallback: usar TransactionProvider
      // (esto es asíncrono, así que solo para fallback visual, no bloqueante)
      // isOffline = !(await txProvider.isOnline()); // No se puede usar await aquí
    }

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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 4,
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
                  selectedItemBuilder: (context) {
                    return [
                      const Text(
                        'Todos',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      ...clients.map(
                        (c) => Text(
                          c.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ];
                  },
                  onChanged: (value) {
                    setState(() {
                      _selectedClientId = value;
                    });
                  },
                  isExpanded: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 3,
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
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 52,
                child: Center(
                  // Puedes ajustar el padding aquí para subir o bajar el icono
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: 12,
                    ), // <-- Ajusta este valor (ej. 2, 4, 6)
                    child: IconButton(
                      icon: const Icon(Icons.date_range, color: Colors.black87),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.center,
                      onPressed: () async {
                        if (!mounted) return;
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
                        if (!mounted) return;
                        if (picked != null) {
                          setState(() => _selectedRange = picked);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Stats de Abono / Deuda mejorado con iconos y recuadro
        Builder(
          builder: (context) {
            double totalAbono = 0;
            double totalDeuda = 0;
            for (var tx in transactions) {
              if (tx.type == 'payment') {
                totalAbono += tx.amount;
              } else if (tx.type == 'debt') {
                totalDeuda += tx.amount;
              }
            }
            final showAbono =
                _selectedType == null || _selectedType == 'payment';
            final showDeuda = _selectedType == null || _selectedType == 'debt';
            if (!showAbono && !showDeuda) return SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 2.0,
              ), //color de los statscard abono/deuda
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(
                        255,
                        227,
                        227,
                        227,
                      ).withValues(alpha: 0.06 * 255),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: const Color.fromARGB(255, 255, 255, 255),
                    width: 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showAbono)
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.green[100],
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.arrow_upward,
                                    color: Colors.green[700],
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Abono',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              format(totalAbono),
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (showAbono && showDeuda) const SizedBox(width: 18),
                    if (showDeuda)
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red[100],
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.arrow_downward,
                                    color: Colors.red[700],
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Deuda',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              format(totalDeuda),
                              style: TextStyle(
                                color: Colors.red[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
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
                separatorBuilder: (_, __) =>
                    SizedBox(height: 6), // Espacio entre transacciones
                itemBuilder: (context, i) {
                  final t = transactions[i];
                  final client = clients.firstWhere(
                    (c) => c.id == t.clientId,
                    orElse: () => Client(id: '', name: '', balance: 0),
                  );

                  // Si NO está pendiente, usa Dismissible normal
                  return Dismissible(
                    key: ValueKey(t.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 32,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Eliminar transacción'),
                              content: const Text(
                                '¿Estás seguro de eliminar esta transacción?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                    },
                    onDismissed: (direction) async {
                      final txProvider = Provider.of<TransactionProvider>(
                        context,
                        listen: false,
                      );
                      final cp = Provider.of<ClientProvider>(
                        context,
                        listen: false,
                      );
                      final transactionIdToDelete = t.id;
                      final transactionDescription = t.description;

                      txProvider.removeTransactionLocally(
                        transactionIdToDelete,
                      );

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Transacción "$transactionDescription" eliminada. Pendiente de sincronizar.',
                          ),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 2),
                        ),
                      );

                      try {
                        debugPrint(
                          '--- INICIO FLUJO ELIMINACIÓN TRANSACCIÓN ---',
                        );
                        debugPrint(
                          '1. Llamando a markTransactionForDeletionAndSync para $transactionIdToDelete',
                        );
                        await txProvider.markTransactionForDeletionAndSync(
                          transactionIdToDelete,
                          widget.userId,
                        );
                        if (!mounted) return;
                        debugPrint(
                          '2. Llamando a cleanLocalPendingDeletedTransactions',
                        );
                        await txProvider.cleanLocalPendingDeletedTransactions();
                        if (!mounted) return;
                        debugPrint(
                          '3. Refrescando clientes (loadClients y refreshClientsFromHive)',
                        );
                        await cp.loadClients(widget.userId);
                        if (!mounted) return;
                        debugPrint('4. Llamando a refreshClientsFromHive');
                        await cp.refreshClientsFromHive();
                        if (!mounted) return;
                        debugPrint(
                          '5. Transacción marcada para eliminar y sincronizar: $transactionIdToDelete',
                        );
                        debugPrint('--- FIN FLUJO ELIMINACIÓN TRANSACCIÓN ---');
                      } catch (e, stack) {
                        debugPrint(
                          '--- ERROR EN FLUJO ELIMINACIÓN TRANSACCIÓN ---',
                        );
                        debugPrint(
                          'Error al marcar/sincronizar eliminación: $transactionIdToDelete -> \\${e.toString()}',
                        );
                        debugPrint('Stacktrace: \n$stack');
                        debugPrint(
                          '--- FIN ERROR FLUJO ELIMINACIÓN TRANSACCIÓN ---',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error al sincronizar eliminación: [\\${e.toString()}]',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(
                          255,
                          255,
                          255,
                          255,
                        ), // Fondo blanco
                        borderRadius: BorderRadius.circular(
                          16,
                        ), // Bordes redondeados
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(
                              255,
                              11,
                              11,
                              11,
                            ).withOpacity(0.25), // Sombra muy suave
                            blurRadius: 4, // Difuminado de la sombra
                            offset: Offset(0, 2), // Desplazamiento de la sombra
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10, // Espaciado horizontal interno
                          vertical: 3, // Espaciado vertical interno
                        ),
                        // Fila principal con los datos de la transacción
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
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
                                      Spacer(),
                                      Text(
                                        format(t.amount),
                                        style: TextStyle(
                                          color: t.type == 'payment'
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
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
                                          maxLines: 1,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      SizedBox(
                                        width: 90,
                                        child: Text(
                                          '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Colors.black45,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // --- NUEVO: Estado especial para transacciones de cliente pendiente por eliminar en offline ---
                                  if (clientPendingDelete && isOffline)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 2,
                                        bottom: 1,
                                      ),
                                      child: Row(
                                        children: [
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(
                                                0.09,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.delete_forever,
                                                  size: 12,
                                                  color: Colors.red,
                                                ),
                                                SizedBox(width: 2),
                                                Text(
                                                  'Pendiente por eliminar',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.red[800],
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (t.synced == false)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 2,
                                        bottom: 1,
                                      ),
                                      child: Row(
                                        children: [
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(
                                                0.09,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.sync,
                                                  size: 10, // Icono más pequeño
                                                  color: Colors.orange,
                                                ),
                                                SizedBox(
                                                  width: 2,
                                                ), // Menor separación
                                                Text(
                                                  'Pendiente por sincronizar', // Mensaje más corto
                                                  style: TextStyle(
                                                    fontSize:
                                                        9, // Texto más pequeño
                                                    color: Colors.orange[800],
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (t.synced == true)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 2,
                                        bottom: 1,
                                      ),
                                      child: Row(
                                        children: [
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(
                                                0.09,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.cloud_done,
                                                  size: 10, // Icono más pequeño
                                                  color: Colors.green,
                                                ),
                                                SizedBox(
                                                  width: 2,
                                                ), // Menor separación
                                                Text(
                                                  'Sincronizado', // Mensaje más corto
                                                  style: TextStyle(
                                                    fontSize:
                                                        9, // Texto más pequeño
                                                    color: Colors.green[800],
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ), // Cierre del Container principal // cierre del itemBuilder
                  ); // cierre de Dismissible
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

import 'package:flutter/material.dart';
import 'package:flutter_date_pickers/flutter_date_pickers.dart' as dp;
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import '../providers/currency_provider.dart';
import '../providers/transaction_filter_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/client.dart';
import '../providers/client_provider.dart';
import '../providers/sync_provider.dart';
import '../utils/no_scrollbar_behavior.dart';
import '../widgets/transaction_card.dart';
import '../widgets/sync_message_state.dart';
import '../utils/currency_utils.dart';

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
  // Compara códigos de moneda ignorando casing
  bool equalsCurrencyCode(String? a, String? b) {
    if (a == null || b == null) return false;
    return a.toLowerCase() == b.toLowerCase();
  }

  // Guarda el set de monedas conocidas para detectar nuevas
  Set<String> _prevCurrencies = {'USD'};
  // Estado de mensajes de sincronización por transacción
  final Map<String, SyncMessageStateTX> _txSyncStates = {};

  // Permite limpiar el buscador desde fuera usando GlobalKey
  final TextEditingController _searchController = TextEditingController();
  void resetSearchState() {
    if (_searchQuery.isNotEmpty ||
        _searchFocusNode.hasFocus ||
        _searchController.text.isNotEmpty) {
      setState(() {
        _searchQuery = '';
        _searchController.clear();
        _searchFocusNode.unfocus();
      });
    }
  }

  bool _loading = true;
  final FocusNode _searchFocusNode = FocusNode();
  DateTimeRange? _selectedRange;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    debugPrint(
      '[TRANSACTIONS_SCREEN][_loadTransactions] INICIO. userId: \\${widget.userId}',
    );
    setState(() => _loading = true);
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    await txProvider.loadTransactions(widget.userId);
    setState(() => _loading = false);

    // Mostrar mensaje temporal 'Sincronizado' para transacciones que acaban de sincronizarse
    final txs = txProvider.transactions;
    for (final tx in txs) {
      if (tx.synced == true && !_txSyncStates.containsKey(tx.id)) {
        showTransactionSyncMessage(tx.id, SyncMessageStateTX.synced());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = context.watch<CurrencyProvider>();

    // Fallback a USD si la moneda seleccionada ya no está disponible
    if (currencyProvider.currency != 'USD' &&
        !currencyProvider.availableCurrencies.contains(
          currencyProvider.currency,
        )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<CurrencyProvider>().setCurrency('USD');
      });
    }

    // --- Selección automática de nueva moneda ---
    // Normaliza los códigos de moneda para evitar problemas de casing
    final currentCurrencies = Set<String>.from(
      currencyProvider.availableCurrencies.map((c) => c),
    );
    // Excluye USD para la lógica de selección automática
    final prevNoUsd = _prevCurrencies.where((c) => c != 'USD').toSet();
    final currNoUsd = currentCurrencies.where((c) => c != 'USD').toSet();
    final newCurrencies = currNoUsd.difference(prevNoUsd);
    if (newCurrencies.isNotEmpty) {
      final lastNew = newCurrencies.last;
      // Compara ignorando casing para robustez
      if (!equalsCurrencyCode(currencyProvider.currency, lastNew)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<CurrencyProvider>().setCurrency(lastNew);
        });
      }
    }

    // Actualiza el set de monedas conocidas
    _prevCurrencies = currentCurrencies;

    final txProvider = Provider.of<TransactionProvider>(context);
    final clientProvider = Provider.of<ClientProvider>(context);
    final filterProvider = Provider.of<TransactionFilterProvider>(context);

    /// Formatea el valor mostrado según la moneda seleccionada.
    /// - Si la moneda seleccionada es USD, muestra el valor en USD (anchorUsdValue).
    /// - Si es otra moneda, muestra el valor convertido multiplicando por la tasa registrada.
    /// - El valor almacenado en anchorUsdValue SIEMPRE está en USD.
    /// - El label visual debe indicar la moneda mostrada.
    String format(dynamic transactionOrValue) {
      final selectedCurrency = currencyProvider.currency;
      final rateForSelected =
          currencyProvider.getRateFor(selectedCurrency) ?? 1.0;

      // Si es un número crudo, convertir usando la tasa actual
      if (transactionOrValue is num) {
        if (selectedCurrency == 'USD') {
          return 'USD ${transactionOrValue.toStringAsFixed(2)}';
        } else {
          final converted = transactionOrValue.toDouble() * rateForSelected;
          return '$selectedCurrency ${converted.toStringAsFixed(2)}';
        }
      }

      if (transactionOrValue != null) {
        // Espera un objeto tipo transacción con amount, currencyCode y anchorUsdValue
        final tx = transactionOrValue;
        double anchorUsd;
        if (tx.anchorUsdValue != null) {
          anchorUsd = tx.anchorUsdValue;
        } else if (tx.amount != null &&
            tx.originalRate != null &&
            tx.originalRate > 0) {
          // Si existe la tasa original usada al crear la transacción
          anchorUsd = tx.amount / tx.originalRate;
        } else if (tx.amount != null) {
          // Fallback: mostrar el monto original si no hay tasa
          anchorUsd = tx.amount;
        } else {
          anchorUsd = 0.0;
        }

        if (selectedCurrency == 'USD') {
          return 'USD ${anchorUsd.toStringAsFixed(2)}';
        } else {
          final converted = anchorUsd * rateForSelected;
          return '$selectedCurrency ${converted.toStringAsFixed(2)}';
        }
      }

      return '';
    }

    final clients = clientProvider.clients;
    var transactions = txProvider.transactions
        .where((t) => t.pendingDelete != true)
        .toList();

    final selectedClientId = filterProvider.clientId;
    final selectedType = filterProvider.type;

    final clientIds = clients.map((c) => c.id).toList();
    final effectiveClientId =
        (selectedClientId != null && clientIds.contains(selectedClientId))
        ? selectedClientId
        : null;

    debugPrint(
      '[TRANSACTIONS_SCREEN][build] selectedClientId: $selectedClientId, effectiveClientId: $effectiveClientId, selectedType: $selectedType, transactions: ${transactions.length}',
    );

    if (effectiveClientId != null && effectiveClientId.isNotEmpty) {
      transactions = transactions
          .where((t) => t.clientId == effectiveClientId)
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
    if (selectedType != null && selectedType.isNotEmpty) {
      transactions = transactions.where((t) => t.type == selectedType).toList();
    }
    if (_searchQuery.isNotEmpty) {
      transactions = transactions.where((t) {
        final client = clients.firstWhere(
          (c) => c.id == t.clientId,
          orElse: () => Client(id: '', name: '', balance: 0),
        );
        final clientName = client.name;
        return t.description.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            clientName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Asegurar orden: transacciones más nuevas primero (fecha desc, si empatan usar createdAt)
    transactions.sort((a, b) {
      final dateCmp = b.date.compareTo(a.date);
      if (dateCmp != 0) return dateCmp;
      return b.createdAt.compareTo(a.createdAt);
    });

    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;
    final double topPadding = isMobile ? 24.0 : 70.0;
    final double? maxCardWidth = isMobile ? null : 500.0;

    // Refactor: Layout fijo arriba, lista virtualizada abajo
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
        }
      },
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ScrollConfiguration(
              behavior: const NoScrollbarBehavior(),
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, topPadding, 0, 1),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxCardWidth ?? 500.0,
                    ),
                    child: Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 28,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Filtros, chips y stats
                            _buildTransactionFilters(
                              context,
                              clients,
                              format,
                              effectiveClientId,
                              selectedType,
                            ),
                            // Lista virtualizada
                            Expanded(
                              child: transactions.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          'No hay transacciones para mostrar',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.only(
                                        top: 6,
                                        bottom: 20,
                                      ),
                                      itemCount: transactions.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 5),
                                      itemBuilder: (context, i) {
                                        final t = transactions[i];
                                        final client = clients.firstWhere(
                                          (c) => c.id == t.clientId,
                                          orElse: () => Client(
                                            id: '',
                                            name: '',
                                            balance: 0,
                                          ),
                                        );
                                        final currencyProvider =
                                            Provider.of<CurrencyProvider>(
                                              context,
                                              listen: false,
                                            );
                                        SyncMessageStateTX? syncMsg =
                                            _txSyncStates[t.id];
                                        bool clientPendingDelete = false;
                                        // Deshabilitado: provider local no usado (dejado como referencia por si se necesita en el futuro)
                                        // final clientProvider =
                                        //     Provider.of<ClientProvider>(
                                        //       context,
                                        //       listen: false,
                                        //     );
                                        if (client.id.isEmpty) {
                                          try {
                                            final box = Hive.box('clients');
                                            final hiveClient = box.get(
                                              t.clientId,
                                            );
                                            if (hiveClient != null &&
                                                hiveClient.pendingDelete ==
                                                    true) {
                                              clientPendingDelete = true;
                                            }
                                          } catch (_) {}
                                        } else {
                                          try {
                                            final box = Hive.box('clients');
                                            final hiveClient = box.get(
                                              t.clientId,
                                            );
                                            if (hiveClient != null &&
                                                hiveClient.pendingDelete ==
                                                    true &&
                                                hiveClient.id is String &&
                                                hiveClient.id.length == 36) {
                                              clientPendingDelete = true;
                                            }
                                          } catch (_) {}
                                        }
                                        final syncProvider =
                                            Provider.of<SyncProvider?>(
                                              context,
                                              listen: false,
                                            );
                                        bool isOffline = false;
                                        if (syncProvider != null) {
                                          isOffline = !syncProvider.isOnline;
                                        }
                                        return Dismissible(
                                          key: ValueKey(t.id),
                                          direction:
                                              DismissDirection.endToStart,
                                          background: Container(
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withAlpha(
                                                (0.12 * 255).toInt(),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
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
                                                  builder: (dialogContext) =>
                                                      AlertDialog(
                                                        title: const Text(
                                                          'Eliminar transacción',
                                                        ),
                                                        content: const Text(
                                                          '¿Estás seguro de eliminar esta transacción?',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  dialogContext,
                                                                ).pop(false),
                                                            child: const Text(
                                                              'Cancelar',
                                                            ),
                                                          ),
                                                          ElevatedButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  dialogContext,
                                                                ).pop(true),
                                                            child: const Text(
                                                              'Eliminar',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                ) ??
                                                false;
                                          },
                                          onDismissed: (direction) async {
                                            final txProvider =
                                                Provider.of<
                                                  TransactionProvider
                                                >(context, listen: false);
                                            final cp =
                                                Provider.of<ClientProvider>(
                                                  context,
                                                  listen: false,
                                                );
                                            final transactionIdToDelete = t.id;
                                            final transactionDescription =
                                                t.description;
                                            txProvider.removeTransactionLocally(
                                              transactionIdToDelete,
                                            );
                                            if (!mounted) return;
                                            final messenger =
                                                ScaffoldMessenger.maybeOf(
                                                  context,
                                                );
                                            messenger?.showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Transacción "$transactionDescription" eliminada. Pendiente de sincronizar.',
                                                ),
                                                backgroundColor: Colors.orange,
                                                duration: const Duration(
                                                  seconds: 2,
                                                ),
                                              ),
                                            );
                                            try {
                                              await txProvider
                                                  .markTransactionForDeletionAndSync(
                                                    transactionIdToDelete,
                                                    widget.userId,
                                                  );
                                              if (!mounted) return;
                                              await txProvider
                                                  .cleanLocalPendingDeletedTransactions();
                                              if (!mounted) return;
                                              await cp.loadClients(
                                                widget.userId,
                                              );
                                              if (!mounted) return;
                                              await cp.refreshClientsFromHive();
                                            } catch (e, stack) {
                                              debugPrint(
                                                'Error al marcar/sincronizar eliminación: $transactionIdToDelete -> \\${e.toString()}',
                                              );
                                              debugPrint(
                                                'Stacktrace: \n$stack',
                                              );
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  // ignore: use_build_context_synchronously
                                                  context,
                                                ).showSnackBar(
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
                                          child: TransactionCard(
                                            transaction: t,
                                            client: client,
                                            format: format,
                                            clientPendingDelete:
                                                clientPendingDelete,
                                            isOffline: isOffline,
                                            availableCurrencies:
                                                currencyProvider
                                                    .availableCurrencies,
                                            exchangeRates:
                                                currencyProvider.exchangeRates,
                                            selectedCurrency:
                                                currencyProvider.currency,
                                            onCurrencySelected: (currency) {
                                              currencyProvider.setCurrency(
                                                currency,
                                              );
                                            },
                                            syncMessage: syncMsg,
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  void showTransactionSyncMessage(
    String txId,
    SyncMessageStateTX message, {
    int durationSeconds = 3,
  }) {
    setState(() {
      _txSyncStates[txId] = message;
    });
    Future.delayed(Duration(seconds: durationSeconds), () {
      if (mounted) {
        setState(() {
          _txSyncStates.remove(txId);
        });
      }
    });
  }

  // Nuevo: Widget para filtros, chips y stats fijos arriba
  Widget _buildTransactionFilters(
    BuildContext context,
    List<Client> clients,
    String Function(dynamic) format,
    String? selectedClientId,
    String? selectedType,
  ) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final allTransactions = Provider.of<TransactionProvider>(
      context,
    ).transactions.where((t) => t.pendingDelete != true).toList();
    // Ordenar igual que en la lista
    allTransactions.sort((a, b) {
      final dateCmp = b.date.compareTo(a.date);
      if (dateCmp != 0) return dateCmp;
      return b.createdAt.compareTo(a.createdAt);
    });
    // Filtrar por cliente si hay uno seleccionado
    final filteredTransactions =
        (selectedClientId != null && selectedClientId.isNotEmpty)
        ? allTransactions.where((t) => t.clientId == selectedClientId).toList()
        : allTransactions;
    // --- INICIO PATCH: Stat Deuda muestra deuda real (saldos negativos) ---
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
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5F7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _searchController,
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
        const SizedBox(height: 15),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 52,
                child: Consumer<TransactionFilterProvider>(
                  builder: (context, filterProvider, _) =>
                      DropdownButtonFormField<String>(
                        value: selectedClientId,
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
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todos'),
                          ),
                          ...clients.map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
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
                          filterProvider.setClientId(value);
                        },
                        isExpanded: true,
                        menuMaxHeight: 250,
                      ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 52,
                child: Consumer<TransactionFilterProvider>(
                  builder: (context, filterProvider, _) =>
                      DropdownButtonFormField<String>(
                        value: selectedType,
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
                          DropdownMenuItem(
                            value: 'payment',
                            child: Text('Abono'),
                          ),
                        ],
                        onChanged: (value) {
                          filterProvider.setType(value);
                        },
                      ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 52,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
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
                                height: 260,
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
        const SizedBox(height: 0),
        // Chips de monedas justo debajo de la fila de filtros
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('USD'),
                  selected: currencyProvider.currency == 'USD',
                  onSelected: (selected) {
                    if (!selected) return;
                    currencyProvider.setCurrency('USD');
                  },
                  selectedColor: Colors.blue.shade100,
                  backgroundColor: Colors.grey.shade200,
                  labelStyle: TextStyle(
                    color: currencyProvider.currency == 'USD'
                        ? Colors.blue
                        : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...currencyProvider.availableCurrencies
                  .where((currency) => currency != 'USD')
                  .map((currency) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(currency),
                        selected: equalsCurrencyCode(
                          currencyProvider.currency,
                          currency,
                        ),
                        onSelected: (selected) {
                          if (!selected) return;
                          currencyProvider.setCurrency(currency);
                        },
                        selectedColor: Colors.blue.shade100,
                        backgroundColor: Colors.grey.shade200,
                        labelStyle: TextStyle(
                          color:
                              equalsCurrencyCode(
                                currencyProvider.currency,
                                currency,
                              )
                              ? Colors.blue
                              : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Estadísticas
        Builder(
          builder: (context) {
            final selectedCurrency = currencyProvider.currency;
            final rateForSelected =
                currencyProvider.getRateFor(selectedCurrency) ?? 1.0;

            // --- Calcular balances por cliente en USD (para lógica interna) ---
            final rateToSelected = selectedCurrency == 'USD'
                ? 1.0
                : (currencyProvider.getRateFor(selectedCurrency) ?? 1.0);
            double displayAbono = 0.0;
            double displayDeuda = 0.0;
            for (var tx in filteredTransactions) {
              final anchor = tx.anchorUsdValue ?? 0.0;
              if (tx.type == 'payment') {
                displayAbono += anchor;
              } else if (tx.type == 'debt') {
                displayDeuda += anchor;
              }
            }
            displayAbono *= rateToSelected;
            displayDeuda *= rateToSelected;
            final showAbono = selectedType == null || selectedType == 'payment';
            final showDeuda = selectedType == null || selectedType == 'debt';
            if (!showAbono && !showDeuda) return const SizedBox.shrink();

            // --- NUEVO: Mostrar mensaje de balance del cliente si hay cliente filtrado ---
            Widget? clientBalanceMessage;
            if (selectedClientId != null && selectedClientId.isNotEmpty) {
              // Calcular balance neto del cliente filtrado (en USD, convertir a moneda seleccionada)
              double clientBalance = 0.0;
              for (var tx in filteredTransactions) {
                final anchor = tx.anchorUsdValue ?? 0.0;
                if (tx.type == 'payment') {
                  clientBalance += anchor;
                } else if (tx.type == 'debt') {
                  clientBalance -= anchor;
                }
              }
              final clientBalanceDisplay = clientBalance * rateToSelected;
              String label;
              Color color;
              if (clientBalanceDisplay < -0.009) {
                label = 'Deuda del cliente';
                color = Colors.red[700]!;
              } else if (clientBalanceDisplay > 0.009) {
                label = 'Saldo a favor del cliente';
                color = Colors.green[700]!;
              } else {
                label = 'Sin movimientos';
                color = Colors.black87;
              }
              clientBalanceMessage = Padding(
                padding: const EdgeInsets.only(top: 10.0, bottom: 2.0),
                child: Column(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (label != 'Sin movimientos')
                      Text(
                        CurrencyUtils.formatNumber(clientBalanceDisplay),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                  ],
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(),
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
                      ).withAlpha((0.06 * 255).toInt()),
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
                  vertical: 4,
                  horizontal: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
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
                                  CurrencyUtils.formatNumber(displayAbono),
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
                                  CurrencyUtils.formatNumber(displayDeuda),
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
                    if (clientBalanceMessage != null) clientBalanceMessage,
                    if (_selectedRange != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_selectedRange!.start.year}-${_selectedRange!.start.month.toString().padLeft(2, '0')}-${_selectedRange!.start.day.toString().padLeft(2, '0')} - '
                              '${_selectedRange!.end.year}-${_selectedRange!.end.month.toString().padLeft(2, '0')}-${_selectedRange!.end.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  setState(() => _selectedRange = null),
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
      ],
    );
    // --- FIN PATCH ---
  }

  // Ejemplo de función para agregar una transacción
  Future<void> addTransaction(dynamic tx) async {
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final syncProvider = Provider.of<SyncProvider?>(context, listen: false);
    final isOffline = syncProvider != null ? !syncProvider.isOnline : false;
    String? tempId = tx.id;

    // --- CAMBIO 1: Mostrar mensaje "Sincronizando" ---
    // Se muestra el mensaje ANTES de la operación asíncrona.
    if (!isOffline && tempId != null) {
      setState(() {
        _txSyncStates[tempId] = SyncMessageStateTX.syncing();
      });
    }

    // --- CAMBIO 2: Ejecutar addTransaction y forzar reconstrucción ---
    // Se agrega la transacción y se llama a setState para que la UI se actualice
    // y muestre la nueva transacción con su mensaje "Sincronizando".
    await txProvider.addTransaction(tx, widget.userId, tx.clientId);
    if (mounted) {
      setState(() {});
    }

    // --- CAMBIO 3: Lógica post-sincronización ---
    // El resto del código busca el ID real y actualiza el mensaje a "Sincronizado".
    // Esta parte ya era correcta.
    String? realId;
    final txs = txProvider.transactions;
    if (txs.isNotEmpty) {
      realId = txs
          .firstWhere(
            (t) =>
                t.amount == tx.amount &&
                t.clientId == tx.clientId &&
                t.date == tx.date,
            orElse: () =>
                tx, // Fallback a la transacción original si no se encuentra
          )
          .id;
    }

    final syncId = realId ?? tempId;
    final isUUID = syncId != null && syncId.length == 36;

    if (!isOffline && isUUID) {
      if (mounted) {
        setState(() {
          if (tempId != null && tempId != syncId) {
            _txSyncStates.remove(tempId);
          }
          _txSyncStates[syncId] = SyncMessageStateTX.synced();
        });
      }

      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          _txSyncStates.remove(syncId);
        });
      }
    } else if (!isOffline) {
      if (mounted) {
        setState(() {
          if (tempId != null) _txSyncStates.remove(tempId);
        });
      }
    }
  }
}

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

  @override
  Widget build(BuildContext context) {
    return dp.RangePicker(
      selectedPeriod: dp.DatePeriod(_start, _end),
      onChanged: (dp.DatePeriod period) {
        setState(() {
          _start = period.start;
          _end = period.end;
        });
        widget.onChanged(DateTimeRange(start: _start, end: _end));
      },
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      datePickerStyles: dp.DatePickerRangeStyles(
        selectedPeriodLastDecoration: BoxDecoration(
          color: Colors.deepPurple[200],
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(10.0),
            bottomRight: Radius.circular(10.0),
          ),
        ),
        selectedPeriodStartDecoration: BoxDecoration(
          color: Colors.deepPurple[200],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10.0),
            bottomLeft: Radius.circular(10.0),
          ),
        ),
        selectedPeriodMiddleDecoration: BoxDecoration(
          color: Colors.deepPurple[100],
          shape: BoxShape.rectangle,
        ),
      ),
    );
  }
}

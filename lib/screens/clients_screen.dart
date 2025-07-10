import '../providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/client_provider.dart';
import '../providers/tab_provider.dart';
import '../providers/transaction_filter_provider.dart';
// import 'transactions_screen.dart';
// import 'receipt_screen.dart';
import '../models/client.dart';
// import '../models/transaction.dart';
import '../widgets/client_form.dart';
import '../widgets/transaction_form.dart';
import '../widgets/client_card.dart';
// import '../widgets/currency_toggle.dart';
import '../widgets/general_receipt_modal.dart';

class ClientsScreen extends StatefulWidget {
  final String userId;
  const ClientsScreen({super.key, required this.userId});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  bool _showSearch = false;
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  // Eliminado _editingClient y _transactionClient porque no son necesarios

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ClientProvider>(context, listen: false);
      provider.loadClients(widget.userId);
    });
  }

  void _showClientForm([Client? client]) {
    // _editingClient eliminado, no es necesario setearlo
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ClientForm(
          initialClient: client,
          userId: widget.userId,
          onSave: (newClient) async {
            final provider = Provider.of<ClientProvider>(
              context,
              listen: false,
            );
            if (client == null) {
              await provider.addClient(newClient, widget.userId);
            } else {
              await provider.updateClient(
                Client(
                  id: client.id,
                  name: newClient.name,
                  email: newClient.email,
                  phone: newClient.phone,
                  balance: client.balance, // No permitir editar balance
                ),
                widget.userId,
              );
            }
            await provider.loadClients(widget.userId);
          },
          readOnlyBalance:
              client != null, // Si es edición, no permitir editar balance
        ),
      ),
    );
  }

  void _showTransactionForm(Client client) async {
    final isMobile =
        Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;
    if (isMobile) {
      // Usar showModalBottomSheet para móviles
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints.maxHeight * 0.95;
              return DraggableScrollableSheet(
                initialChildSize: 0.85,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Agregar Transacción para ${client.name}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                            TransactionForm(
                              clientId: client.id,
                              userId: widget.userId,
                              onSave: (tx) async {
                                final txProvider =
                                    Provider.of<TransactionProvider>(
                                      context,
                                      listen: false,
                                    );
                                await txProvider.addTransaction(
                                  tx,
                                  widget.userId,
                                  client.id,
                                );
                                // Actualizar balance del cliente
                                final clientProvider =
                                    Provider.of<ClientProvider>(
                                      context,
                                      listen: false,
                                    );
                                double newBalance = client.balance;
                                if (tx.type == 'debt') {
                                  newBalance -= tx.amount;
                                } else if (tx.type == 'payment') {
                                  newBalance += tx.amount;
                                }
                                await clientProvider.updateClient(
                                  Client(
                                    id: client.id,
                                    name: client.name,
                                    email: client.email,
                                    phone: client.phone,
                                    balance: newBalance,
                                  ),
                                  widget.userId,
                                );
                                Navigator.of(context).pop();
                                await clientProvider.loadClients(widget.userId);
                              },
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
        },
      );
      return;
    }
    // En escritorio/tablet mostrar como modal dialog
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 350,
                maxWidth: 480,
                maxHeight: 600,
              ),
              child: Material(
                color: Colors.transparent,
                child: TransactionForm(
                  clientId: client.id,
                  userId: widget.userId,
                  onSave: (tx) async {
                    final txProvider = Provider.of<TransactionProvider>(
                      context,
                      listen: false,
                    );
                    await txProvider.addTransaction(
                      tx,
                      widget.userId,
                      client.id,
                    );
                    // Actualizar balance del cliente
                    final clientProvider = Provider.of<ClientProvider>(
                      context,
                      listen: false,
                    );
                    double newBalance = client.balance;
                    if (tx.type == 'debt') {
                      newBalance -= tx.amount;
                    } else if (tx.type == 'payment') {
                      newBalance += tx.amount;
                    }
                    await clientProvider.updateClient(
                      Client(
                        id: client.id,
                        name: client.name,
                        email: client.email,
                        phone: client.phone,
                        balance: newBalance,
                      ),
                      widget.userId,
                    );
                    Navigator.of(context).pop();
                    await clientProvider.loadClients(widget.userId);
                  },
                  onClose: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteClient(Client client) async {
    final provider = Provider.of<ClientProvider>(context, listen: false);
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    // Buscar si el cliente tiene transacciones asociadas
    final userTransactions = txProvider.transactions
        .where((tx) => tx.clientId == client.id)
        .toList();
    String warning = '';
    if (userTransactions.isNotEmpty) {
      warning =
          '\n\nADVERTENCIA: Este cliente tiene ${userTransactions.length} transacción(es) asociada(s). Se eliminarán TODAS las transacciones de este cliente.';
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar Cliente'),
        content: Text('¿Estás seguro de eliminar a ${client.name}?$warning'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await provider.deleteClient(client.id, widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClientProvider>(
      builder: (context, provider, child) {
        final allClients = provider.clients;
        final isMobile =
            Theme.of(context).platform == TargetPlatform.android ||
            Theme.of(context).platform == TargetPlatform.iOS;
        final screenWidth = MediaQuery.of(context).size.width;
        final cardMaxWidth = isMobile
            ? (screenWidth - 8).clamp(0.0, 900.0)
            : 700.0;

        // Filtrado en vivo
        final clients = _showSearch && _searchText.isNotEmpty
            ? allClients
                  .where(
                    (c) => c.name.toLowerCase().contains(
                      _searchText.toLowerCase(),
                    ),
                  )
                  .toList()
            : allClients;

        return Scaffold(
          backgroundColor: const Color(0xFFE6F0FF),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (_showSearch) {
                FocusScope.of(context).unfocus();
                setState(() {
                  _showSearch = false;
                  _searchText = '';
                  _searchController.clear();
                });
              }
            },
            child: Center(
              child: ScrollConfiguration(
                behavior: const _TransparentScrollbarBehavior(),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 4.0 : 8.0,
                      vertical: 8.0,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: cardMaxWidth),
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Clientes registrados',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF7C3AED),
                                      fontSize: 28,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              // Botones de acción: Recibo general, Registrar cliente, Buscar cliente (solo icono)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (allClients.isEmpty) ...[
                                    FloatingActionButton(
                                      heroTag: 'registrarCliente',
                                      mini: true,
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      onPressed: () => _showClientForm(),
                                      tooltip: 'Registrar Cliente',
                                      child: const Icon(Icons.add),
                                    ),
                                  ] else ...[
                                    FloatingActionButton(
                                      heroTag: 'reciboGeneral',
                                      mini: true,
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      onPressed: () {
                                        final txProvider =
                                            Provider.of<TransactionProvider>(
                                              context,
                                              listen: false,
                                            );
                                        final clientData = allClients
                                            .map(
                                              (c) => {
                                                'client': c,
                                                'transactions': txProvider
                                                    .transactions
                                                    .where(
                                                      (tx) =>
                                                          tx.clientId == c.id,
                                                    )
                                                    .toList(),
                                              },
                                            )
                                            .toList();
                                        showDialog(
                                          context: context,
                                          builder: (_) => GeneralReceiptModal(
                                            clientData: clientData,
                                          ),
                                        );
                                      },
                                      tooltip: 'Recibo general',
                                      child: const Icon(Icons.receipt_long),
                                    ),
                                    const SizedBox(width: 12),
                                    FloatingActionButton(
                                      heroTag: 'registrarCliente',
                                      mini: true,
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      onPressed: () => _showClientForm(),
                                      tooltip: 'Registrar Cliente',
                                      child: const Icon(Icons.add),
                                    ),
                                    const SizedBox(width: 12),
                                    // Botón buscar cliente solo icono
                                    FloatingActionButton(
                                      heroTag: 'buscarCliente',
                                      mini: true,
                                      backgroundColor: const Color(0xFF7C3AED),
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      onPressed: () {
                                        setState(() {
                                          _showSearch = !_showSearch;
                                          if (!_showSearch) {
                                            _searchText = '';
                                            _searchController.clear();
                                          }
                                        });
                                      },
                                      tooltip: _showSearch
                                          ? 'Ocultar buscador'
                                          : 'Buscar cliente',
                                      child: const Icon(Icons.search),
                                    ),
                                  ],
                                ],
                              ),
                              // Mostrar buscador solo si hay clientes y _showSearch está activo
                              if (_showSearch && allClients.isNotEmpty)
                                GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: () {
                                    // Oculta el buscador si se hace tap fuera
                                    FocusScope.of(context).unfocus();
                                    setState(() {
                                      _showSearch = false;
                                      _searchText = '';
                                      _searchController.clear();
                                    });
                                  },
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 12),
                                      GestureDetector(
                                        onTap:
                                            () {}, // Evita que el tap en el TextField cierre el buscador
                                        child: TextField(
                                          controller: _searchController,
                                          autofocus: true,
                                          decoration: InputDecoration(
                                            hintText: 'Buscar por nombre...',
                                            prefixIcon: const Icon(
                                              Icons.search,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 0,
                                                ),
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              _searchText = value;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 16),
                              clients.isEmpty
                                  ? const Center(
                                      child: Text('No hay clientes.'),
                                    )
                                  : ScrollConfiguration(
                                      behavior: const _NoScrollbarBehavior(),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: clients.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 10),
                                        itemBuilder: (context, index) {
                                          final client = clients[index];
                                          return Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.03),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: ClientCard(
                                              client: client,
                                              onEdit: () =>
                                                  _showClientForm(client),
                                              onDelete: () =>
                                                  _deleteClient(client),
                                              onAddTransaction: () =>
                                                  _showTransactionForm(client),
                                              onViewMovements: () {
                                                Provider.of<TabProvider>(
                                                  context,
                                                  listen: false,
                                                ).setTab(2);
                                                Provider.of<
                                                      TransactionFilterProvider
                                                    >(context, listen: false)
                                                    .setClientId(client.id);
                                              },
                                              onReceipt: () {
                                                final txProvider =
                                                    Provider.of<
                                                      TransactionProvider
                                                    >(context, listen: false);
                                                final clientData = [
                                                  {
                                                    'client': client,
                                                    'transactions': txProvider
                                                        .transactions
                                                        .where(
                                                          (tx) =>
                                                              tx.clientId ==
                                                              client.id,
                                                        )
                                                        .toList(),
                                                  },
                                                ];
                                                showDialog(
                                                  context: context,
                                                  builder: (_) =>
                                                      GeneralReceiptModal(
                                                        clientData: clientData,
                                                      ),
                                                );
                                              },
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
            ),
          ),
        );
      },
    );
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _TransparentScrollbarBehavior extends ScrollBehavior {
  const _TransparentScrollbarBehavior();
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Oculta el scrollbar visualmente, pero permite el scroll
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: false,
      thickness: 0.0,
      child: child,
    );
  }
}

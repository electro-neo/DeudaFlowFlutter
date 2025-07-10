// --- INICIO: Código restaurado del último commit y ajustado para layout independiente ---
import '../providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/client_provider.dart';
import '../models/client.dart';
import '../widgets/client_form.dart';
import '../widgets/client_card.dart';
import '../widgets/general_receipt_modal.dart';
import '../widgets/transaction_form.dart';

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

  // Método para mostrar el formulario de transacción
  void _showTransactionForm(Client client) async {
    final isMobile =
        Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;
    if (isMobile) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final viewInsets = MediaQuery.of(context).viewInsets;
              final maxHeight = constraints.maxHeight * 0.95;
              return DraggableScrollableSheet(
                initialChildSize: 0.85,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (context, scrollController) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: viewInsets.bottom),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
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
                                  await clientProvider.loadClients(
                                    widget.userId,
                                  );
                                },
                                onClose: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
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
    // Desktop/tablet: mostrar como modal dialog
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ClientProvider>(context, listen: false);
      provider.loadClients(widget.userId);
    });
  }

  void _showClientForm([Client? client]) {
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
                  balance: client.balance,
                ),
                widget.userId,
              );
            }
            await provider.loadClients(widget.userId);
          },
          readOnlyBalance: client != null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClientProvider>(
      builder: (context, provider, child) {
        final allClients = provider.clients;
        final txProvider = Provider.of<TransactionProvider>(
          context,
          listen: false,
        );
        final clients = _showSearch && _searchText.isNotEmpty
            ? allClients
                  .where(
                    (c) => c.name.toLowerCase().contains(
                      _searchText.toLowerCase(),
                    ),
                  )
                  .toList()
            : allClients;
        final clientsWithBalance = clients.map((client) {
          final hasTransactions = txProvider.transactions.any(
            (tx) => tx.clientId == client.id,
          );
          if (!hasTransactions) {
            return Client(
              id: client.id,
              name: client.name,
              email: client.email,
              phone: client.phone,
              balance: 0,
            );
          }
          return client;
        }).toList();

        // --- LAYOUT INDEPENDIENTE Y MODERNO ---
        return Scaffold(
          backgroundColor: const Color(0xFFE6F0FF),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
                  child: Column(
                    children: [
                      Container(
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
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
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
                                if (allClients.isNotEmpty)
                                  FloatingActionButton(
                                    heroTag: 'reciboGeneral',
                                    mini: true,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    onPressed: () {
                                      final clientData = allClients
                                          .map(
                                            (c) => {
                                              'client': c,
                                              'transactions': txProvider
                                                  .transactions
                                                  .where(
                                                    (tx) => tx.clientId == c.id,
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
                                if (allClients.isNotEmpty)
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
                                      if (!_showSearch &&
                                          allClients.isNotEmpty) {
                                        FocusScope.of(context).unfocus();
                                      }
                                    },
                                    tooltip: _showSearch
                                        ? 'Ocultar buscador'
                                        : 'Buscar cliente',
                                    child: const Icon(Icons.search),
                                  ),
                              ],
                            ),
                            if (_showSearch && allClients.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 14.0),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeInOut,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F6FD),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _searchText.isNotEmpty
                                          ? const Color(0xFF7C3AED)
                                          : Colors.black,
                                      width: 2.2,
                                    ),
                                    boxShadow: _searchText.isNotEmpty
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF7C3AED,
                                              ).withOpacity(0.18),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    style: const TextStyle(color: Colors.black),
                                    cursorColor: Colors.black,
                                    enableInteractiveSelection: false,
                                    decoration: const InputDecoration(
                                      hintText: 'Buscar por nombre...',
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: Color(0xFF7C3AED),
                                      ),
                                      border: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 14,
                                      ),
                                      fillColor: Color(0xFFF3F6FD),
                                      filled: true,
                                      hoverColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      iconColor: Color(0xFF7C3AED),
                                      prefixIconColor: Color(0xFF7C3AED),
                                      suffixIconColor: Colors.black,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _searchText = value;
                                      });
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.80),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: clientsWithBalance.isEmpty
                          ? const Center(child: Text('No hay clientes.'))
                          : ScrollConfiguration(
                              behavior: const _NoScrollbarBehavior(),
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                itemCount: clientsWithBalance.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final client = clientsWithBalance[index];
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.03,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: ClientCard(
                                            client: client,
                                            onEdit: () =>
                                                _showClientForm(client),
                                            onDelete: () async {
                                              final provider =
                                                  Provider.of<ClientProvider>(
                                                    context,
                                                    listen: false,
                                                  );
                                              final txProvider =
                                                  Provider.of<
                                                    TransactionProvider
                                                  >(context, listen: false);
                                              final userTransactions =
                                                  txProvider.transactions
                                                      .where(
                                                        (tx) =>
                                                            tx.clientId ==
                                                            client.id,
                                                      )
                                                      .toList();
                                              String warning = '';
                                              if (userTransactions.isNotEmpty) {
                                                warning =
                                                    '\n\nADVERTENCIA: Este cliente tiene ${userTransactions.length} transacción(es) asociada(s). Se eliminarán TODAS las transacciones de este cliente.';
                                              }
                                              final confirm =
                                                  await showDialog<bool>(
                                                    context: context,
                                                    builder: (_) => AlertDialog(
                                                      title: const Text(
                                                        'Eliminar Cliente',
                                                      ),
                                                      content: Text(
                                                        '¿Estás seguro de eliminar a ${client.name}?$warning',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                context,
                                                              ).pop(false),
                                                          child: const Text(
                                                            'Cancelar',
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                context,
                                                              ).pop(true),
                                                          child: const Text(
                                                            'Eliminar',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                              if (confirm == true) {
                                                await provider.deleteClient(
                                                  client.id,
                                                  widget.userId,
                                                );
                                              }
                                            },
                                            onAddTransaction: () =>
                                                _showTransactionForm(client),
                                            onViewMovements:
                                                null, // Puedes implementar si lo necesitas
                                            onReceipt: () {
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
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                    ),
                  ),
                ),
              ],
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

// --- FIN: Layout desacoplado e independiente para pantalla de clientes ---

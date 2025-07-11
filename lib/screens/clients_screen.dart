// --- INICIO: Código restaurado del último commit y ajustado para layout independiente ---

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/client_provider.dart';
import '../models/client.dart';
import '../widgets/client_form.dart';
import '../widgets/client_card.dart';
import '../widgets/general_receipt_modal.dart';
import '../widgets/transaction_form.dart';
import 'transactions_screen.dart';
import '../utils/no_scrollbar_behavior.dart';

class ClientsScreen extends StatefulWidget {
  final String userId;
  const ClientsScreen({super.key, required this.userId});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final FocusScopeNode _screenFocusScopeNode = FocusScopeNode();
  bool _showSearch = false;
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _didLoadClients = false;

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
    _searchFocusNode.dispose();
    super.dispose();
  }

  // initState eliminado completamente para evitar cualquier acceso a context

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadClients) {
      final provider = Provider.of<ClientProvider>(context, listen: false);
      provider.loadClients(widget.userId);
      _didLoadClients = true;
    }
  }

  void _showClientForm([Client? client]) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.25),
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
              return await provider.addClient(newClient, widget.userId);
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
              await provider.loadClients(widget.userId);
              return client;
            }
          },
          readOnlyBalance: client != null,
        ),
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (_showSearch) {
        // Da foco al campo de búsqueda solo cuando se activa
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _searchFocusNode.requestFocus();
        });
      } else {
        _searchText = '';
        _searchController.clear();
        FocusScope.of(context).unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: _screenFocusScopeNode,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _screenFocusScopeNode.unfocus();
          if (_showSearch) {
            setState(() {
              _showSearch = false;
              _searchText = '';
              _searchController.clear();
            });
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFE6F0FF),
          body: SafeArea(
            child: Consumer<ClientProvider>(
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
                return Column(
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
                                if (allClients.isEmpty)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                    ],
                                  )
                                else
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
                                        heroTag: 'buscarCliente',
                                        mini: true,
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 2,
                                        onPressed: _toggleSearch,
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
                                      duration: const Duration(
                                        milliseconds: 350,
                                      ),
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
                                        focusNode: _searchFocusNode,
                                        style: const TextStyle(
                                          color: Colors.black,
                                        ),
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
                                  behavior: NoScrollbarBehavior(),
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    itemCount: clientsWithBalance.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final client = clientsWithBalance[index];
                                      return Container(
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
                                          userId: widget.userId,
                                          onEdit: () => _showClientForm(client),
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
                                            final userTransactions = txProvider
                                                .transactions
                                                .where(
                                                  (tx) =>
                                                      tx.clientId == client.id,
                                                )
                                                .toList();
                                            String warning = '';
                                            if (userTransactions.isNotEmpty) {
                                              warning =
                                                  '\n\nADVERTENCIA: Este cliente tiene ${userTransactions.length} transacción(es) asociada(s). Se eliminarán TODAS las transacciones de este cliente.';
                                            }
                                            final confirm = await showDialog<bool>(
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
                                          onViewMovements: () {
                                            Navigator.of(
                                              context,
                                              rootNavigator: true,
                                            ).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    TransactionsScreen(
                                                      userId: widget.userId,
                                                      initialClientId:
                                                          client.id,
                                                    ),
                                              ),
                                            );
                                          },
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
                                      );
                                    },
                                  ),
                                ),
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
    );
  }
}

// --- FIN: Layout desacoplado e independiente para pantalla de clientes ---

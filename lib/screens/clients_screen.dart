// Importa el proveedor de transacciones para acceder a los datos de transacciones
import '../providers/transaction_provider.dart';
// Importa el framework principal de Flutter para construir la interfaz
import 'package:flutter/material.dart';
// Importa Provider para la gestión de estado
import 'package:provider/provider.dart';
// Proveedor para manejar la lógica de clientes
import '../providers/client_provider.dart';
import '../providers/tab_provider.dart';
import '../providers/transaction_filter_provider.dart';
// import 'transactions_screen.dart';
// import 'receipt_screen.dart';
// Modelo de datos para un cliente
import '../models/client.dart';
// import '../models/transaction.dart';
// Widget para el formulario de cliente
import '../widgets/client_form.dart';
// Widget para el formulario de transacción
import '../widgets/transaction_form.dart';
// Widget para mostrar la tarjeta de un cliente
import '../widgets/client_card.dart';
// import '../widgets/currency_toggle.dart';
// Widget para mostrar el recibo general de todos los clientes
import '../widgets/general_receipt_modal.dart';

// Pantalla principal para mostrar y gestionar los clientes
class ClientsScreen extends StatefulWidget {
  final String userId;
  const ClientsScreen({super.key, required this.userId});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  // Controla si se muestra el buscador
  bool _showSearch = false;
  // Texto actual del buscador
  String _searchText = '';
  // Controlador para el campo de texto del buscador
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    // Libera el controlador cuando se destruye la pantalla
    _searchController.dispose();
    super.dispose();
  }
  // Eliminado _editingClient y _transactionClient porque no son necesarios

  @override
  void initState() {
    super.initState();
    // Carga los clientes al iniciar la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ClientProvider>(context, listen: false);
      provider.loadClients(widget.userId);
    });
  }

  // Muestra el formulario para agregar o editar un cliente
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

  // Muestra el formulario para agregar una transacción a un cliente
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
                        color:
                            Colors.transparent, // Fondo totalmente transparente
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

  // Elimina un cliente (y sus transacciones asociadas si existen)
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
  // Construye la interfaz de la pantalla de clientes
  Widget build(BuildContext context) {
    return Consumer<ClientProvider>(
      builder: (context, provider, child) {
        // Lista completa de clientes
        final allClients = provider.clients;
        // Detecta si es un dispositivo móvil
        final isMobile =
            Theme.of(context).platform == TargetPlatform.android ||
            Theme.of(context).platform == TargetPlatform.iOS;
        // Ancho de la pantalla
        final screenWidth = MediaQuery.of(context).size.width;
        // Ancho máximo de las tarjetas de cliente
        final cardMaxWidth = isMobile
            ? (screenWidth - 8).clamp(0.0, 900.0)
            : 700.0; // (No se usa, solo para referencia visual)

        // Filtrado en vivo
        // Filtra los clientes según el texto de búsqueda
        final clients = _showSearch && _searchText.isNotEmpty
            ? allClients
                  .where(
                    (c) => c.name.toLowerCase().contains(
                      _searchText.toLowerCase(),
                    ),
                  )
                  .toList()
            : allClients;

        // Ajustar balance a 0 si el cliente no tiene transacciones, pero NO eliminar ni ocultar clientes ni botones
        final txProvider = Provider.of<TransactionProvider>(
          context,
          listen: false,
        );
        final clientsWithBalance = clients.map((client) {
          final hasTransactions = txProvider.transactions.any(
            (tx) => tx.clientId == client.id,
          );
          // Solo ajustar el balance, no eliminar ni filtrar clientes
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

        // Estructura principal de la pantalla
        return Scaffold(
          backgroundColor: const Color(
            0xFFE6F0FF,
          ), // Fondo violeta/azulado claro original
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
                        Center(
                          child: Row(
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
                                MouseRegion(
                                  cursor: SystemMouseCursors.basic,
                                  child: FloatingActionButton(
                                    heroTag: 'buscarCliente',
                                    mini: true,
                                    backgroundColor: const Color(0xFF7C3AED),
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    hoverColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    splashColor: Colors.transparent,
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
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Mostrar el campo de búsqueda solo si hay clientes y el buscador está activo
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
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.text,
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
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          hoverColor: Colors.transparent,
                                          focusColor: Colors.transparent,
                                          splashColor: Colors.transparent,
                                          highlightColor: Colors.transparent,
                                          disabledColor: Colors.transparent,
                                          canvasColor: const Color(0xFFF3F6FD),
                                          inputDecorationTheme:
                                              const InputDecorationTheme(
                                                border: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                disabledBorder:
                                                    InputBorder.none,
                                                errorBorder: InputBorder.none,
                                                focusedErrorBorder:
                                                    InputBorder.none,
                                                fillColor: Color(0xFFF3F6FD),
                                                filled: true,
                                                hoverColor: Colors.transparent,
                                                focusColor: Colors.transparent,
                                                iconColor: Color(0xFF7C3AED),
                                                prefixIconColor: Color(
                                                  0xFF7C3AED,
                                                ),
                                                suffixIconColor: Colors.black,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 14,
                                                    ),
                                              ),
                                        ),
                                        child: TextField(
                                          controller: _searchController,
                                          autofocus: true,
                                          style: const TextStyle(
                                            color: Colors.black,
                                          ),
                                          cursorColor: Colors.black,
                                          enableInteractiveSelection:
                                              false, // Elimina highlight de selección
                                          mouseCursor: SystemMouseCursors.text,
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
                                            focusedErrorBorder:
                                                InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
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
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        // Lista de clientes o mensaje si no hay ninguno
                        clientsWithBalance.isEmpty
                            ? const Center(child: Text('No hay clientes.'))
                            : ScrollConfiguration(
                                behavior: const _NoScrollbarBehavior(),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
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
                                          ),
                                        ),
                                      ],
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
        );
      },
    );
  }
}

// Comportamiento para ocultar el scrollbar
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

// Comportamiento para hacer el scrollbar invisible pero permitir el scroll
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

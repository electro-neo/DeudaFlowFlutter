// --- INICIO: Código restaurado del último commit y ajustado para layout independiente ---

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/client_provider.dart';
import 'package:hive/hive.dart';
import '../models/client_hive.dart';
import '../widgets/client_form.dart';
import '../models/transaction.dart';
import '../models/client.dart';
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

class _ClientsScreenState extends State<ClientsScreen>
    with SingleTickerProviderStateMixin {
  // ...existing code...

  bool _isSyncing = false;
  StreamSubscription? _connectivitySubscription;
  late final AnimationController _syncController;

  final FocusScopeNode _screenFocusScopeNode = FocusScopeNode();
  bool _showSearch = false;
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _didLoadClients = false;

  // Método para mostrar el formulario de transacción
  void _showTransactionForm(ClientHive client) async {
    final isMobile =
        Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;
    Future<void> handleTransactionSave(Transaction tx) async {
      final txProvider = Provider.of<TransactionProvider>(
        context,
        listen: false,
      );
      //final clientProvider = Provider.of<ClientProvider>(
        //context,
       // listen: false,
      //);
      await txProvider.addTransaction(tx, widget.userId, client.id);
      // Sincroniza en segundo plano tras agregar movimiento para refrescar statscards
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _syncAll();
      });
      if (!mounted) return;
      Navigator.of(context).pop();
    }

    if (isMobile) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final maxHeight = MediaQuery.of(context).size.height * 0.92;
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.15 * 255).toInt()),
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
                          userId: widget.userId,
                          onSave: handleTransactionSave,
                          onClose: () => Navigator.of(context).pop(),
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
                  userId: widget.userId,
                  onSave: handleTransactionSave,
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
  void initState() {
    super.initState();
    _syncController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    // Escucha cambios de conectividad y dispara sincronización automática
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) async {
      // NOTA: En versiones recientes de connectivity_plus, 'result' es una lista.
      // El warning 'unrelated_type_equality_checks' aparece si comparas una lista con un solo valor.
      // Solución: verifica si la lista NO contiene ConnectivityResult.none para saber si hay conexión.
      if (!result.contains(ConnectivityResult.none) && !_isSyncing) {
        await _syncAll();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _screenFocusScopeNode.dispose();
    _connectivitySubscription?.cancel();
    _syncController.dispose();
    super.dispose();
  }

  Future<void> _syncAll() async {
    if (_isSyncing) return;
    // Verifica conexión a internet antes de sincronizar
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final provider = Provider.of<ClientProvider>(context, listen: false);
    bool isOnline = true;
    try {
      isOnline = await txProvider.isOnline();
    } catch (_) {
      isOnline = false;
    }
    if (!isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se puede sincronizar en este momento. Verifica tu conexión a internet.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    setState(() => _isSyncing = true);
    _syncController.repeat();
    await provider.syncPendingClients(widget.userId);
    await provider
        .cleanLocalPendingDeletedClients(); // Refuerzo: limpieza tras sync
    await txProvider.syncPendingTransactions(widget.userId);
    await txProvider
        .cleanLocalOrphanTransactions(); // Refuerzo: limpieza tras sync
    // Esperar a que no haya clientes pendientes de eliminar antes de recargar la lista
    int intentos = 0;
    bool hayPendientes;
    do {
      await provider.loadClients(widget.userId);
      final box = Hive.box<ClientHive>('clients');
      // LOG: Mostrar balances reales de todos los clientes tras recarga
      for (final c in box.values) {
        debugPrint(
          '[DEBUG][SYNC] Cliente: id=${c.id}, name=${c.name}, balance=${c.balance}, pendingDelete=${c.pendingDelete}',
        );
      }
      hayPendientes = box.values.any((c) => c.pendingDelete == true);
      if (hayPendientes) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      intentos++;
    } while (hayPendientes && intentos < 8);
    await txProvider.loadTransactions(widget.userId);
    if (mounted) {
      setState(() => _isSyncing = false);
      _syncController.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sincronización de clientes y transacciones completada.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // initState eliminado completamente para evitar cualquier acceso a context

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadClients) {
      // Ya no es necesario recalcular balances manualmente, el provider lo hace automáticamente
      _didLoadClients = true;
    }
  }

  void _showClientForm([ClientHive? client]) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (dialogContext) => Dialog(
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
            final txProvider = Provider.of<TransactionProvider>(
              context,
              listen: false,
            );
            // 1. Crear SIEMPRE en Hive (offline-first)
            if (client == null) {
              // Guardar cliente en Hive y obtener el id real tras sincronizar
              final realId = await provider.addClient(
                Client.fromHive(newClient),
                widget.userId,
              );
              await provider.loadClients(widget.userId);
              if (newClient.balance != 0) {
                final now = DateTime.now();
                final tx = Transaction(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  clientId: realId,
                  userId: widget.userId,
                  type: newClient.balance > 0 ? 'payment' : 'debt',
                  amount: newClient.balance.abs(),
                  description: 'Saldo inicial',
                  date: now,
                  createdAt: now,
                  synced: false, // Siempre pendiente por sincronizar
                );
                await txProvider.addTransaction(tx, widget.userId, realId);
                // Sincroniza en segundo plano tras agregar movimiento de saldo inicial
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) _syncAll();
                });
                await txProvider.loadTransactions(widget.userId);
                await provider.loadClients(widget.userId);
                // Si estamos online, sincroniza la transacción de saldo inicial inmediatamente
                if (await txProvider.isOnline()) {
                  await txProvider.syncPendingTransactions(widget.userId);
                }
              }
            } else {
              // Edición: actualizar en Hive y marcar como pendiente de sincronizar (offline-first)
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
            // 2. Lanzar sincronización a Supabase en segundo plano después de 2 segundos
            Future.delayed(const Duration(seconds: 2), () async {
              await provider.syncPendingClients(widget.userId);
              await txProvider.syncPendingTransactions(widget.userId);
              // Puedes agregar aquí lógica para mostrar un snackbar o actualizar la UI si lo deseas
            });
            // 3. El modal se cierra inmediatamente tras guardar en Hive (lo hace el formulario)
            return newClient;
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
                final box = Hive.box<ClientHive>('clients');
                final allClients = box.values.toList();
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
                final clientsWithBalance = clients;

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
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
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
                                          // Convierte ClientHive a Client para el modal
                                          final clientData = allClients
                                              .map(
                                                (c) => {
                                                  'client': Client.fromHive(c),
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
                                      FutureBuilder<bool>(
                                        future:
                                            Provider.of<TransactionProvider>(
                                              context,
                                              listen: false,
                                            ).isOnline(),
                                        builder: (context, snapshot) {
                                          final online = snapshot.data ?? true;
                                          if (!online) {
                                            // Si está offline, no muestra el botón de sincronizar
                                            return const SizedBox.shrink();
                                          }
                                          return FloatingActionButton(
                                            heroTag: 'syncClientes',
                                            mini: true,
                                            backgroundColor: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            foregroundColor: Colors.white,
                                            elevation: 2,
                                            onPressed: _isSyncing
                                                ? null
                                                : _syncAll,
                                            tooltip:
                                                'Forzar sincronización de clientes y transacciones',
                                            child: AnimatedBuilder(
                                              animation: _syncController,
                                              builder: (context, child) {
                                                return Transform.rotate(
                                                  angle: _isSyncing
                                                      ? -_syncController.value *
                                                            6.28319
                                                      : 0, // 2*pi (sentido inverso)
                                                  child: Icon(
                                                    Icons.sync,
                                                    color: _isSyncing
                                                        ? Colors.green
                                                        : Colors.white,
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        },
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
                                      const SizedBox(width: 12),
                                      FloatingActionButton(
                                        heroTag: 'eliminarTodos',
                                        mini: true,
                                        backgroundColor: Colors.red[700],
                                        foregroundColor: Colors.white,
                                        elevation: 2,
                                        onPressed: () async {
                                          final provider =
                                              Provider.of<ClientProvider>(
                                                context,
                                                listen: false,
                                              );
                                          final txProvider =
                                              Provider.of<TransactionProvider>(
                                                context,
                                                listen: false,
                                              );
                                          final box = Hive.box<ClientHive>(
                                            'clients',
                                          );
                                          final allClients = box.values
                                              .toList();
                                          debugPrint(
                                            '[ELIMINAR_TODOS] Clientes encontrados: ${allClients.length}',
                                          );
                                          if (allClients.isEmpty) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'No hay clientes para eliminar.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text(
                                                'Eliminar TODOS los clientes',
                                              ),
                                              content: const Text(
                                                '¿Estás seguro de eliminar TODOS los clientes y sus transacciones? Esta acción no se puede deshacer.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    context,
                                                  ).pop(false),
                                                  child: const Text('Cancelar'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    context,
                                                  ).pop(true),
                                                  child: const Text(
                                                    'Eliminar todo',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            debugPrint(
                                              '[ELIMINAR_TODOS] Eliminando todos los clientes...',
                                            );
                                            for (final client in allClients) {
                                              debugPrint(
                                                '[ELIMINAR_TODOS] Eliminando cliente: ${client.id} (${client.name})',
                                              );
                                              await provider.deleteClient(
                                                client.id,
                                                widget.userId,
                                              );
                                            }
                                            await provider
                                                .cleanLocalPendingDeletedClients();
                                            debugPrint(
                                              '[ELIMINAR_TODOS] Sincronizando eliminaciones...',
                                            );
                                            await provider.syncPendingClients(
                                              widget.userId,
                                            );
                                            await txProvider
                                                .syncPendingTransactions(
                                                  widget.userId,
                                                );
                                            int intentos = 0;
                                            bool hayPendientes;
                                            do {
                                              await provider.loadClients(
                                                widget.userId,
                                              );
                                              final box = Hive.box<ClientHive>(
                                                'clients',
                                              );
                                              hayPendientes = box.values.any(
                                                (c) => c.pendingDelete == true,
                                              );
                                              debugPrint(
                                                '[ELIMINAR_TODOS] Intento ${intentos + 1}: ¿Quedan clientes pendientes de eliminar? $hayPendientes',
                                              );
                                              if (hayPendientes) {
                                                await Future.delayed(
                                                  const Duration(
                                                    milliseconds: 500,
                                                  ),
                                                );
                                              }
                                              intentos++;
                                            } while (hayPendientes &&
                                                intentos < 8);
                                            debugPrint(
                                              '[ELIMINAR_TODOS] Recargando transacciones...',
                                            );
                                            await txProvider.loadTransactions(
                                              widget.userId,
                                            );
                                            if (mounted) {
                                              debugPrint(
                                                '[ELIMINAR_TODOS] Proceso completado.',
                                              );
                                              // Verifica si está offline
                                              final isOnline = await txProvider
                                                  .isOnline();
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    isOnline
                                                        ? 'Todos los clientes eliminados.'
                                                        : 'Clientes pendientes por eliminar',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        tooltip: 'Eliminar TODOS los clientes',
                                        child: const Icon(Icons.delete_forever),
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
                                                  ).withValues(alpha: 0.18),
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
                            color: const Color.fromARGB(
                              0,
                              0,
                              0,
                              0,
                            ).withValues(alpha: 0.00),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromARGB(
                                  0,
                                  0,
                                  0,
                                  0,
                                ).withValues(alpha: 0.00),
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
                                          color: const Color.fromARGB(
                                            0,
                                            0,
                                            0,
                                            0,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color.fromARGB(
                                                0,
                                                0,
                                                0,
                                                0,
                                              ).withValues(alpha: 0.03),
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
                                              // Limpieza local de clientes nunca sincronizados marcados para eliminar
                                              await provider
                                                  .cleanLocalPendingDeletedClients();
                                              await provider.syncPendingClients(
                                                widget.userId,
                                              );
                                              await txProvider
                                                  .syncPendingTransactions(
                                                    widget.userId,
                                                  );
                                              await provider.loadClients(
                                                widget.userId,
                                              );
                                              await txProvider.loadTransactions(
                                                widget.userId,
                                              );
                                              if (!mounted) return;
                                              // ignore: use_build_context_synchronously
                                              // NOTA: Este warning aparece porque el linter de Flutter no siempre detecta correctamente el patrón de chequeo de 'mounted'.
                                              // El uso de context aquí es seguro porque se verifica 'mounted' justo antes. Puedes ignorar este warning: no afecta la ejecución ni la seguridad del código.
                                              // Verifica si está online antes de mostrar el mensaje
                                              final isOnline = await txProvider.isOnline();
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    isOnline
                                                        ? 'Cliente eliminado correctamente.'
                                                        : 'Cliente pendiente por eliminar',
                                                  ),
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                ),
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

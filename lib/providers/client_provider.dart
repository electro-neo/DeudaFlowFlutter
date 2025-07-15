import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import '../models/client.dart';
import '../models/client_hive.dart';
import '../models/transaction_hive.dart';
import '../services/supabase_service.dart';
import 'transaction_provider.dart';

class ClientProvider extends ChangeNotifier {
  /// Sincroniza los clientes locales pendientes cuando hay internet
  Future<void> syncPendingClients(String userId) async {
    if (!await _isOnline()) return;
    final box = Hive.box<ClientHive>('clients');
    // 1. LOG: Mostrar todos los clientes marcados para eliminar
    final pendingDeletes = box.values
        .where((c) => c.pendingDelete == true)
        .toList();
    if (pendingDeletes.isNotEmpty) {
      debugPrint(
        '[SYNC][INFO] Clientes marcados para eliminar (pendingDelete=true):',
      );
      for (final c in pendingDeletes) {
        debugPrint('  - id: ${c.id}, name: ${c.name}, synced: ${c.synced}');
      }
    }
    // 2. Procesar eliminaciones pendientes (todas antes de sincronizar)
    for (final c in pendingDeletes) {
      if (c.id.isNotEmpty) {
        try {
          debugPrint(
            '[SYNC] Intentando eliminar cliente ${c.id} de Supabase...',
          );
          final bool fueEliminado = await _service.deleteClientAndTransactions(
            c.id,
          );

          if (fueEliminado) {
            debugPrint(
              '[SYNC][SUCCESS] Cliente ${c.id} confirmado como eliminado en Supabase. Eliminando de Hive...',
            );
            await c.delete();
          } else {
            debugPrint(
              '[SYNC][WARN] Falló la eliminación del cliente ${c.id} en Supabase. Se reintentará en la próxima sincronización.',
            );
          }
        } catch (e, stack) {
          debugPrint(
            '[SYNC][ERROR] Excepción al intentar eliminar cliente ${c.id}: $e',
          );
          debugPrint('[SYNC][ERROR] Stacktrace: $stack');
        }
      } else {
        debugPrint(
          '[SYNC] Cliente con id local (no UUID), eliminado solo de Hive.',
        );
        await c.delete();
      }
    }

    // 3. LOG: Mostrar clientes pendientes de sincronizar (creación/edición)
    final pending = box.values
        .where((c) => !c.synced && !c.pendingDelete)
        .toList();
    if (pending.isNotEmpty) {
      debugPrint(
        '[SYNC][INFO] Clientes pendientes de sincronizar (creación/edición):',
      );
      for (final c in pending) {
        debugPrint('  - id: ${c.id}, name: ${c.name}');
      }
    }
    // 4. Procesar creaciones/ediciones pendientes
    for (final c in pending) {
      final client = Client(
        id: c.id,
        name: c.name,
        email: c.email,
        phone: c.phone,
        balance: c.balance,
        localId: c.localId,
      );
      try {
        // Si el id NO es UUID (36 caracteres), es local: hacer upsert por local_id y reconciliar
        if (c.id.isNotEmpty && c.id.length != 36) {
          final newId = await _service.addClient(client, userId);
          if (newId != null) {
            final box = Hive.box<ClientHive>('clients');
            final old = box.get(c.id);
            if (old != null) {
              final updated = ClientHive(
                id: newId,
                name: old.name,
                email: old.email,
                phone: old.phone,
                balance: old.balance,
                synced: true,
                pendingDelete: old.pendingDelete,
                localId: old.localId,
              );
              await box.delete(c.id);
              await box.put(newId, updated);

              // --- ACTUALIZAR TRANSACCIONES CON EL NUEVO ID DE CLIENTE ---
              Box<TransactionHive> txBox;
              if (Hive.isBoxOpen('transactions')) {
                txBox = Hive.box<TransactionHive>('transactions');
              } else {
                txBox = await Hive.openBox<TransactionHive>('transactions');
              }
              final txsToUpdate = txBox.values
                  .where((tx) => tx.clientId == c.id)
                  .toList();
              for (final tx in txsToUpdate) {
                tx.clientId = newId;
                await tx.save();
              }
              debugPrint(
                '[SYNC][INFO] Transacciones actualizadas al nuevo id de cliente: $newId (${txsToUpdate.length} transacciones)',
              );
            }
          }
        } else if (c.id.isNotEmpty) {
          // Si tiene id real (UUID), intenta actualizar
          await _service.updateClient(client);
          c.synced = true;
          await c.save();
          // Refuerzo: tras sincronizar, asegurar que TODAS las transacciones de este cliente tengan el id correcto
          if (c.id.length == 36) {
            Box<TransactionHive> txBox;
            if (Hive.isBoxOpen('transactions')) {
              txBox = Hive.box<TransactionHive>('transactions');
            } else {
              txBox = await Hive.openBox<TransactionHive>('transactions');
            }
            final clientBox = Hive.box<ClientHive>('clients');
            final txsToUpdate = txBox.values.where((tx) {
              final relatedClient = clientBox.get(tx.clientId);
              return tx.clientId != c.id && relatedClient?.name == c.name;
            }).toList();
            for (final tx in txsToUpdate) {
              tx.clientId = c.id;
              await tx.save();
            }
            if (txsToUpdate.isNotEmpty) {
              debugPrint(
                '[SYNC][INFO] Transacciones antiguas actualizadas al id correcto de cliente: ${c.id} (${txsToUpdate.length} transacciones)',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[SYNC][ERROR] Error al sincronizar cliente: $e');
      }
    }

    // 5. Solo después de procesar eliminaciones y creaciones, recarga los clientes desde Supabase
    // await loadClients(userId); // <-- Eliminamos esta llamada
    await _refreshClientsFromHive(); // <-- Usamos la nueva función para refrescar desde Hive
  }

  final SupabaseService _service = SupabaseService();
  List<Client> _clients = [];
  List<Client> get clients => _clients;

  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    if (result.contains(ConnectivityResult.none)) {
      return false;
    }
    // Prueba acceso real a internet
    try {
      final response = await InternetAddress.lookup('google.com');
      if (response.isNotEmpty && response[0].rawAddress.isNotEmpty) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshClientsFromHive() async {
    final box = Hive.box<ClientHive>('clients');
    _clients = box.values
        .where((c) => c.pendingDelete != true)
        .map(
          (c) => Client(
            id: c.id,
            name: c.name,
            email: c.email,
            phone: c.phone,
            balance: c.balance,
          ),
        )
        .toList();
    // LOG: Mostrar balances reales de todos los clientes tras recarga en el provider
    for (final c in box.values) {
      debugPrint(
        '[DEBUG][PROVIDER][REFRESH] Cliente: id=${c.id}, name=${c.name}, balance=${c.balance}, pendingDelete=${c.pendingDelete}',
      );
    }
    notifyListeners();
    debugPrint(
      '[PROVIDER][REFRESH] La lista de clientes se ha actualizado desde Hive.',
    );
  }

  Future<void> loadClients(String userId) async {
    final isOnline = await _isOnline();
    final box = await Hive.openBox<ClientHive>('clients');
    // MIGRACIÓN AUTOMÁTICA: Fuerza la escritura de los campos para todos los clientes y corrige nulls
    // Aquí podría ir lógica de migración/corrección de datos si es necesario
    // Actualmente, no se realiza migración en este punto.
    if (isOnline) {
      try {
        // Online: usa Supabase y sincroniza Hive
        final remoteClients = await _service.fetchClients(userId);
        // Guarda los IDs de clientes locales pendientes de eliminar
        final pendingDeleteIds = box.values
            .where((c) => c.pendingDelete == true)
            .map((c) => c.id)
            .toSet();
        // Mantén los clientes locales no sincronizados ni pendientes de eliminar
        final localPending = box.values
            .where((c) => !c.synced && !c.pendingDelete)
            .toList();
        await box.clear();
        // Guarda los de Supabase como sincronizados, excepto los que están pendientes de eliminar localmente
        for (final c in remoteClients) {
          if (!pendingDeleteIds.contains(c.id)) {
            box.put(
              c.id,
              ClientHive(
                id: c.id,
                name: c.name,
                email: c.email,
                phone: c.phone,
                balance: c.balance,
                synced: true,
                pendingDelete: false,
              ),
            );
          }
        }
        // Vuelve a guardar los locales pendientes y los pendientes de eliminar
        for (final c in localPending) {
          box.put(c.id, c);
        }
        // También vuelve a guardar los pendientes de eliminar para que no se pierdan
        for (final c in box.values.where((c) => c.pendingDelete == true)) {
          box.put(c.id, c);
        }
        // Refresca la lista desde Hive para asegurar que el estado synced es correcto
        _clients = box.values
            .where((c) => c.pendingDelete != true)
            .map(
              (c) => Client(
                id: c.id,
                name: c.name,
                email: c.email,
                phone: c.phone,
                balance: c.balance, // Este valor será recalculado localmente
              ),
            )
            .toList();
        // Recalcula los balances de todos los clientes después de cargar desde Supabase
        try {
          // Recalcula balances usando la función estática para evitar crear un nuevo provider
          await TransactionProvider.recalculateAllClientsBalancesStatic();
        } catch (e) {
          debugPrint(
            '[SYNC][WARN] No se pudo recalcular balances tras sync: $e',
          );
        }
      } catch (e) {
        // Si falla la red, carga desde Hive
        _clients = box.values
            .where((c) => c.pendingDelete != true)
            .map(
              (c) => Client(
                id: c.id,
                name: c.name,
                email: c.email,
                phone: c.phone,
                balance: c.balance,
              ),
            )
            .toList();
      }
    } else {
      // Offline: usa Hive
      _clients = box.values
          .where((c) => c.pendingDelete != true)
          .map(
            (c) => Client(
              id: c.id,
              name: c.name,
              email: c.email,
              phone: c.phone,
              balance: c.balance,
            ),
          )
          .toList();
    }
    notifyListeners();
  }

  Future<String> addClient(Client client, String userId) async {
    // Siempre crea el cliente en Hive como pendiente de sincronizar (offline-first)
    final box = Hive.box<ClientHive>('clients');
    String randomLetters(int n) {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      final rand = DateTime.now().microsecondsSinceEpoch;
      return List.generate(
        n,
        (i) => chars[(rand >> (i * 5)) % chars.length],
      ).join();
    }

    final localId =
        randomLetters(2) + DateTime.now().millisecondsSinceEpoch.toString();
    final clientHive = ClientHive(
      id: client.id,
      name: client.name,
      email: client.email,
      phone: client.phone,
      balance: client.balance,
      synced: false,
      pendingDelete: false,
      localId: client.localId ?? localId,
    );
    box.put(client.id, clientHive);
    await _refreshClientsFromHive();

    // Si estamos online, sincroniza inmediatamente
    String finalId = client.id;
    if (await _isOnline()) {
      await syncPendingClients(userId);
      // Buscar el id real en Hive después de sincronizar
      final updated = box.values.firstWhere(
        (c) =>
            c.name == client.name &&
            c.email == client.email &&
            c.phone == client.phone &&
            c.balance == client.balance,
        orElse: () => box.get(client.id)!,
      );
      finalId = updated.id;
      // --- ACTUALIZAR TRANSACCIONES CON EL NUEVO ID DE CLIENTE ---
      if (finalId != client.id) {
        Box<TransactionHive> txBox;
        if (Hive.isBoxOpen('transactions')) {
          txBox = Hive.box<TransactionHive>('transactions');
        } else {
          txBox = await Hive.openBox<TransactionHive>('transactions');
        }
        final txsToUpdate = txBox.values
            .where((tx) => tx.clientId == client.id)
            .toList();
        for (final tx in txsToUpdate) {
          tx.clientId = finalId;
          await tx.save();
        }
      }
      // Refrescar clientes desde Hive y notificar listeners para asegurar actualización inmediata de la UI
      await _refreshClientsFromHive();
    }
    return finalId;
  }

  Future<void> updateClient(Client client, String userId) async {
    // Siempre actualiza en Hive y marca como pendiente de sincronizar
    final box = Hive.box<ClientHive>('clients');
    final c = box.get(client.id);
    if (c != null) {
      c
        ..name = client.name
        ..email = client.email
        ..phone = client.phone
        ..balance = client.balance
        ..synced = false;
      await c.save();
    }
    await _refreshClientsFromHive();

    // Si estamos online, sincroniza inmediatamente
    if (await _isOnline()) {
      await syncPendingClients(userId);
      // Refrescar clientes desde Hive y notificar listeners para asegurar actualización inmediata de la UI
      await _refreshClientsFromHive();
    }
  }

  Future<void> deleteClient(String clientId, String userId) async {
    final box = Hive.box<ClientHive>('clients');
    final c = box.get(clientId);
    if (c == null) return;

    // 1. Marcar como pendiente de eliminar en Hive
    c.pendingDelete = true;
    await c.save();
    // await loadClients(userId);
    await _refreshClientsFromHive();

    // 2. Verificar si estamos online
    if (await _isOnline()) {
      // Si hay internet, sincroniza inmediatamente (elimina en Supabase y luego en Hive)
      await syncPendingClients(userId);
    } else {
      // Si está offline, iniciar polling cada 2 segundos hasta que haya internet
      _startDeletePolling(clientId, userId);
    }
  }

  // Polling para intentar sincronizar la eliminación cuando vuelva el internet
  void _startDeletePolling(String clientId, String userId) async {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (await _isOnline()) {
        await syncPendingClients(userId);
        return false; // Detener el polling
      }
      // Si el cliente ya no existe (fue eliminado), detener polling
      final box = Hive.box<ClientHive>('clients');
      if (!box.containsKey(clientId)) return false;
      return true; // Seguir intentando
    });
  }
}

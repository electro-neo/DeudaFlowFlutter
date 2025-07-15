import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';
import 'package:hive/hive.dart';

import '../models/transaction.dart';
import '../models/transaction_hive.dart';
import '../models/client_hive.dart';
import '../models/client.dart';
import '../services/supabase_service.dart';
import 'package:provider/provider.dart';
import 'client_provider.dart';
import '../main.dart' show navigatorKey;

class TransactionProvider extends ChangeNotifier {
  /// Elimina una transacción de la lista en memoria y notifica listeners (solo UI, no Hive)
  void removeTransactionLocally(String transactionId) {
    _transactions.removeWhere((t) => t.id == transactionId);
    notifyListeners();
  }

  /// Marca una transacción como pendiente de eliminar en Hive y sincroniza con el backend cuando sea posible
  Future<void> markTransactionForDeletionAndSync(
    String transactionId,
    String userId,
  ) async {
    final box = Hive.isBoxOpen('transactions')
        ? Hive.box<TransactionHive>('transactions')
        : await Hive.openBox<TransactionHive>('transactions');
    final t = box.get(transactionId);
    if (t != null) {
      t.pendingDelete = true;
      t.synced = false;
      await t.save();
      // Elimina de la lista en memoria para que desaparezca de la UI
      _transactions.removeWhere((tx) => tx.id == transactionId);
      notifyListeners();
      // Intenta sincronizar con el backend si hay conexión
      if (await isOnline()) {
        try {
          await _service.deleteTransaction(transactionId);
          await box.delete(transactionId);
        } catch (_) {
          // Si falla, queda como pendienteDelete
        }
      }
      // Recalcula balances y recarga lista
      await recalculateClientBalance(t.clientId);
      await loadTransactions(userId);
    }
  }

  /// Marca una transacción como pendiente de eliminar y actualiza la lista principal
  Future<void> markPendingDelete(String transactionId) async {
    final box = Hive.isBoxOpen('transactions')
        ? Hive.box<TransactionHive>('transactions')
        : await Hive.openBox<TransactionHive>('transactions');
    final t = box.get(transactionId);
    if (t != null) {
      t.pendingDelete = true;
      t.synced = false;
      await t.save();
      notifyListeners();
    }
  }

  /// Permite recalcular balances de todos los clientes desde cualquier parte del código (ej: tras sync)
  static Future<void> recalculateAllClientsBalancesStatic() async {
    final clientBox = Hive.isBoxOpen('clients')
        ? Hive.box<ClientHive>('clients')
        : await Hive.openBox<ClientHive>('clients');
    for (final client in clientBox.values) {
      await TransactionProvider._recalculateClientBalanceStatic(client.id);
    }
  }

  static Future<void> _recalculateClientBalanceStatic(String clientId) async {
    final clientBox = Hive.isBoxOpen('clients')
        ? Hive.box<ClientHive>('clients')
        : await Hive.openBox<ClientHive>('clients');
    final txBox = Hive.isBoxOpen('transactions')
        ? Hive.box<TransactionHive>('transactions')
        : await Hive.openBox<TransactionHive>('transactions');
    final client = clientBox.get(clientId);
    if (client == null) return;
    final txs = txBox.values.where(
      (t) => t.clientId == clientId && t.pendingDelete != true,
    );
    double newBalance = 0;
    for (final t in txs) {
      if (t.type == 'debt') {
        newBalance -= t.amount;
      } else if (t.type == 'payment') {
        newBalance += t.amount;
      }
    }
    if (client.balance != newBalance) {
      client.balance = newBalance;
      await client.save();
    }
  }

  final SupabaseService _service = SupabaseService();
  List<Transaction> _transactions = [];
  List<Transaction> get transactions =>
      _transactions.where((t) => t.pendingDelete != true).toList();

  // Mantener referencia al stream subscription para cancelarlo si es necesario
  StreamSubscription? _connectivitySubscription;

  // Nuevo: guardar el userId más reciente
  String? _lastKnownUserId;
  String? get lastKnownUserId => _lastKnownUserId;

  TransactionProvider() {
    // Escucha cambios de conectividad y sincroniza automáticamente
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) async {
      // Para versiones recientes de connectivity_plus: result es List<ConnectivityResult>
      if (result.any((r) => r != ConnectivityResult.none)) {
        await syncPendingTransactionsOnConnection(userId: _lastKnownUserId);
      }
    });
  }

  // Llama a la sincronización solo si hay pendientes
  Future<void> syncPendingTransactionsOnConnection({String? userId}) async {
    final box = Hive.isBoxOpen('transactions')
        ? Hive.box<TransactionHive>('transactions')
        : await Hive.openBox<TransactionHive>('transactions');
    final hasPending = box.values.any(
      (t) => !t.synced || t.pendingDelete == true,
    );

    if (!hasPending) return;

    // Busca un userId válido
    String? effectiveUserId = userId;
    if (effectiveUserId == null || effectiveUserId.isEmpty) {
      // 1. Intenta con el último userId conocido
      if (_lastKnownUserId != null && _lastKnownUserId!.isNotEmpty) {
        effectiveUserId = _lastKnownUserId;
      } else if (_transactions.isNotEmpty) {
        effectiveUserId = _transactions.first.userId;
      } else {
        // Si la lista en memoria está vacía, busca en Hive
        TransactionHive? anyTransaction;
        try {
          anyTransaction = box.values.firstWhere(
            (t) => t.userId != null && t.userId!.isNotEmpty,
          );
        } on StateError {
          anyTransaction = null; // No se encontró, es seguro continuar
        }
        if (anyTransaction != null) {
          effectiveUserId = anyTransaction.userId;
        }
      }
    }

    if (effectiveUserId != null && effectiveUserId.isNotEmpty) {
      debugPrint(
        '[SYNC] Conexión recuperada. Sincronizando transacciones pendientes para el usuario $effectiveUserId...',
      );
      await syncPendingTransactions(effectiveUserId);
    } else {
      debugPrint(
        '[SYNC][WARN] Conexión recuperada, pero no se pudo encontrar un userId para sincronizar transacciones.',
      );
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    // Para versiones recientes de connectivity_plus, result es List<ConnectivityResult>
    if (result.every((r) => r == ConnectivityResult.none)) return false;
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

  Future<void> loadTransactions(String userId) async {
    final online = await isOnline();
    final box = Hive.isBoxOpen('transactions')
        ? Hive.box<TransactionHive>('transactions')
        : await Hive.openBox<TransactionHive>('transactions');
    // Guarda el userId más reciente
    _lastKnownUserId = userId;
    // MIGRACIÓN AUTOMÁTICA: Fuerza la escritura de los campos para todos los registros
    for (final t in box.values) {
      t.synced = t.synced;
      t.pendingDelete = t.pendingDelete;
      t.save();
    }
    if (online) {
      try {
        // Online: usa Supabase y sincroniza Hive
        final remoteTxs = await _service.fetchTransactions(userId);
        // --- RECONCILIACIÓN DE IDS: Si el local_id coincide con una transacción local pendiente, actualiza el id local por el UUID real de Supabase ---
        final localTxs = box.values.toList();
        for (final remote in remoteTxs) {
          final localMatches = localTxs
              .where((t) => t.id == (remote.localId ?? ''))
              .toList();
          if (localMatches.isNotEmpty && remote.id != localMatches.first.id) {
            final localMatch = localMatches.first;
            // Actualiza el id local por el UUID real de Supabase
            final updated = TransactionHive(
              id: remote.id,
              clientId: localMatch.clientId,
              type: localMatch.type,
              amount: localMatch.amount,
              date: localMatch.date,
              description: localMatch.description,
              synced: true,
              pendingDelete: false,
              userId: localMatch.userId,
            );
            await box.delete(localMatch.id);
            await box.put(updated.id, updated);
          }
        }
        // Mantén las transacciones locales no sincronizadas o pendientes de eliminar
        final localPending = box.values
            .where((t) => t.synced == false || t.pendingDelete == true)
            .toList();
        // Elimina localmente las transacciones pendientes que nunca se sincronizaron y fueron eliminadas offline
        final localPendingToKeep = localPending
            .where((t) => t.id != '')
            .toList();
        await box.clear();
        // Guarda las de Supabase como sincronizadas
        for (final t in remoteTxs) {
          box.put(
            t.id,
            TransactionHive(
              id: t.id,
              clientId: t.clientId,
              type: t.type,
              amount: t.amount,
              date: t.date,
              description: t.description,
              synced: true,
              pendingDelete: false,
              userId: userId, // Asegura que el userId se guarde en Hive
            ),
          );
        }
        // Vuelve a guardar las locales pendientes válidas
        for (final t in localPendingToKeep) {
          box.put(t.id, t);
        }
        // Refresca la lista desde Hive para asegurar que el estado synced es correcto
        _transactions = box.values.map((t) => Transaction.fromHive(t)).toList();
        // Recalcula balances de todos los clientes tras cargar transacciones
        await _recalculateAllClientsBalances();
      } catch (e) {
        // Si falla la red, carga desde Hive
        _transactions = box.values.map((t) => Transaction.fromHive(t)).toList();
        await _recalculateAllClientsBalances();
      }
    } else {
      // Offline: usa Hive
      _transactions = box.values.map((t) => Transaction.fromHive(t)).toList();
      await _recalculateAllClientsBalances();
    }
    notifyListeners();
  }

  // Recalcula el balance de todos los clientes existentes
  Future<void> _recalculateAllClientsBalances() async {
    final clientBox = Hive.isBoxOpen('clients')
        ? Hive.box<ClientHive>('clients')
        : await Hive.openBox<ClientHive>('clients');
    for (final client in clientBox.values) {
      await recalculateClientBalance(client.id);
    }
  }

  // Recalcula y guarda el balance de un cliente tras cambios en sus transacciones
  Future<void> recalculateClientBalance(String clientId) async {
    final clientBox = Hive.isBoxOpen('clients')
        ? Hive.box<ClientHive>('clients')
        : await Hive.openBox<ClientHive>('clients');
    final txBox = Hive.isBoxOpen('transactions')
        ? Hive.box<TransactionHive>('transactions')
        : await Hive.openBox<TransactionHive>('transactions');
    final client = clientBox.get(clientId);
    if (client == null) return;
    final txs = txBox.values.where(
      (t) => t.clientId == clientId && t.pendingDelete != true,
    );
    double newBalance = 0;
    for (final t in txs) {
      if (t.type == 'debt') {
        newBalance -= t.amount;
      } else if (t.type == 'payment') {
        newBalance += t.amount;
      }
    }
    if (client.balance != newBalance) {
      client.balance = newBalance;
      await client.save();
      debugPrint(
        '[recalculateClientBalance][LOCAL] Balance actualizado en Hive para cliente ${client.id}: $newBalance',
      );
      // Refresca la UI y notifica listeners SIEMPRE, aunque falle Supabase
      try {
        notifyListeners();
      } catch (e) {
        debugPrint('[recalculateClientBalance][UI-REFRESH][ERROR] $e');
      }
      // Sincroniza con Supabase SOLO si hay userId, pero no bloquea el flujo local
      try {
        final clientModel = Client(
          id: client.id,
          name: client.name,
          email: client.email,
          phone: client.phone,
          balance: client.balance,
          localId: client.localId,
        );
        final userId = _lastKnownUserId ?? '';
        if (userId.isNotEmpty) {
          await SupabaseService().updateClient(clientModel);
          // Opción: puedes refrescar el provider global si lo deseas, pero no es obligatorio
        }
      } catch (e, stack) {
        debugPrint(
          '[recalculateClientBalance][ERROR] No se pudo actualizar el balance en Supabase: $e',
        );
        debugPrint('[recalculateClientBalance][STACK] $stack');
      }
    }
  }

  Future<void> addTransaction(
    Transaction tx,
    String userId,
    String clientId,
  ) async {
    final box = Hive.isBoxOpen('transactions')
        ? Hive.box<TransactionHive>('transactions')
        : await Hive.openBox<TransactionHive>('transactions');
    final online = await isOnline();
    _lastKnownUserId = userId;

    // --- GENERAR localId CONSISTENTE (2 letras mayúsculas + timestamp) ---
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
    final txWithLocalId = tx.localId != null && tx.localId!.isNotEmpty
        ? tx
        : tx.copyWith(id: localId, localId: localId);

    if (online) {
      try {
        await _service.addTransaction(txWithLocalId, userId, clientId);
        box.put(
          txWithLocalId.id,
          TransactionHive(
            id: txWithLocalId.id,
            clientId: txWithLocalId.clientId,
            type: txWithLocalId.type,
            amount: txWithLocalId.amount,
            date: txWithLocalId.date,
            description: txWithLocalId.description,
            synced: true,
            pendingDelete: false,
            userId: userId,
          ),
        );
      } catch (_) {
        box.put(
          txWithLocalId.id,
          TransactionHive(
            id: txWithLocalId.id,
            clientId: txWithLocalId.clientId,
            type: txWithLocalId.type,
            amount: txWithLocalId.amount,
            date: txWithLocalId.date,
            description: txWithLocalId.description,
            synced: false,
            pendingDelete: false,
            userId: userId,
          ),
        );
      }
    } else {
      box.put(
        txWithLocalId.id,
        TransactionHive(
          id: txWithLocalId.id,
          clientId: txWithLocalId.clientId,
          type: txWithLocalId.type,
          amount: txWithLocalId.amount,
          date: txWithLocalId.date,
          description: txWithLocalId.description,
          synced: false,
          pendingDelete: false,
          userId: userId,
        ),
      );
    }
    await recalculateClientBalance(clientId);
    await loadTransactions(userId);
  }

  Future<void> updateTransaction(Transaction tx, String userId) async {
    final online = await isOnline();
    final box = Hive.isBoxOpen('transactions')
        ? Hive.box<TransactionHive>('transactions')
        : await Hive.openBox<TransactionHive>('transactions');
    if (online) {
      try {
        await _service.updateTransaction(tx);
      } catch (_) {
        // Si falla la red, marca como no sincronizado
        final t = box.get(tx.id);
        if (t != null) {
          t
            ..type = tx.type
            ..amount = tx.amount
            ..date = tx.date
            ..synced = false;
          await t.save();
        }
      }
      await recalculateClientBalance(tx.clientId);
      await loadTransactions(userId);
    } else {
      final t = box.get(tx.id);
      if (t != null) {
        t
          ..type = tx.type
          ..amount = tx.amount
          ..date = tx.date
          ..synced = false;
        await t.save();
      }
      await recalculateClientBalance(tx.clientId);
      await loadTransactions(userId);
    }
  }

  Future<void> deleteTransaction(String transactionId, String userId) async {
    final online = await isOnline();
    final box = Hive.isBoxOpen('transactions')
        ? Hive.box<TransactionHive>('transactions')
        : await Hive.openBox<TransactionHive>('transactions');
    final t = box.get(transactionId);
    if (t == null) return;
    final clientId = t.clientId;
    if (online) {
      try {
        await _service.deleteTransaction(transactionId);
        await box.delete(transactionId);
      } catch (_) {
        // Si falla la red, marca como pendiente de eliminar
        t.pendingDelete = true;
        t.synced = false;
        await t.save();
      }
    } else {
      // Solo marca como pendiente de eliminar
      t.pendingDelete = true;
      t.synced = false;
      await t.save();
    }

    // Actualiza la lista en memoria (sin recargar todo Hive)
    _transactions.removeWhere((tx) => tx.id == transactionId);

    // Recalcula y guarda el balance, notifica a la UI inmediatamente
    await recalculateClientBalance(clientId);
    notifyListeners();
  }

  /// Sincroniza los cambios locales pendientes cuando hay internet
  Future<void> syncPendingTransactions(String userId) async {
    if (!await isOnline()) return;
    final box = Hive.isBoxOpen('transactions')
        ? Hive.box<TransactionHive>('transactions')
        : await Hive.openBox<TransactionHive>('transactions');

    // Refuerzo: sincronizar clientes primero para garantizar que todos tengan UUID
    try {
      final clientProvider = ClientProvider();
      await clientProvider.syncPendingClients(userId);
    } catch (e) {
      debugPrint(
        '[SYNC][WARN] No se pudo sincronizar clientes antes de transacciones: $e',
      );
    }

    // Primero elimina en Supabase las transacciones pendientes de eliminar
    final toDelete = box.values.where((t) => t.pendingDelete == true).toList();
    for (final t in toDelete) {
      try {
        await _service.deleteTransaction(t.id);
        await box.delete(t.id);
      } catch (_) {
        // Si falla, sigue pendiente
      }
    }

    // Obtén las transacciones remotas para reconciliar antes de subir
    List<Transaction> remoteTxs = [];
    try {
      remoteTxs = await _service.fetchTransactions(userId);
    } catch (_) {}

    // Sincroniza las transacciones pendientes de agregar/editar
    final pending = box.values
        .where((t) => !t.synced && t.pendingDelete != true)
        .toList();
    for (final t in pending) {
      // Validar que el clientId sea un UUID válido (36 caracteres)
      if (t.clientId.length != 36) {
        debugPrint(
          '[SYNC][SKIP] Transacción ${t.id} NO se sube porque clientId no es UUID válido: ${t.clientId}',
        );
        continue;
      }
      // Busca si ya existe en remoto por local_id
      final idx = remoteTxs.indexWhere(
        (r) => r.localId != null && r.localId == t.id,
      );
      if (idx != -1) {
        final remoteMatch = remoteTxs[idx];
        // Ya existe en Supabase, actualiza el registro local con el UUID y márcala como sincronizada
        final updated = TransactionHive(
          id: remoteMatch.id,
          clientId: t.clientId,
          type: t.type,
          amount: t.amount,
          date: t.date,
          description: t.description,
          synced: true,
          pendingDelete: false,
          userId: t.userId,
        );
        await box.delete(t.id); // Elimina la local con id temporal
        await box.put(updated.id, updated); // Guarda con el UUID real
      } else {
        // No existe en Supabase, súbela normalmente
        final tx = Transaction.fromHive(t).copyWith(userId: userId);
        try {
          await _service.addTransaction(tx, userId, t.clientId);
          t.synced = true;
          await t.save();
        } catch (e, stack) {
          debugPrint(
            '[SYNC][ERROR] No se pudo subir la transacción offline con id ${t.id}: $e',
          );
          debugPrint('[SYNC][STACK] $stack');
          // Si falla, sigue offline
        }
      }
    }

    // Refuerzo: recarga desde Supabase y actualiza el estado local
    try {
      final remoteTxsReload = await _service.fetchTransactions(userId);
      // Marca como sincronizadas todas las que existen en Supabase
      for (final remote in remoteTxsReload) {
        final local = box.get(remote.id);
        if (local != null) {
          local.synced = true;
          local.pendingDelete = false;
          local.userId = userId;
          await local.save();
        }
      }
    } catch (_) {
      // Si falla la red, no pasa nada, ya se intentó sincronizar
    }

    await loadTransactions(userId);
  }
}

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';
import 'package:hive/hive.dart';
import '../models/transaction.dart';
import '../models/transaction_hive.dart';
import '../models/client_hive.dart';
import '../services/supabase_service.dart';

class TransactionProvider extends ChangeNotifier {
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
    // Guarda el userId más reciente
    _lastKnownUserId = userId;
    if (online) {
      try {
        await _service.addTransaction(tx, userId, clientId);
        // Guardar como sincronizada en Hive
        box.put(
          tx.id,
          TransactionHive(
            id: tx.id,
            clientId: tx.clientId,
            type: tx.type,
            amount: tx.amount,
            date: tx.date,
            description: tx.description,
            synced: true,
            pendingDelete: false,
            userId: userId,
          ),
        );
      } catch (_) {
        // Si falla la red, guardar como pendiente
        box.put(
          tx.id,
          TransactionHive(
            id: tx.id,
            clientId: tx.clientId,
            type: tx.type,
            amount: tx.amount,
            date: tx.date,
            description: tx.description,
            synced: false,
            pendingDelete: false,
            userId: userId,
          ),
        );
      }
    } else {
      // Guardar como pendiente de sincronizar
      box.put(
        tx.id,
        TransactionHive(
          id: tx.id,
          clientId: tx.clientId,
          type: tx.type,
          amount: tx.amount,
          date: tx.date,
          description: tx.description,
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
      await recalculateClientBalance(clientId);
      await loadTransactions(userId);
    } else {
      // Solo marca como pendiente de eliminar
      t.pendingDelete = true;
      t.synced = false;
      await t.save();
      await recalculateClientBalance(clientId);
      await loadTransactions(userId);
    }
  }

  /// Sincroniza los cambios locales pendientes cuando hay internet
  Future<void> syncPendingTransactions(String userId) async {
    if (!await isOnline()) return;
    final box = Hive.isBoxOpen('transactions')
        ? Hive.box<TransactionHive>('transactions')
        : await Hive.openBox<TransactionHive>('transactions');
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
    // Luego sincroniza las transacciones pendientes de agregar/editar
    final pending = box.values
        .where((t) => !t.synced && t.pendingDelete != true)
        .toList();
    for (final t in pending) {
      final tx = Transaction.fromHive(t).copyWith(userId: userId);
      try {
        await _service.addTransaction(tx, userId, t.clientId);
        t.synced = true;
        await t.save();
      } catch (_) {
        // Si falla, sigue offline
      }
    }

    // Refuerzo: recarga desde Supabase y actualiza el estado local
    try {
      final remoteTxs = await _service.fetchTransactions(userId);
      // Marca como sincronizadas todas las que existen en Supabase
      for (final remote in remoteTxs) {
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

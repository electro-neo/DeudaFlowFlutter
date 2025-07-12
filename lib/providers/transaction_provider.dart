import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import '../models/transaction.dart';
import '../models/transaction_hive.dart';
import '../services/supabase_service.dart';

class TransactionProvider extends ChangeNotifier {
  final SupabaseService _service = SupabaseService();
  List<Transaction> _transactions = [];
  List<Transaction> get transactions => _transactions;

  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) return false;
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
    final isOnline = await _isOnline();
    final box = await Hive.openBox<TransactionHive>('transactions');
    // MIGRACIÓN AUTOMÁTICA: Fuerza la escritura de los campos para todos los registros
    for (final t in box.values) {
      t.synced = t.synced;
      t.pendingDelete = t.pendingDelete;
      t.save();
    }
    if (isOnline) {
      try {
        // Online: usa Supabase y sincroniza Hive
        final remoteTxs = await _service.fetchTransactions(userId);
        // Mantén las transacciones locales no sincronizadas
        final localPending = box.values
            .where((t) => t.synced == false)
            .toList();
        // Elimina localmente las transacciones pendientes que nunca se sincronizaron y fueron eliminadas offline
        final localPendingToKeep = localPending
            .where((t) => t.id != null && t.id != '')
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
            ),
          );
        }
        // Vuelve a guardar las locales pendientes válidas
        for (final t in localPendingToKeep) {
          box.put(t.id, t);
        }
        // Refresca la lista desde Hive para asegurar que el estado synced es correcto
        _transactions = box.values.map((t) => Transaction.fromHive(t)).toList();
      } catch (e) {
        // Si falla la red, carga desde Hive
        _transactions = box.values.map((t) => Transaction.fromHive(t)).toList();
      }
    } else {
      // Offline: usa Hive
      _transactions = box.values.map((t) => Transaction.fromHive(t)).toList();
    }
    notifyListeners();
  }

  Future<void> addTransaction(
    Transaction tx,
    String userId,
    String clientId,
  ) async {
    // Siempre crea la transacción en Hive como pendiente de sincronizar (offline-first)
    final box = Hive.box<TransactionHive>('transactions');
    box.put(
      tx.id,
      TransactionHive(
        id: tx.id,
        clientId: tx.clientId,
        type: tx.type,
        amount: tx.amount,
        date: tx.date,
        description: tx.description,
        synced: false, // Siempre pendiente por sincronizar
      ),
    );
    await loadTransactions(userId);
  }

  Future<void> updateTransaction(Transaction tx, String userId) async {
    final isOnline = await _isOnline();
    if (isOnline) {
      try {
        await _service.updateTransaction(tx);
      } catch (_) {
        // Si falla la red, marca como no sincronizado
        final box = Hive.box<TransactionHive>('transactions');
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
      await loadTransactions(userId);
    } else {
      final box = Hive.box<TransactionHive>('transactions');
      final t = box.get(tx.id);
      if (t != null) {
        t
          ..type = tx.type
          ..amount = tx.amount
          ..date = tx.date
          ..synced = false;
        await t.save();
      }
      await loadTransactions(userId);
    }
  }

  Future<void> deleteTransaction(String transactionId, String userId) async {
    final isOnline = await _isOnline();
    if (isOnline) {
      try {
        await _service.deleteTransaction(transactionId);
      } catch (_) {
        // Si falla la red, elimina localmente pero marca como pendiente
        final box = Hive.box<TransactionHive>('transactions');
        await box.delete(transactionId);
      }
      await loadTransactions(userId);
    } else {
      final box = Hive.box<TransactionHive>('transactions');
      await box.delete(transactionId);
      await loadTransactions(userId);
    }
  }

  /// Sincroniza los cambios locales pendientes cuando hay internet
  Future<void> syncPendingTransactions(String userId) async {
    if (!await _isOnline()) return;
    final box = Hive.box<TransactionHive>('transactions');
    final pending = box.values.where((t) => !t.synced).toList();
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
    await loadTransactions(userId);
  }
}

import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/supabase_service.dart';

class TransactionProvider extends ChangeNotifier {
  final SupabaseService _service = SupabaseService();
  List<Transaction> _transactions = [];
  List<Transaction> get transactions => _transactions;

  Future<void> loadTransactions(String userId) async {
    try {
      _transactions = await _service.fetchTransactions(userId);
      debugPrint(
        '[TransactionProvider] Transacciones cargadas: \\${_transactions.length}',
      );
    } catch (e, s) {
      debugPrint(
        '[TransactionProvider] Error al cargar transacciones: \\${e.toString()}',
      );
      debugPrintStack(stackTrace: s);
      _transactions = [];
    }
    notifyListeners();
  }

  Future<void> addTransaction(
    Transaction tx,
    String userId,
    String clientId,
  ) async {
    await _service.addTransaction(tx, userId, clientId);
    await loadTransactions(userId);
  }

  Future<void> updateTransaction(Transaction tx, String userId) async {
    await _service.updateTransaction(tx);
    await loadTransactions(userId);
  }

  Future<void> deleteTransaction(String transactionId, String userId) async {
    await _service.deleteTransaction(transactionId);
    await loadTransactions(userId);
  }
}

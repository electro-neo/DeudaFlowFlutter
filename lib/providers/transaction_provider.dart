import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/supabase_service.dart';

class TransactionProvider extends ChangeNotifier {
  final SupabaseService _service = SupabaseService();
  List<Transaction> _transactions = [];
  List<Transaction> get transactions => _transactions;

  Future<void> loadTransactions(String userId) async {
    _transactions = await _service.fetchTransactions(userId);
    notifyListeners();
  }

  Future<void> addTransaction(Transaction tx, String userId, String clientId) async {
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

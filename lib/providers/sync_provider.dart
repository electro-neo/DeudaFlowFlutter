import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';

import 'client_provider.dart';
import 'transaction_provider.dart';

enum SyncStatus { idle, waiting, syncing, success, error }

class SyncProvider extends ChangeNotifier {
  /// Refuerza el estado inicial de conexión al crear el provider
  Future<void> initializeConnectionStatus() async {
    final result = await Connectivity().checkConnectivity();
    final online = result != ConnectivityResult.none;
    _isOnline = online;
    notifyListeners();
  }

  late StreamSubscription _subscription;
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;
  int _progress = 0;
  int get progress => _progress;
  String? _lastError;
  String? get lastError => _lastError;

  String? _userId;
  String? get userId => _userId;

  void _setStatus(SyncStatus status, {int progress = 0, String? error}) {
    _status = status;
    _progress = progress;
    _lastError = error;
    notifyListeners();
  }

  Future<void> retrySync(BuildContext context) async {
    if (_userId != null) {
      await _syncAll(context, _userId!);
    }
  }

  Future<void> _syncAll(BuildContext context, String userId) async {
    try {
      _setStatus(SyncStatus.waiting);
      await Future.delayed(const Duration(milliseconds: 400));
      _setStatus(SyncStatus.syncing, progress: 0);
      // Sincroniza clientes
      await Provider.of<ClientProvider>(
        context,
        listen: false,
      ).syncPendingClients(userId);
      _setStatus(SyncStatus.syncing, progress: 50);
      // Sincroniza transacciones
      await Provider.of<TransactionProvider>(
        context,
        listen: false,
      ).syncPendingTransactions(userId);
      _setStatus(SyncStatus.syncing, progress: 100);
      await Future.delayed(const Duration(milliseconds: 400));
      _setStatus(SyncStatus.success);
      await Future.delayed(const Duration(seconds: 2));
      _setStatus(SyncStatus.idle);
    } catch (e) {
      _setStatus(SyncStatus.error, error: e.toString());
    }
  }

  void startSync(BuildContext context, String userId) {
    _userId = userId;
    _subscription = Connectivity().onConnectivityChanged.listen((result) async {
      final online = result != ConnectivityResult.none;
      if (online && !_isOnline) {
        // Se acaba de reconectar: sincroniza clientes y transacciones pendientes con feedback
        await _syncAll(context, userId);
      }
      _isOnline = online;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

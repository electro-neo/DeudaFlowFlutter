import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:hive/hive.dart';
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
      // Solo sincroniza si pasamos de offline a online
      if (online && !_isOnline) {
        print(
          '[SYNC][PROVIDER] Reconectado a internet. Iniciando sincronización de clientes y transacciones...',
        );
        await _syncAll(context, userId);
        // Refuerzo: recargar clientes solo cuando no haya pendientes de eliminar
        try {
          final clientProvider = Provider.of<ClientProvider>(
            context,
            listen: false,
          );
          int intentos = 0;
          bool hayPendientes;
          do {
            await clientProvider.loadClients(userId);
            final box = await Hive.openBox('clients');
            hayPendientes = box.values.any((c) => c.pendingDelete == true);
            if (hayPendientes) {
              print(
                '[SYNC][PROVIDER] Esperando a que se eliminen todos los clientes pendientes... (intento ${intentos + 1})',
              );
              await Future.delayed(const Duration(milliseconds: 500));
            }
            intentos++;
          } while (hayPendientes && intentos < 8);
        } catch (e) {
          print(
            '[SYNC][PROVIDER][ERROR] Error recargando clientes tras sincronizar: $e',
          );
        }
      }
      if (!online && _isOnline) {
        print('[SYNC][PROVIDER] Sin conexión a internet. Modo offline.');
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

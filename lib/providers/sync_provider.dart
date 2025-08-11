import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'client_provider.dart';
import 'transaction_provider.dart';
import 'currency_provider.dart';

import '../models/client_hive.dart';
import '../models/transaction_hive.dart';
import '../services/session_authority_service.dart';

enum SyncStatus { idle, waiting, syncing, success, error }

class SyncProvider extends ChangeNotifier {
  /// Devuelve el total de sincronizaciones pendientes (clientes y transacciones: altas, ediciones, eliminaciones)
  Future<int> getTotalPendings() async {
    final clientBox = Hive.isBoxOpen('clients')
        ? Hive.box<ClientHive>('clients')
        : await Hive.openBox<ClientHive>('clients');
    final txBox = Hive.isBoxOpen('transactions')
        ? Hive.box<TransactionHive>('transactions')
        : await Hive.openBox<TransactionHive>('transactions');

    // Solo cuenta como pendiente si:
    // - Cliente: no está sincronizado Y no existe en Supabase (id no UUID)
    // - Cliente: está pendiente de eliminar
    final pendingClients = clientBox.values.where((c) {
      final isLocalId = c.id.length != 36;
      return (isLocalId || c.synced == false || c.pendingDelete == true);
    }).length;

    // Transacciones: cuenta TODAS las que no están sincronizadas o están pendingDelete
    final pendingTxs = txBox.values.where((t) {
      return t.synced == false || t.pendingDelete == true;
    }).length;

    return pendingClients + pendingTxs;
  }

  /// Refuerza el estado inicial de conexión al crear el provider
  Future<void> initializeConnectionStatus() async {
    final result = await Connectivity().checkConnectivity();
    final online = !result.contains(ConnectivityResult.none);
    _isOnline = online;
    notifyListeners();
  }

  late StreamSubscription<List<ConnectivityResult>> _subscription;
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

  ///
  /// NOTA IMPORTANTE SOBRE EL USO DE BuildContext EN PROVIDERS:
  /// ----------------------------------------------------------
  /// El uso de `context` tras un await aquí está protegido por:
  ///   if (context is Element && !context.mounted) return;
  /// Esto es seguro en providers y ChangeNotifier, aunque el linter de Flutter
  /// muestre advertencia. No es posible usar `mounted` como en un State.
  /// Puedes ignorar el warning `use_build_context_synchronously` en este contexto.
  Future<void> _syncAll(BuildContext context, String userId) async {
    try {
      if (context is Element && !context.mounted) return;
      // Validar device_id antes de sincronizar
      final ok = await SessionAuthorityService.instance
          .validateDeviceAuthorityOrLogout(context, userId);
      if (!ok) return;
      final clientProvider = Provider.of<ClientProvider>(
        context,
        listen: false,
      );
      final transactionProvider = Provider.of<TransactionProvider>(
        context,
        listen: false,
      );
      final currencyProvider = Provider.of<CurrencyProvider>(
        context,
        listen: false,
      );

      _setStatus(SyncStatus.waiting);
      await Future.delayed(const Duration(milliseconds: 400));
      _setStatus(SyncStatus.syncing, progress: 0);

      // Sincroniza clientes
      await clientProvider.syncPendingClients(userId);
      _setStatus(SyncStatus.syncing, progress: 45);

      // Sincroniza transacciones
      await transactionProvider.syncPendingTransactions(userId);
      _setStatus(SyncStatus.syncing, progress: 90);

      // Sincroniza tasas de cambio (reutilizando la lógica de carga)
      await currencyProvider.loadInitialData();
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
      final online = !result.contains(ConnectivityResult.none);
      // Solo sincroniza si pasamos de offline a online
      if (online && !_isOnline) {
        debugPrint(
          '[SYNC][PROVIDER] Reconectado a internet. Iniciando sincronización completa...',
        );
        if (context is Element && !context.mounted) return;
        // Verificación de autoridad de dispositivo antes de cualquier sincronización
        final state = await SessionAuthorityService.instance.evaluate(
          userId: userId,
          hasInternet: true,
        );
        bool canContinue = true;
        if (state == AuthorityState.conflict) {
          // Detecta si veníamos en estado autorizado offline
          final wasAuthorizedOffline = await SessionAuthorityService.instance
              .wasAuthorizedOffline();
          canContinue = await SessionAuthorityService.instance
              .handleConflictDialog(
                context,
                userId,
                wasAuthorizedOffline: wasAuthorizedOffline,
              );
        } else {
          // Si remoto vacío, fijar a este dispositivo
          final localId = await SessionAuthorityService.instance
              .getOrCreateLocalDeviceId();
          final remote = await SessionAuthorityService.instance
              .fetchServerDeviceId(userId);
          if (remote == null || remote.isEmpty) {
            await SessionAuthorityService.instance.setServerDeviceId(
              userId,
              localId,
            );
          }
          await SessionAuthorityService.instance.markSessionFlag('authorized');
        }
        if (!canContinue) {
          _isOnline = online; // actualiza estado y termina
          notifyListeners();
          return;
        }

        // Sincroniza las tasas de cambio primero. Esto es crucial porque `loadInitialRates`
        // contiene la lógica para enviar (push) las tasas locales si se modificaron offline.
        await Provider.of<CurrencyProvider>(
          context,
          listen: false,
        ).loadInitialData();

        await _syncAll(context, userId);
        // Refuerzo: recargar clientes solo cuando no haya pendientes de eliminar
        try {
          if (context is Element && !context.mounted) return;
          // ignore: use_build_context_synchronously
          // NOTA: Este warning aparece porque el linter de Flutter no reconoce el chequeo de 'mounted' en un ChangeNotifier.
          // El uso de context aquí es seguro porque se verifica 'context.mounted' antes de cada uso tras un await.
          // Puedes ignorar este warning: no afecta la ejecución ni la seguridad del código.
          final clientProvider = Provider.of<ClientProvider>(
            // ignore: use_build_context_synchronously
            context,
            listen: false,
          );
          int intentos = 0;
          bool hayPendientes;
          do {
            if (context is Element && !context.mounted) return;
            // ignore: use_build_context_synchronously
            await clientProvider.loadClients(userId);
            final box = await Hive.openBox<ClientHive>('clients');
            hayPendientes = box.values.any((c) => c.pendingDelete == true);
            if (hayPendientes) {
              debugPrint(
                '[SYNC][PROVIDER] Esperando a que se eliminen todos los clientes pendientes... (intento ${intentos + 1})',
              );
              await Future.delayed(const Duration(milliseconds: 500));
            }
            intentos++;
          } while (hayPendientes && intentos < 8);
        } catch (e) {
          debugPrint(
            '[SYNC][PROVIDER][ERROR] Error recargando clientes tras sincronizar: $e',
          );
        }
      }
      if (!online && _isOnline) {
        debugPrint('[SYNC][PROVIDER] Sin conexión a internet. Modo offline.');
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

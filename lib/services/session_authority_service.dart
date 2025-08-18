import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client_hive.dart';
import '../models/transaction_hive.dart';
import '../services/supabase_service.dart';
import '../main.dart';
import 'package:provider/provider.dart';
import '../providers/client_provider.dart';
import '../providers/transaction_provider.dart';

/// Representa el estado de autoridad evaluado.
/// Usado por Login y por SyncProvider durante reconexiones.
enum AuthorityState {
  authorized,
  unverifiedOffline,
  authorizedOffline,
  conflict,
}

/// Servicio centralizado para controlar "sesión única por dispositivo".
///
/// Objetivos clave:
/// - Generar y persistir un deviceId local (Hive box 'session').
/// - Consultar/establecer el device_id remoto en Supabase (tabla user_settings, key='device_id').
/// - Evaluar el estado de autoridad según la conectividad y los valores local/remoto.
/// - Proveer utilidades para detectar cambios locales pendientes y para descartar locales y recargar desde servidor.
///
/// Notas de diseño:
/// - No agrega dependencias nuevas; usa Hive y Supabase ya presentes.
/// - Mantiene los cambios acotados para no romper otros flujos.
/// - No limpia el device_id del servidor al cerrar sesión; otro dispositivo puede "reclamar" reemplazándolo.
/// Representa el estado de autoridad evaluado.
/// Usado por Login y por SyncProvider durante reconexiones.

class SessionAuthorityService {
  /// Cierra sesión y detiene el listener de device_id en tiempo real.
  Future<void> signOutAndDisposeListener() async {
    disposeDeviceIdListener();
    await Supabase.instance.client.auth.signOut();
  }

  // --- Realtime device_id listener ---
  RealtimeChannel? _deviceIdChannel;

  /// Inicia la escucha en tiempo real del device_id para el usuario dado.
  /// Si el device_id remoto cambia y no coincide con el local, dispara la lógica de conflicto en tiempo real.
  void listenToDeviceIdChanges(String userId, BuildContext context) {
    _deviceIdChannel?.unsubscribe();

    _deviceIdChannel = Supabase.instance.client
        .channel('public:user_settings')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'user_settings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            debugPrint(
              '[AUTH-DEVICE][Realtime] Evento recibido: newRecord =\n${payload.newRecord.toString()}',
            );
            final newDeviceId =
                (payload.newRecord['value']?['device_id']) as String?;
            debugPrint(
              '[AUTH-DEVICE][Realtime] newDeviceId extraído: '
              '[33m$newDeviceId[0m',
            );
            if (newDeviceId != null) {
              final localId = await getOrCreateLocalDeviceId();
              debugPrint(
                '[AUTH-DEVICE][Realtime] localId actual: '
                '[36m$localId[0m',
              );
              if (newDeviceId != localId) {
                debugPrint(
                  '[AUTH-DEVICE][Realtime] ¡Conflicto detectado! Ejecutando validateDeviceAuthorityOrLogout...',
                );
                // Reutiliza la lógica de conflicto
                await validateDeviceAuthorityOrLogout(context, userId);
              } else {
                debugPrint(
                  '[AUTH-DEVICE][Realtime] device_id coincide, no hay conflicto.',
                );
              }
            } else {
              debugPrint(
                '[AUTH-DEVICE][Realtime] newDeviceId es null, no se procesa.',
              );
            }
          },
        )
        .subscribe();
  }

  /// Detiene la escucha en tiempo real del device_id.
  void disposeDeviceIdListener() {
    _deviceIdChannel?.unsubscribe();
    _deviceIdChannel = null;
  }

  /// Valida que el device_id local coincida con el remoto antes de sincronizar.
  /// Si no coincide, muestra un diálogo y cierra sesión automáticamente tras 4 segundos.
  Future<bool> validateDeviceAuthorityOrLogout(
    BuildContext context,
    String userId,
  ) async {
    final localId = await getOrCreateLocalDeviceId();
    final remoteId = await fetchServerDeviceId(userId);
    debugPrint(
      '[AUTH-DEVICE][validateDeviceAuthorityOrLogout] localId: $localId, remoteId: $remoteId',
    );
    if (remoteId != null && remoteId.isNotEmpty && remoteId != localId) {
      debugPrint(
        '[AUTH-DEVICE][validateDeviceAuthorityOrLogout] Conflicto detectado, context: $context',
      );
      // Si el context local no está montado, usar navigatorKey.currentContext como fallback global
      // Esto permite mostrar diálogos o navegar incluso si el widget original ya no existe
      BuildContext? safeContext = context;
      if (context is Element && !context.mounted) {
        debugPrint(
          '[AUTH-DEVICE][validateDeviceAuthorityOrLogout] Context no montado, usando navigatorKey.currentContext como fallback.',
        );
        safeContext = navigatorKey.currentContext;
        if (safeContext == null) {
          debugPrint(
            '[AUTH-DEVICE][validateDeviceAuthorityOrLogout] navigatorKey.currentContext también es null, abortando.',
          );
          return false;
        }
      }
      // Detectar si es reconexión tras autorizado offline
      final box = await Hive.openBox('session');
      final prevFlag = box.get(kSessionFlagKey);
      final wasAuthorizedOffline = prevFlag == 'authorized';
      debugPrint(
        '[AUTH-DEVICE][validateDeviceAuthorityOrLogout] wasAuthorizedOffline: $wasAuthorizedOffline',
      );
      if (wasAuthorizedOffline) {
        debugPrint(
          '[AUTH-DEVICE][validateDeviceAuthorityOrLogout] Mostrando diálogo de conflicto (reconexión offline)',
        );
        // Mostrar diálogo de opciones en vez de cerrar sesión automática
        final ok = await SessionAuthorityService.instance.handleConflictDialog(
          // ignore: use_build_context_synchronously
          safeContext,
          userId,
          isLoginFlow: false,
          wasAuthorizedOffline: true,
        );
        debugPrint(
          '[AUTH-DEVICE][validateDeviceAuthorityOrLogout] handleConflictDialog retornó: $ok',
        );
        return ok;
      }
      debugPrint(
        '[AUTH-DEVICE][validateDeviceAuthorityOrLogout] Mostrando diálogo de cierre de sesión automática',
      );
      // Si no es reconexión offline, cerrar sesión automática
      await showDialog(
        // ignore: use_build_context_synchronously
        context: safeContext,
        barrierDismissible: false,
        builder: (ctx) {
          Future.delayed(const Duration(seconds: 4), () async {
            // ignore: use_build_context_synchronously
            if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
            try {
              await signOutAndDisposeListener();
            } catch (_) {}
            // Navegar a login tras cerrar sesión
            try {
              navigatorKey.currentState?.pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            } catch (_) {}
          });
          return AlertDialog(
            title: const Text('Sesión cerrada por seguridad'),
            content: const Text(
              'Tu cuenta ha sido activada en otro equipo. Por seguridad, se cerrará la sesión en este equipo.',
            ),
          );
        },
      );
      debugPrint(
        '[AUTH-DEVICE][validateDeviceAuthorityOrLogout] showDialog de cierre de sesión automática mostrado',
      );
      return false;
    }
    debugPrint(
      '[AUTH-DEVICE][validateDeviceAuthorityOrLogout] No hay conflicto, todo ok.',
    );
    return true;
  }

  SessionAuthorityService._();
  static final SessionAuthorityService instance = SessionAuthorityService._();

  /// Estados de autoridad de sesión.
  ///
  /// authorized: Remoto coincide (o estaba vacío y ya se fijó) con el deviceId local.
  /// unverifiedOffline: Se accedió sin conexión y nunca se confirmó autoridad.
  /// authorizedOffline: Estaba autorizado y se perdió conexión (permite operar).
  /// conflict: El device_id remoto existe y NO coincide con el local.
  @visibleForTesting
  static const String kSessionFlagKey = 'session_state';

  /// Obtiene o crea un deviceId local estable.
  /// Persistencia: Hive box 'session', clave 'device_id'.
  Future<String> getOrCreateLocalDeviceId() async {
    final box = await Hive.openBox('session');
    final existing = box.get('device_id');
    if (existing is String && existing.trim().isNotEmpty) return existing;
    // Genera un id simple y suficientemente único sin dependencia extra.
    final rnd = Random();
    final id =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-${rnd.nextInt(1 << 32).toRadixString(16)}';
    await box.put('device_id', id);
    return id;
  }

  /// Lee el device_id remoto desde Supabase (user_settings, key='device_id').
  Future<String?> fetchServerDeviceId(String userId) async {
    try {
      // Centralizado en SupabaseService
      return await SupabaseService().getDeviceId();
    } catch (e) {
      debugPrint('[AUTH-DEVICE] fetchServerDeviceId error: $e');
      return null;
    }
  }

  /// Establece/actualiza el device_id remoto en Supabase (upsert por (user_id,key)).
  Future<void> setServerDeviceId(String userId, String deviceId) async {
    // Centralizado en SupabaseService
    await SupabaseService().saveDeviceId(deviceId);
  }

  /// Evalúa el estado de autoridad dadas la conectividad y el userId actual.
  /// - hasInternet=false: si hay flag 'authorized' previo -> authorizedOffline; si no -> unverifiedOffline.
  /// - hasInternet=true: compara deviceId local vs remoto -> authorized o conflict.
  Future<AuthorityState> evaluate({
    required String userId,
    required bool hasInternet,
  }) async {
    final sessionBox = await Hive.openBox('session');
    final localFlag = sessionBox.get(kSessionFlagKey);
    if (!hasInternet) {
      if (localFlag == 'authorized') return AuthorityState.authorizedOffline;
      return AuthorityState.unverifiedOffline;
    }
    final localId = await getOrCreateLocalDeviceId();
    final remoteId = await fetchServerDeviceId(userId);
    if (remoteId == null || remoteId.isEmpty || remoteId == localId) {
      return AuthorityState.authorized;
    }
    return AuthorityState.conflict;
  }

  /// Marca una bandera de sesión en Hive 'session' para reflejar el estado más reciente.
  /// Valores sugeridos: 'authorized' | 'authorized_offline' | 'unverified_offline'.
  Future<void> markSessionFlag(String value) async {
    final box = await Hive.openBox('session');
    await box.put(kSessionFlagKey, value);
  }

  /// Indica si la app estuvo en estado 'authorized' antes de perder conexión.
  Future<bool> wasAuthorizedOffline() async {
    final box = await Hive.openBox('session');
    final val = box.get(kSessionFlagKey);
    return val == 'authorized';
  }

  /// Devuelve true si existen cambios locales pendientes (clientes o transacciones) no sincronizados
  /// o marcados para eliminar.
  Future<bool> hasLocalPendingChanges() async {
    final clientBox = Hive.isBoxOpen('clients')
        ? Hive.box<ClientHive>('clients')
        : await Hive.openBox<ClientHive>('clients');
    final txBox = Hive.isBoxOpen('transactions')
        ? Hive.box<TransactionHive>('transactions')
        : await Hive.openBox<TransactionHive>('transactions');
    final pendingClients = clientBox.values.any(
      (c) => !c.synced || c.pendingDelete,
    );
    final pendingTxs = txBox.values.any((t) => !t.synced || t.pendingDelete);
    return pendingClients || pendingTxs;
  }

  /// Descarta cambios locales no sincronizados y recarga datos limpios desde Supabase.
  /// Mantiene cualquier dato que ya esté sincronizado en el servidor.
  /// No toca el device_id remoto.
  Future<void> discardLocalChangesAndReload(String userId) async {
    final supa = SupabaseService();
    // 1) Recupera datos remotos
    final remoteClients = await supa.fetchClients(userId);
    final remoteTxs = await supa.fetchTransactions(userId);

    // 2) Limpia Hive y repuebla solo con datos remotos como sincronizados
    final clientBox = Hive.isBoxOpen('clients')
        ? Hive.box<ClientHive>('clients')
        : await Hive.openBox<ClientHive>('clients');
    final txBox = Hive.isBoxOpen('transactions')
        ? Hive.box<TransactionHive>('transactions')
        : await Hive.openBox<TransactionHive>('transactions');

    await clientBox.clear();
    for (final c in remoteClients) {
      await clientBox.put(
        c.id,
        ClientHive(
          id: c.id,
          name: c.name,
          address: c.address,
          phone: c.phone,
          balance: c.balance,
          synced: true,
          pendingDelete: false,
          currencyCode: 'VES',
        ),
      );
    }

    await txBox.clear();
    for (final t in remoteTxs) {
      await txBox.put(
        t.id,
        TransactionHive(
          id: t.id,
          clientId: t.clientId,
          type: t.type,
          amount: t.amount,
          date: t.createdAt,
          description: t.description,
          synced: true,
          pendingDelete: false,
          userId: userId,
          currencyCode: t.currencyCode,
          localId: t.localId,
          anchorUsdValue: t.anchorUsdValue,
        ),
      );
    }
  }

  /// Muestra un diálogo de conflicto dentro de la app y resuelve según la opción del usuario.
  ///
  /// Debe llamarse en contexto con conexión, antes de sincronizar.
  /// Retorna true si, tras la resolución, es seguro continuar con sincronización.
  Future<bool> handleConflictDialog(
    BuildContext context,
    String userId, {
    bool isLoginFlow = false,
    bool wasAuthorizedOffline = false,
  }) async {
    if (context is Element && !context.mounted) return false;
    final hasPending = await hasLocalPendingChanges();

    final result = await showDialog<String>(
      // ignore: use_build_context_synchronously
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final title = isLoginFlow
            ? 'Tu cuenta está activa en otro dispositivo'
            : 'Conflicto de dispositivo al reconectar';
        final contentText = () {
          if (isLoginFlow) {
            return hasPending
                ? 'Ya existe otro dispositivo usando tu cuenta y aquí hay cambios sin sincronizar. Elige cómo proceder.'
                : '¿Qué deseas hacer?';
          }
          // Reconexión
          if (wasAuthorizedOffline) {
            return hasPending
                ? 'Estabas trabajando offline. Al reconectar detectamos otro dispositivo como principal y hay cambios sin sincronizar. Elige cómo proceder.'
                : 'Estabas offline y al reconectar detectamos otro dispositivo como principal. ¿Qué deseas hacer?';
          }
          return hasPending
              ? 'Se detectó otro dispositivo como principal y hay cambios sin sincronizar. Elige cómo proceder.'
              : 'Se detectó otro dispositivo como principal. ¿Qué deseas hacer?';
        }();
        return AlertDialog(
          title: Text(title),
          content: Text(contentText),
          actions: [
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text(
                'Borrar cambios locales y continuar',
                style: TextStyle(fontSize: 13),
              ),
              onPressed: () => Navigator.of(ctx).pop('discard'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.sync, size: 18),
              label: const Text(
                'Guardar cambios locales y continuar',
                style: TextStyle(fontSize: 13),
              ),
              onPressed: () => Navigator.of(ctx).pop('claim'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout, size: 18, color: Colors.white),
              label: const Text(
                'Cerrar sesión',
                style: TextStyle(fontSize: 13, color: Colors.white),
              ),
              onPressed: () => Navigator.of(ctx).pop('logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result == 'claim') {
      final localId = await getOrCreateLocalDeviceId();
      await setServerDeviceId(userId, localId);
      await markSessionFlag('authorized');
      // --- Sincroniza automáticamente los cambios locales pendientes ---
      try {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          final clientProvider = Provider.of<ClientProvider>(
            ctx,
            listen: false,
          );
          final txProvider = Provider.of<TransactionProvider>(
            ctx,
            listen: false,
          );
          await clientProvider.syncPendingClients(userId);
          await txProvider.syncPendingTransactions(userId);
        }
      } catch (e, st) {
        debugPrint(
          '[AUTH-DEVICE][handleConflictDialog] Error al sincronizar automáticamente: $e\n$st',
        );
      }
      return true; // se puede continuar con sync
    }
    if (result == 'discard') {
      await discardLocalChangesAndReload(userId);
      // También reclamar autoridad en este equipo para evitar cierre automático.
      final localId = await getOrCreateLocalDeviceId();
      await setServerDeviceId(userId, localId);
      await markSessionFlag('authorized');
      return true; // datos limpios, seguir con sync ligera si aplica
    }
    if (result == 'logout') {
      try {
        await signOutAndDisposeListener();
        // Cerrar el diálogo antes de navegar
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        // Navegar a login tras cerrar sesión en el siguiente microtask
        Future.microtask(() {
          final ctx = navigatorKey.currentContext;
          if (ctx != null) {
            Navigator.of(
              ctx,
            ).pushNamedAndRemoveUntil('/login', (route) => false);
          }
        });
      } catch (_) {}
      return false;
    }
    return false;
  }
}

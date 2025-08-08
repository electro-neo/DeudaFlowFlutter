import 'package:flutter/material.dart';

/// Estado y mensaje temporal de sincronización para un cliente
/// Usar en ClientsScreen y ClientCard

enum SyncMessageType { syncing, synced }

class SyncMessageState {
  bool get isSyncing =>
      type == SyncMessageType.syncing && message == 'Sincronizando';
  bool get isSynced => type == SyncMessageType.synced;
  final SyncMessageType type;
  final String message;
  final IconData icon;
  final Color color;
  const SyncMessageState(this.type, this.message, this.icon, this.color);

  factory SyncMessageState.syncing() => SyncMessageState(
    SyncMessageType.syncing,
    'Sincronizando',
    Icons.sync,
    Colors.blue,
  );
  factory SyncMessageState.synced() => SyncMessageState(
    SyncMessageType.synced,
    'Sincronizado',
    Icons.cloud_done,
    const Color.fromARGB(255, 76, 175, 78),
  );

  /// Crea un estado de mensaje por defecto según el estado del cliente
  /// Si el cliente está sincronizado y no pendiente de eliminar, retorna null (no mostrar mensaje)
  static SyncMessageState? fromClient(dynamic client) {
    if (client.pendingDelete == true) {
      // DEBUG: Verifica si el cliente está marcado como pendiente de eliminar
      debugPrint(
        '[SYNC_MESSAGE_STATE] Cliente marcado como pendingDelete: id=${client.id}, name=${client.name}, synced=${client.synced}',
      );
      return SyncMessageState(
        SyncMessageType.syncing,
        'Pendiente de eliminar',
        Icons.delete_forever,
        Colors.red[700] ?? Colors.red,
      );
    } else if (client.synced != true) {
      return SyncMessageState(
        SyncMessageType.syncing,
        'Pendiente por sincronizar',
        Icons.sync,
        Colors.orange[800] ?? Colors.orange,
      );
    } else {
      // Cliente sincronizado: no mostrar mensaje
      return null;
    }
  }
}

/// Estado y mensaje temporal de sincronización para una transacción
/// Usar en TransactionCard
enum SyncMessageTypeTX { syncing, synced }

class SyncMessageStateTX {
  bool get isSyncing =>
      type == SyncMessageTypeTX.syncing && message == 'Sincronizando';
  bool get isSynced => type == SyncMessageTypeTX.synced;
  final SyncMessageTypeTX type;
  final String message;
  final IconData icon;
  final Color color;
  const SyncMessageStateTX(this.type, this.message, this.icon, this.color);

  factory SyncMessageStateTX.syncing() => SyncMessageStateTX(
    SyncMessageTypeTX.syncing,
    'Sincronizando',
    Icons.sync,
    Colors.blue,
  );
  factory SyncMessageStateTX.synced() => SyncMessageStateTX(
    SyncMessageTypeTX.synced,
    'Sincronizado',
    Icons.cloud_done,
    const Color.fromARGB(255, 76, 175, 78),
  );

  /// Crea un estado de mensaje por defecto según el estado de la transacción
  /// Si la transacción está sincronizada y no pendiente de eliminar, retorna null (no mostrar mensaje)
  static SyncMessageStateTX? fromTransaction(
    dynamic tx, {
    bool clientPendingDelete = false,
    bool isOffline = false,
  }) {
    if (clientPendingDelete && isOffline) {
      return SyncMessageStateTX(
        SyncMessageTypeTX.syncing,
        'Pendiente por eliminar',
        Icons.delete_forever,
        Colors.red[700] ?? Colors.red,
      );
    } else if (tx.synced == false) {
      return SyncMessageStateTX(
        SyncMessageTypeTX.syncing,
        'Pendiente por sincronizar',
        Icons.sync,
        Colors.orange[800] ?? Colors.orange,
      );
    } else if (tx.synced == true) {
      // Ya sincronizado: no mostrar mensaje permanente
      return null;
    } else {
      // No mostrar mensaje si no se reconoce el estado
      return null;
    }
  }
}

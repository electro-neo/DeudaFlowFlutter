import 'package:flutter/material.dart';

/// Estado y mensaje temporal de sincronización para un cliente
/// Usar en ClientsScreen y ClientCard

enum SyncMessageType { syncing, synced }

class SyncMessageState {
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

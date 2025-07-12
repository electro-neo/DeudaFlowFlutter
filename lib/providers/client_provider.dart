import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import '../models/client.dart';
import '../models/client_hive.dart';
import '../services/supabase_service.dart';

class ClientProvider extends ChangeNotifier {
  /// Sincroniza los clientes locales pendientes cuando hay internet
  Future<void> syncPendingClients(String userId) async {
    if (!await _isOnline()) return;
    final box = Hive.box<ClientHive>('clients');
    // 1. LOG: Mostrar todos los clientes marcados para eliminar
    final pendingDeletes = box.values
        .where((c) => c.pendingDelete == true)
        .toList();
    if (pendingDeletes.isNotEmpty) {
      print(
        '[SYNC][INFO] Clientes marcados para eliminar (pendingDelete=true):',
      );
      for (final c in pendingDeletes) {
        print('  - id: ${c.id}, name: ${c.name}, synced: ${c.synced}');
      }
    }
    // 2. Procesar eliminaciones pendientes
    for (final c in pendingDeletes) {
      if (c.synced == false) {
        print(
          '[SYNC] Cliente ${c.id} nunca sincronizado, eliminado solo local.',
        );
        await c.delete();
        continue;
      }
      try {
        print('[SYNC] Intentando eliminar cliente ${c.id} de Supabase...');
        await _service.deleteClientAndTransactions(c.id);
        print(
          '[SYNC] Cliente ${c.id} eliminado de Supabase. Eliminando local...',
        );
        await c.delete();
      } catch (e) {
        print(
          '[SYNC][ERROR] No se pudo eliminar cliente ${c.id} de Supabase: $e',
        );
        // Si falla, sigue offline
      }
    }
    // 3. LOG: Mostrar clientes pendientes de sincronizar (creación/edición)
    final pending = box.values
        .where((c) => !c.synced && !c.pendingDelete)
        .toList();
    if (pending.isNotEmpty) {
      print(
        '[SYNC][INFO] Clientes pendientes de sincronizar (creación/edición):',
      );
      for (final c in pending) {
        print('  - id: ${c.id}, name: ${c.name}');
      }
    }
    // 4. Procesar creaciones/ediciones pendientes
    for (final c in pending) {
      final client = Client(
        id: c.id,
        name: c.name,
        email: c.email,
        phone: c.phone,
        balance: c.balance,
      );
      try {
        if (c.id.isNotEmpty) {
          // Si tiene id, intenta actualizar
          await _service.updateClient(client);
        } else {
          // Si no tiene id, crea nuevo
          await _service.addClient(client, userId);
        }
        c.synced = true;
        await c.save();
      } catch (_) {
        // Si falla, sigue offline
      }
    }
    await loadClients(userId);
  }

  final SupabaseService _service = SupabaseService();
  List<Client> _clients = [];
  List<Client> get clients => _clients;

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

  Future<void> loadClients(String userId) async {
    final isOnline = await _isOnline();
    final box = await Hive.openBox<ClientHive>('clients');
    // MIGRACIÓN AUTOMÁTICA: Fuerza la escritura de los campos para todos los clientes
    for (final c in box.values) {
      c.synced = c.synced;
      c.pendingDelete = c.pendingDelete;
      c.save();
    }
    if (isOnline) {
      try {
        // Online: usa Supabase y sincroniza Hive
        final remoteClients = await _service.fetchClients(userId);
        // Guarda los IDs de clientes locales pendientes de eliminar
        final pendingDeleteIds = box.values
            .where((c) => c.pendingDelete == true)
            .map((c) => c.id)
            .toSet();
        // Mantén los clientes locales no sincronizados ni pendientes de eliminar
        final localPending = box.values
            .where((c) => !c.synced && !c.pendingDelete)
            .toList();
        await box.clear();
        // Guarda los de Supabase como sincronizados, excepto los que están pendientes de eliminar localmente
        for (final c in remoteClients) {
          if (!pendingDeleteIds.contains(c.id)) {
            box.put(
              c.id,
              ClientHive(
                id: c.id,
                name: c.name,
                email: c.email,
                phone: c.phone,
                balance: c.balance,
                synced: true,
                pendingDelete: false,
              ),
            );
          }
        }
        // Vuelve a guardar los locales pendientes y los pendientes de eliminar
        for (final c in localPending) {
          box.put(c.id, c);
        }
        // También vuelve a guardar los pendientes de eliminar para que no se pierdan
        for (final c in box.values.where((c) => c.pendingDelete == true)) {
          box.put(c.id, c);
        }
        // Refresca la lista desde Hive para asegurar que el estado synced es correcto
        _clients = box.values
            .where((c) => c.pendingDelete != true)
            .map(
              (c) => Client(
                id: c.id,
                name: c.name,
                email: c.email,
                phone: c.phone,
                balance: c.balance,
              ),
            )
            .toList();
      } catch (e) {
        // Si falla la red, carga desde Hive
        _clients = box.values
            .where((c) => c.pendingDelete != true)
            .map(
              (c) => Client(
                id: c.id,
                name: c.name,
                email: c.email,
                phone: c.phone,
                balance: c.balance,
              ),
            )
            .toList();
      }
    } else {
      // Offline: usa Hive
      _clients = box.values
          .where((c) => c.pendingDelete != true)
          .map(
            (c) => Client(
              id: c.id,
              name: c.name,
              email: c.email,
              phone: c.phone,
              balance: c.balance,
            ),
          )
          .toList();
    }
    notifyListeners();
  }

  Future<void> addClient(Client client, String userId) async {
    // Siempre crea el cliente en Hive como pendiente de sincronizar (offline-first)
    final box = Hive.box<ClientHive>('clients');
    box.put(
      client.id,
      ClientHive(
        id: client.id,
        name: client.name,
        email: client.email,
        phone: client.phone,
        balance: client.balance,
        synced: false, // Siempre pendiente por sincronizar
        pendingDelete: false,
      ),
    );
    await loadClients(userId);
    // Si estamos online, sincroniza inmediatamente
    if (await _isOnline()) {
      await syncPendingClients(userId);
    }
  }

  Future<void> updateClient(Client client, String userId) async {
    // Siempre actualiza en Hive y marca como pendiente de sincronizar
    final box = Hive.box<ClientHive>('clients');
    final c = box.get(client.id);
    if (c != null) {
      c
        ..name = client.name
        ..email = client.email
        ..phone = client.phone
        ..balance = client.balance
        ..synced = false;
      await c.save();
    }
    await loadClients(userId);
    // Si estamos online, sincroniza inmediatamente
    if (await _isOnline()) {
      await syncPendingClients(userId);
    }
  }

  Future<void> deleteClient(String clientId, String userId) async {
    // Siempre marca como pendiente de eliminar en Hive
    final box = Hive.box<ClientHive>('clients');
    final c = box.get(clientId);
    if (c != null) {
      c.pendingDelete = true;
      await c.save();
    }
    await loadClients(userId);
    // Lanza la sincronización en segundo plano después de 2 segundos
    Future.delayed(const Duration(seconds: 2), () async {
      await syncPendingClients(userId);
    });
  }
}

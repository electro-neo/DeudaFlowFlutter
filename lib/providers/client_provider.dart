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
    // Sincroniza eliminaciones pendientes
    final pendingDeletes = box.values
        .where((c) => c.pendingDelete == true)
        .toList();
    for (final c in pendingDeletes) {
      if (c.synced == false) {
        // Nunca se sincronizó, elimínalo localmente sin intentar en Supabase
        await c.delete();
        continue;
      }
      try {
        await _service.deleteClientAndTransactions(c.id);
        await c.delete(); // Elimina localmente tras sincronizar
      } catch (_) {
        // Si falla, sigue offline
      }
    }
    // Sincroniza creaciones/ediciones pendientes
    final pending = box.values
        .where((c) => !c.synced && !c.pendingDelete)
        .toList();
    for (final c in pending) {
      final client = Client(
        id: c.id,
        name: c.name,
        email: c.email,
        phone: c.phone,
        balance: c.balance,
      );
      try {
        await _service.addClient(client, userId);
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
        // Mantén los clientes locales no sincronizados ni pendientes de eliminar
        final localPending = box.values
            .where((c) => !c.synced && !c.pendingDelete)
            .toList();
        await box.clear();
        // Guarda los de Supabase como sincronizados
        for (final c in remoteClients) {
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
        // Vuelve a guardar los locales pendientes
        for (final c in localPending) {
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
    await this.loadClients(userId);
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
    await this.loadClients(userId);
  }

  Future<void> deleteClient(String clientId, String userId) async {
    // Siempre marca como pendiente de eliminar en Hive
    final box = Hive.box<ClientHive>('clients');
    final c = box.get(clientId);
    if (c != null) {
      c.pendingDelete = true;
      await c.save();
    }
    await this.loadClients(userId);
  }
}

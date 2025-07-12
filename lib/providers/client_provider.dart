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
    if (isOnline) {
      try {
        // Online: usa Supabase y sincroniza Hive
        _clients = await _service.fetchClients(userId);
        final box = await Hive.openBox<ClientHive>('clients');
        await box.clear();
        for (final c in _clients) {
          box.put(
            c.id,
            ClientHive(
              id: c.id,
              name: c.name,
              email: c.email,
              phone: c.phone,
              balance: c.balance,
              synced: true,
            ),
          );
        }
      } catch (e) {
        // Si falla la red, carga desde Hive
        final box = await Hive.openBox<ClientHive>('clients');
        _clients = box.values
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
      final box = await Hive.openBox<ClientHive>('clients');
      _clients = box.values
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
    final isOnline = await _isOnline();
    final box = Hive.box<ClientHive>('clients');
    if (isOnline) {
      try {
        await _service.addClient(client, userId);
        box.put(
          client.id,
          ClientHive(
            id: client.id,
            name: client.name,
            email: client.email,
            phone: client.phone,
            balance: client.balance,
            synced: true,
            pendingDelete: false,
          ),
        );
      } catch (_) {
        // Si falla la red, guarda localmente como pendiente de registro
        box.put(
          client.id,
          ClientHive(
            id: client.id,
            name: client.name,
            email: client.email,
            phone: client.phone,
            balance: client.balance,
            synced: false,
            pendingDelete: false,
          ),
        );
      }
      await loadClients(userId);
    } else {
      box.put(
        client.id,
        ClientHive(
          id: client.id,
          name: client.name,
          email: client.email,
          phone: client.phone,
          balance: client.balance,
          synced: false,
          pendingDelete: false,
        ),
      );
      await loadClients(userId);
    }
  }

  Future<void> updateClient(Client client, String userId) async {
    final isOnline = await _isOnline();
    if (isOnline) {
      try {
        await _service.updateClient(client);
      } catch (_) {
        // Si falla la red, marca como no sincronizado
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
      }
      await loadClients(userId);
    } else {
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
    }
  }

  Future<void> deleteClient(String clientId, String userId) async {
    final isOnline = await _isOnline();
    final box = Hive.box<ClientHive>('clients');
    final c = box.get(clientId);
    if (isOnline) {
      try {
        await _service.deleteClientAndTransactions(clientId);
        if (c != null) await c.delete();
      } catch (_) {
        // Si falla la red, marca como pendiente de eliminar
        if (c != null) {
          c.pendingDelete = true;
          await c.save();
        }
      }
      await loadClients(userId);
    } else {
      // Solo marca como pendiente de eliminar
      if (c != null) {
        c.pendingDelete = true;
        await c.save();
      }
      await loadClients(userId);
    }
  }
}

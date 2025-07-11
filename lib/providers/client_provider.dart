import 'package:flutter/material.dart';
import '../models/client.dart';
import '../services/supabase_service.dart';
import '../models/transaction.dart';
import 'transaction_provider.dart';

class ClientProvider extends ChangeNotifier {
  final SupabaseService _service = SupabaseService();
  List<Client> _clients = [];
  List<Client> get clients => _clients;

  Future<void> loadClients(String userId) async {
    try {
      _clients = await _service.fetchClients(userId);
      debugPrint('[ClientProvider] Clientes cargados: \\${_clients.length}');
    } catch (e, s) {
      debugPrint(
        '[ClientProvider] Error al cargar clientes: \\${e.toString()}',
      );
      debugPrintStack(stackTrace: s);
      _clients = [];
    }
    notifyListeners();
  }

  Future<void> addClient(Client client, String userId) async {
    await _service.addClient(client, userId);
    await loadClients(userId);
  }

  Future<void> updateClient(Client client, String userId) async {
    await _service.updateClient(client);
    await loadClients(userId);
  }

  Future<void> deleteClient(String clientId, String userId) async {
    await _service.deleteClientAndTransactions(clientId);
    await loadClients(userId);
  }
}

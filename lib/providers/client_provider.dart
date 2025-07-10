import 'package:flutter/material.dart';
import '../models/client.dart';
import '../services/supabase_service.dart';

class ClientProvider extends ChangeNotifier {
  final SupabaseService _service = SupabaseService();
  List<Client> _clients = [];
  List<Client> get clients => _clients;

  Future<void> loadClients(String userId) async {
    _clients = await _service.fetchClients(userId);
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

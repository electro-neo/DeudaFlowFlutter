import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client.dart';
import '../models/transaction.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

  Future<List<Client>> fetchClients(String userId) async {
    final response = await _client
        .from('clients')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => Client.fromMap(e)).toList();
  }

  Future<List<Transaction>> fetchTransactions(String userId) async {
    final response = await _client
        .from('transactions')
        .select()
        .eq('user_id', userId);
    return (response as List).map((e) => Transaction.fromMap(e)).toList();
  }

  Future<String?> addClient(Client client, String userId) async {
    final now = DateTime.now().toIso8601String();
    final response = await _client
        .from('clients')
        .insert({
          'name': client.name,
          'email': client.email,
          'phone': client.phone,
          'balance': client.balance,
          'user_id': userId,
          'created_at': now,
          'updated_at': now,
        })
        .select('id')
        .single();
    // Devuelve el id generado por Supabase si existe
    if (response['id'] != null) {
      return response['id'].toString();
    }
    return null;
  }

  Future<void> updateClient(Client client) async {
    final now = DateTime.now().toIso8601String();
    await _client
        .from('clients')
        .update({
          'name': client.name,
          'email': client.email,
          'phone': client.phone,
          'balance': client.balance,
          'updated_at': now,
        })
        .eq('id', client.id);
  }

  Future<void> deleteClientAndTransactions(String clientId) async {
    try {
      // Elimina primero todas las transacciones asociadas a este cliente
      final txResponse = await _client
          .from('transactions')
          .delete()
          .eq('client_id', clientId);
      print(
        '[SUPABASE][DELETE] Transacciones eliminadas para cliente $clientId: $txResponse',
      );

      // Luego elimina el cliente
      final clientResponse = await _client
          .from('clients')
          .delete()
          .eq('id', clientId);
      print('[SUPABASE][DELETE] Cliente eliminado $clientId: $clientResponse');

      // Validación extra: si no se eliminó ningún cliente, avisar
      if (clientResponse is List && clientResponse.isEmpty) {
        print(
          '[SUPABASE][WARNING] Ningún cliente eliminado en Supabase para id: $clientId',
        );
      } else {
        print(
          '[SUPABASE][INFO] Cliente $clientId eliminado correctamente en Supabase.',
        );
      }

      // LOG extra: Verificar si el cliente sigue existiendo tras el intento de borrado
      final check = await _client.from('clients').select().eq('id', clientId);
      print('[SUPABASE][CHECK] Cliente $clientId tras borrado: $check');
    } catch (e, stack) {
      print(
        '[SUPABASE][ERROR] Error al eliminar cliente y transacciones para id $clientId: $e',
      );
      print('[SUPABASE][ERROR] Stacktrace: $stack');
      rethrow;
    }
  }

  Future<void> addTransaction(
    Transaction tx,
    String userId,
    String clientId,
  ) async {
    final now = DateTime.now().toIso8601String();
    await _client.from('transactions').insert({
      'client_id': clientId,
      'user_id': userId,
      'type': tx.type,
      'amount': tx.amount,
      'description': tx.description,
      'date': tx.date
          .toIso8601String(), // Usa la fecha seleccionada en el formulario
      'created_at': now,
    });
  }

  Future<void> updateTransaction(Transaction tx) async {
    await _client
        .from('transactions')
        .update({
          'type': tx.type,
          'amount': tx.amount,
          'description': tx.description,
          'date': tx.date.toIso8601String(),
          'created_at': tx.createdAt.toIso8601String(),
        })
        .eq('id', tx.id);
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _client.from('transactions').delete().eq('id', transactionId);
  }
}

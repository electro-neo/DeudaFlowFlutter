import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/client.dart';
import '../models/transaction.dart';

class SupabaseService {
  /// Actualiza solo el balance de un cliente en Supabase por id
  Future<void> updateClientBalance(String clientId, double balance) async {
    await _client
        .from('clients')
        .update({'balance': balance})
        .eq('id', clientId);
  }

  final _client = Supabase.instance.client;

  // --- Métodos para Tasas de Cambio ---

  Future<Map<String, double>> getExchangeRates() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return {};

      final response = await _client
          .from('user_settings')
          .select('value')
          .eq('user_id', userId)
          .eq('key', 'exchange_rates')
          .single();

      final rates = response['value'] as Map<String, dynamic>;
      return rates.map((key, value) => MapEntry(key, (value as num).toDouble()));
    } catch (e) {
      debugPrint('[SUPABASE][ERROR] No se pudieron cargar las tasas: $e');
      return {}; // Devuelve mapa vacío si no hay configuración o hay un error
    }
  }

  Future<void> saveExchangeRates(Map<String, double> rates) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client.from('user_settings').upsert({
        'user_id': userId,
        'key': 'exchange_rates',
        'value': rates,
      }, onConflict: 'user_id,key');
      debugPrint('[SUPABASE][SUCCESS] Tasas de cambio guardadas.');
    } catch (e) {
      debugPrint('[SUPABASE][ERROR] No se pudieron guardar las tasas: $e');
    }
  }

  // --- Métodos existentes ---

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
    // Solo incluir 'id' si es un UUID válido (36 caracteres)
    final Map<String, dynamic> data = {
      'name': client.name,
      'address': client.address,
      'phone': client.phone,
      'balance': client.balance,
      'user_id': userId,
      'created_at': now,
      'updated_at': now,
      'local_id': client.localId ?? client.id,
    };
    if (client.id.isNotEmpty && client.id.length == 36) {
      data['id'] = client.id;
    }
    final response = await _client
        .from('clients')
        .upsert(data, onConflict: 'local_id')
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
          'address': client.address,
          'phone': client.phone,
          'balance': client.balance,
          'updated_at': now,
        })
        .eq('id', client.id);
  }

  Future<bool> deleteClientAndTransactions(String clientId) async {
    try {
      // Elimina primero todas las transacciones asociadas a este cliente
      await _client.from('transactions').delete().eq('client_id', clientId);
      debugPrint(
        '[SUPABASE][DELETE] Intento de eliminar transacciones para cliente $clientId completado.',
      );

      // Luego elimina el cliente
      await _client.from('clients').delete().eq('id', clientId);
      debugPrint(
        '[SUPABASE][DELETE] Intento de eliminar cliente $clientId completado.',
      );

      // Validación: Espera un momento y verifica si el cliente sigue existiendo.
      await Future.delayed(const Duration(milliseconds: 250));
      final check = await _client
          .from('clients')
          .select('id')
          .eq('id', clientId);

      if (check.isEmpty) {
        debugPrint(
          '[SUPABASE][CHECK][SUCCESS] Cliente $clientId eliminado exitosamente de Supabase.',
        );
        return true;
      } else {
        debugPrint(
          '[SUPABASE][CHECK][FAIL] El cliente $clientId AÚN EXISTE en Supabase tras el intento de borrado.',
        );
        return false;
      }
    } catch (e, stack) {
      debugPrint(
        '[SUPABASE][ERROR] Error al eliminar cliente y transacciones para id $clientId: $e',
      );
      debugPrint('[SUPABASE][ERROR] Stacktrace: $stack');
      return false; // Indicar fallo en caso de excepción
    }
  }

  Future<void> addTransaction(
    Transaction tx,
    String userId,
    String clientId,
  ) async {
    final now = DateTime.now().toIso8601String();
    final data = {
      'client_id': clientId,
      'user_id': userId,
      'type': tx.type,
      'amount': tx.amount,
      'description': tx.description,
      'date': tx.date.toIso8601String(),
      'created_at': now,
      'local_id': tx.id, // id local generado en Hive
      'currency_code': tx.currencyCode,
      'anchor_usd_value': tx.anchorUsdValue,
    };
    debugPrint(
      '\u001b[45m[SUPABASE][UPSERT][TX] id=${tx.id}, clientId=$clientId, anchorUsdValue=${tx.anchorUsdValue}\u001b[0m',
    );
    final response = await _client
        .from('transactions')
        .upsert(data, onConflict: 'local_id')
        .select();
    if (response.isEmpty) {
      debugPrint(
        '\u001b[41m[SUPABASE][ERROR] No se pudo insertar/upsert la transacción (respuesta vacía): $response\u001b[0m',
      );
      throw Exception('No se pudo insertar la transacción');
    } else {
      debugPrint(
        '\u001b[42m[SUPABASE][UPSERT][OK] id=${tx.id}, anchorUsdValue=${tx.anchorUsdValue}, response=${response.toString()}\u001b[0m',
      );
    }
  }

  Future<void> updateTransaction(Transaction tx) async {
    final data = {
      'type': tx.type,
      'amount': tx.amount,
      'description': tx.description,
      'date': tx.date.toIso8601String(),
      'created_at': tx.createdAt.toIso8601String(),
      'anchor_usd_value': tx.anchorUsdValue,
    };
    debugPrint(
      '\u001b[44m[SUPABASE][UPDATE][TX] id=${tx.id}, anchorUsdValue=${tx.anchorUsdValue}\u001b[0m',
    );
    await _client.from('transactions').update(data).eq('id', tx.id);
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _client.from('transactions').delete().eq('id', transactionId);
  }
}

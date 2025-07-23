import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/client_hive.dart';
import '../models/transaction_hive.dart';

bool _hiveInitialized = false;

/// Inicializa Hive y abre las cajas necesarias (solo una vez)
Future<void> initOfflineStorage() async {
  if (_hiveInitialized) return;
  await Hive.initFlutter(); // Inicializa Hive correctamente en Flutter
  if (!Hive.isBoxOpen('clients')) {
    await Hive.openBox<ClientHive>('clients');
  }
  if (!Hive.isBoxOpen('transactions')) {
    await Hive.openBox<TransactionHive>('transactions');
  }
  _hiveInitialized = true;
}

/// Guarda un cliente localmente
Future<void> saveClientOffline(Map<String, dynamic> client) async {
  final box = Hive.box<ClientHive>('clients');
  final clientHive = ClientHive(
    id: client['id'],
    name: client['name'],
    address: client['address'],
    phone: client['phone'],
    balance: (client['balance'] as num?)?.toDouble() ?? 0.0,
    synced: client['synced'] ?? false,
    pendingDelete: client['pendingDelete'] ?? false,
    localId: client['localId'],
  );
  await box.put(client['id'], clientHive);
}

/// Obtiene todos los clientes locales
List<Map<String, dynamic>> getClientsOffline() {
  final box = Hive.box<ClientHive>('clients');
  return box.values
      .map(
        (c) => {
          'id': c.id,
          'name': c.name,
          'address': c.address,
          'phone': c.phone,
          'balance': c.balance,
          'synced': c.synced,
          'pendingDelete': c.pendingDelete,
          'localId': c.localId,
        },
      )
      .toList();
}

/// Guarda una transacción localmente
Future<void> saveTransactionOffline(Map<String, dynamic> tx) async {
  final box = Hive.box<TransactionHive>('transactions');
  final txHive = TransactionHive(
    id: tx['id'],
    clientId: tx['clientId'],
    type: tx['type'],
    amount: (tx['amount'] as num?)?.toDouble() ?? 0.0,
    date: tx['date'],
    description: tx['description'] ?? '',
    synced: tx['synced'] ?? false,
    pendingDelete: tx['pendingDelete'] ?? false,
    userId: tx['userId'],
  );
  await box.put(tx['id'], txHive);
}

/// Obtiene todas las transacciones locales
List<Map<String, dynamic>> getTransactionsOffline() {
  final box = Hive.box<TransactionHive>('transactions');
  return box.values
      .map(
        (t) => {
          'id': t.id,
          'clientId': t.clientId,
          'type': t.type,
          'amount': t.amount,
          'date': t.date,
          'description': t.description,
          'synced': t.synced,
          'pendingDelete': t.pendingDelete,
          'userId': t.userId,
        },
      )
      .toList();
}

/// Verifica si hay conexión a internet
Future<bool> isOnline() async {
  final result = await Connectivity().checkConnectivity();
  return !result.contains(ConnectivityResult.none);
}

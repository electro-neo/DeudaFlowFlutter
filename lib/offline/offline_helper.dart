import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Inicializa Hive y abre las cajas necesarias
Future<void> initOfflineStorage() async {
  await Hive.initFlutter();
  await Hive.openBox('clients');
  await Hive.openBox('transactions');
}

/// Guarda un cliente localmente
Future<void> saveClientOffline(Map<String, dynamic> client) async {
  final box = Hive.box('clients');
  await box.put(client['id'], client);
}

/// Obtiene todos los clientes locales
List<Map<String, dynamic>> getClientsOffline() {
  final box = Hive.box('clients');
  return box.values.cast<Map<String, dynamic>>().toList();
}

/// Guarda una transacción localmente
Future<void> saveTransactionOffline(Map<String, dynamic> tx) async {
  final box = Hive.box('transactions');
  await box.put(tx['id'], tx);
}

/// Obtiene todas las transacciones locales
List<Map<String, dynamic>> getTransactionsOffline() {
  final box = Hive.box('transactions');
  return box.values.cast<Map<String, dynamic>>().toList();
}

/// Verifica si hay conexión a internet
Future<bool> isOnline() async {
  final result = await Connectivity().checkConnectivity();
  return result != ConnectivityResult.none;
}

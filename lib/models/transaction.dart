import 'package:flutter/foundation.dart';

class Transaction {
  final String id;
  final String clientId;
  final String userId;
  final String type; // 'debt' o 'payment'
  final double amount;
  final String description;
  final DateTime date;
  final DateTime createdAt;
  final bool? synced;
  final bool? pendingDelete;
  final String? localId;
  final String currencyCode;
  final double? anchorUsdValue;

  Transaction({
    required this.id,
    required this.clientId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.createdAt,
    this.synced,
    this.pendingDelete,
    this.localId,
    required this.currencyCode,
    this.anchorUsdValue,
  }) {
    debugPrint(
      '\u001b[43m[TX][CREACION] id=$id, clientId=$clientId, type=$type, amount=$amount, currency=$currencyCode, anchorUsdValue=${anchorUsdValue?.toString() ?? 'null'}\u001b[0m',
    );
  }

  Transaction copyWith({
    String? id,
    String? clientId,
    String? userId,
    String? type,
    double? amount,
    String? description,
    DateTime? date,
    DateTime? createdAt,
    bool? synced,
    bool? pendingDelete,
    String? localId,
    String? currencyCode,
    double? anchorUsdValue,
  }) {
    return Transaction(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
      pendingDelete: pendingDelete ?? this.pendingDelete,
      localId: localId ?? this.localId,
      currencyCode: currencyCode ?? this.currencyCode,
      anchorUsdValue: anchorUsdValue ?? this.anchorUsdValue,
    );
  }

  static Transaction fromHive(dynamic t) {
    final tx = Transaction(
      id: t.id,
      clientId: t.clientId,
      userId: t.userId ?? '',
      type: t.type,
      amount: t.amount,
      description: t.description,
      date: t.date,
      createdAt: t.date, // Solo usa date, TransactionHive no tiene createdAt
      synced: t.synced,
      pendingDelete: t.pendingDelete,
      localId: t.localId,
      currencyCode: t.currencyCode ?? 'VES',
      anchorUsdValue: t.anchorUsdValue,
    );
    debugPrint(
      '\u001b[31m[TX][fromHive] id=${tx.id}, anchorUsdValue=${tx.anchorUsdValue?.toString() ?? 'null'}\u001b[0m',
    );
    return tx;
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    final tx = Transaction(
      id: map['id']?.toString() ?? '',
      clientId: map['client_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      type: map['type'],
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] ?? '',
      date: DateTime.parse(map['date']),
      createdAt: DateTime.parse(map['created_at']),
      synced: map['synced'] is bool
          ? map['synced'] as bool
          : (map['synced'] is int ? (map['synced'] == 1) : null),
      pendingDelete: map['pendingDelete'] is bool
          ? map['pendingDelete'] as bool
          : (map['pendingDelete'] is int ? (map['pendingDelete'] == 1) : null),
      localId: map['local_id']?.toString(),
      currencyCode: map['currency_code']?.toString() ?? 'VES',
      anchorUsdValue: (map['anchor_usd_value'] is num)
          ? (map['anchor_usd_value'] as num).toDouble()
          : double.tryParse(map['anchor_usd_value']?.toString() ?? ''),
    );
    debugPrint(
      '\u001b[35m[TX][fromMap] id=${tx.id}, anchorUsdValue=${tx.anchorUsdValue?.toString() ?? 'null'}\u001b[0m',
    );
    return tx;
  }

  // Elimina el factory duplicado para evitar conflicto con el método estático
}

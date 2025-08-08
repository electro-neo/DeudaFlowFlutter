import 'package:hive/hive.dart';
part 'transaction_hive.g.dart';

@HiveType(typeId: 1)
class TransactionHive extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String clientId;
  @HiveField(2)
  String type; // 'debt' o 'payment'
  @HiveField(3)
  double amount;
  @HiveField(4)
  DateTime date;
  @HiveField(5)
  bool synced;
  @HiveField(6)
  String description;
  @HiveField(7)
  bool pendingDelete;
  @HiveField(8)
  String? userId;
  @HiveField(9)
  String currencyCode; // Código de moneda (ej: 'USD', 'VES', 'COP')
  @HiveField(10)
  String? localId; // <-- Agregado para compatibilidad con Transaction
  @HiveField(11)
  double? anchorUsdValue; // Nuevo campo para valor en USD

  TransactionHive({
    required this.id,
    required this.clientId,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    this.synced = false,
    this.pendingDelete = false,
    this.userId,
    this.currencyCode = 'VES', // Valor por defecto para datos antiguos
    this.localId,
    this.anchorUsdValue,
  });

  factory TransactionHive.fromMap(Map<String, dynamic> map) {
    final idValue = map['id'];
    final clientIdValue = map['clientId'];
    final typeValue = map['type'];
    final dateValue = map['date'];
    if (idValue == null ||
        idValue.toString() == 'null' ||
        idValue.toString().isEmpty) {
      throw ArgumentError(
        "El campo 'id' es obligatorio y no puede ser null o vacío en TransactionHive.fromMap",
      );
    }
    if (clientIdValue == null ||
        clientIdValue.toString() == 'null' ||
        clientIdValue.toString().isEmpty) {
      throw ArgumentError(
        "El campo 'clientId' es obligatorio y no puede ser null o vacío en TransactionHive.fromMap",
      );
    }
    if (typeValue == null ||
        typeValue.toString() == 'null' ||
        typeValue.toString().isEmpty) {
      throw ArgumentError(
        "El campo 'type' es obligatorio y no puede ser null o vacío en TransactionHive.fromMap",
      );
    }
    if (dateValue == null ||
        dateValue.toString() == 'null' ||
        dateValue.toString().isEmpty) {
      throw ArgumentError(
        "El campo 'date' es obligatorio y no puede ser null o vacío en TransactionHive.fromMap",
      );
    }
    DateTime parsedDate;
    try {
      parsedDate = dateValue is DateTime
          ? dateValue
          : DateTime.parse(dateValue.toString());
    } catch (_) {
      throw ArgumentError(
        "El campo 'date' no tiene un formato válido en TransactionHive.fromMap: ${dateValue.toString()}",
      );
    }
    final tx = TransactionHive(
      id: idValue.toString(),
      clientId: clientIdValue.toString(),
      type: typeValue.toString(),
      amount: (map['amount'] is num)
          ? (map['amount'] as num).toDouble()
          : double.tryParse(map['amount']?.toString() ?? '') ?? 0.0,
      date: parsedDate,
      description: map['description']?.toString() ?? '',
      synced: map['synced'] is bool
          ? map['synced'] as bool
          : (map['synced'] is int ? (map['synced'] == 1) : false),
      pendingDelete: map['pendingDelete'] is bool
          ? map['pendingDelete'] as bool
          : (map['pendingDelete'] is int ? (map['pendingDelete'] == 1) : false),
      userId: map['userId']?.toString(),
      currencyCode: map['currency_code']?.toString() ?? 'VES',
      localId: map['local_id']?.toString(),
      anchorUsdValue: (map['anchor_usd_value'] is num)
          ? (map['anchor_usd_value'] as num).toDouble()
          : double.tryParse(map['anchor_usd_value']?.toString() ?? ''),
    );
    //
    return tx;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'type': type,
      'amount': amount,
      'date': date.toIso8601String(),
      'description': description,
      'synced': synced,
      'pendingDelete': pendingDelete,
      'userId': userId,
      'currency_code': currencyCode,
      'local_id': localId,
      'anchor_usd_value': anchorUsdValue,
    };
  }
}

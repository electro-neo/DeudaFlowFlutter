import 'package:hive/hive.dart';
part 'transaction_hive.g.dart';

@HiveType(typeId: 1)
class TransactionHive extends HiveObject {
  @HiveField(7)
  bool pendingDelete;
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

  TransactionHive({
    required this.id,
    required this.clientId,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    this.synced = false,
    this.pendingDelete = false,
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
    return TransactionHive(
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
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'clientId': clientId,
    'type': type,
    'amount': amount,
    'date': date.toIso8601String(),
    'description': description,
    'synced': synced,
    'pendingDelete': pendingDelete,
  };
}

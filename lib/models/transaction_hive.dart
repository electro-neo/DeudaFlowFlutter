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

  TransactionHive({
    required this.id,
    required this.clientId,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    this.synced = false,
  });

  factory TransactionHive.fromMap(Map<String, dynamic> map) => TransactionHive(
    id: map['id'].toString(),
    clientId: map['clientId'].toString(),
    type: map['type'].toString(),
    amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    date: DateTime.parse(map['date'].toString()),
    description: map['description']?.toString() ?? '',
    synced: map['synced'] ?? false,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'clientId': clientId,
    'type': type,
    'amount': amount,
    'date': date.toIso8601String(),
    'description': description,
    'synced': synced,
  };
}

import 'package:hive/hive.dart';
part 'client_hive.g.dart';

@HiveType(typeId: 0)
class ClientHive extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String? email;
  @HiveField(3)
  String? phone;
  @HiveField(4)
  double balance;
  @HiveField(5)
  bool synced; // true si está sincronizado con el servidor

  ClientHive({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.balance,
    this.synced = false,
  });

  factory ClientHive.fromMap(Map<String, dynamic> map) => ClientHive(
    id: map['id'].toString(),
    name: map['name']?.toString() ?? '',
    email: map['email']?.toString(),
    phone: map['phone']?.toString(),
    balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
    synced: map['synced'] ?? false,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'balance': balance,
    'synced': synced,
  };
}

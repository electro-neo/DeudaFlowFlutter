class Client {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final double balance;
  final String? localId;

  const Client({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.balance,
    this.localId,
  });

  factory Client.fromMap(Map<String, dynamic> map) => Client(
    id: map['id'].toString(),
    name: map['name']?.toString() ?? '',
    email: map['email']?.toString(),
    phone: map['phone']?.toString(),
    balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
    localId: map['local_id']?.toString(),
  );

  // Permite convertir un ClientHive a Client para compatibilidad
  factory Client.fromHive(dynamic hive) => Client(
    id: hive.id,
    name: hive.name,
    email: hive.email,
    phone: hive.phone,
    balance: hive.balance,
    localId: hive.localId,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'balance': balance,
    'local_id': localId,
  };
}

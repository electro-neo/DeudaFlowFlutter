class Client {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final double balance;

  const Client({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.balance,
  });

  factory Client.fromMap(Map<String, dynamic> map) => Client(
    id: map['id'].toString(),
    name: map['name']?.toString() ?? '',
    email: map['email']?.toString(),
    phone: map['phone']?.toString(),
    balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
  );

  // Permite convertir un ClientHive a Client para compatibilidad
  factory Client.fromHive(dynamic hive) => Client(
    id: hive.id,
    name: hive.name,
    email: hive.email,
    phone: hive.phone,
    balance: hive.balance,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'balance': balance,
  };
}

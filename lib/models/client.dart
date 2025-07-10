class Client {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final double balance;

  Client({
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'balance': balance,
  };
}

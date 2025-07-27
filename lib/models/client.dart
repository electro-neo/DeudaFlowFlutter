class Client {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final double balance;
  final String? localId;
  final double? anchorUsdValue;

  const Client({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    required this.balance,
    this.localId,
    this.anchorUsdValue,
  });

  factory Client.fromMap(Map<String, dynamic> map) => Client(
    id: map['id'].toString(),
    name: map['name']?.toString() ?? '',
    address: map['address']?.toString(),
    phone: map['phone']?.toString(),
    balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
    localId: map['local_id']?.toString(),
    anchorUsdValue: map['anchor_usd_value'] != null
        ? (map['anchor_usd_value'] as num?)?.toDouble()
        : null,
  );

  // Permite convertir un ClientHive a Client para compatibilidad
  factory Client.fromHive(dynamic hive) => Client(
    id: hive.id,
    name: hive.name,
    address: hive.address,
    phone: hive.phone,
    balance: hive.balance,
    localId: hive.localId,
    anchorUsdValue: hive.anchorUsdValue,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'address': address,
    'phone': phone,
    'balance': balance,
    'local_id': localId,
    'anchor_usd_value': anchorUsdValue,
  };
}

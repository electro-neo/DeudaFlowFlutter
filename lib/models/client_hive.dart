import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
part 'client_hive.g.dart';

@HiveType(typeId: 0)
class ClientHive extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String? address;
  @HiveField(3)
  String? phone;
  @HiveField(4)
  double balance;
  @HiveField(5)
  bool synced; // true si está sincronizado con el servidor
  @HiveField(6)
  bool pendingDelete; // true si está pendiente de eliminar
  @HiveField(7)
  String? localId;

  @HiveField(8)
  String? currencyCode; // Código de moneda (ej: 'USD', 'VES', 'COP'), ahora nullable

  @HiveField(9)
  double? anchorUsdValue; // Valor USD de saldo inicial (opcional)

  ClientHive({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    required this.balance,
    this.synced = false,
    this.pendingDelete = false,
    this.localId,
    this.currencyCode,
    this.anchorUsdValue,
  });

  factory ClientHive.fromMap(Map<String, dynamic> map) {
    final idValue = map['id'];
    final nameValue = map['name'];
    if (idValue == null ||
        idValue.toString() == 'null' ||
        idValue.toString().isEmpty) {
      debugPrint('[CLIENT_HIVE][ERROR] id inválido en fromMap: $map');
      throw ArgumentError(
        "El campo 'id' es obligatorio y no puede ser null o vacío en ClientHive.fromMap",
      );
    }
    if (nameValue == null || nameValue.toString() == 'null') {
      debugPrint('[CLIENT_HIVE][ERROR] name inválido en fromMap: $map');
      throw ArgumentError(
        "El campo 'name' es obligatorio y no puede ser null en ClientHive.fromMap",
      );
    }
    final client = ClientHive(
      id: idValue.toString(),
      name: nameValue.toString(),
      address: map['address']?.toString(),
      phone: map['phone']?.toString(),
      balance: (map['balance'] is num)
          ? (map['balance'] as num).toDouble()
          : double.tryParse(map['balance']?.toString() ?? '') ?? 0.0,
      synced: map['synced'] == null
          ? false
          : (map['synced'] is bool
                ? map['synced'] as bool
                : (map['synced'] is int ? (map['synced'] == 1) : false)),
      pendingDelete: map['pendingDelete'] == null
          ? false
          : (map['pendingDelete'] is bool
                ? map['pendingDelete'] as bool
                : (map['pendingDelete'] is int
                      ? (map['pendingDelete'] == 1)
                      : false)),
      localId: map['local_id']?.toString(),
      currencyCode: map['currency_code']?.toString() ?? 'VES',
      anchorUsdValue: map['anchor_usd_value'] != null
          ? (map['anchor_usd_value'] as num?)?.toDouble()
          : null,
    );
    debugPrint(
      '[CLIENT_HIVE][fromMap] Instancia creada: id=\x1B[36m${client.id}\x1B[0m, name=\x1B[36m${client.name}\x1B[0m, pendingDelete=${client.pendingDelete}, synced=${client.synced}',
    );
    return client;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'address': address,
    'phone': phone,
    'balance': balance,
    'synced': synced,
    'pendingDelete': pendingDelete,
    'local_id': localId,
    'currency_code': currencyCode,
    'anchor_usd_value': anchorUsdValue,
  };
}

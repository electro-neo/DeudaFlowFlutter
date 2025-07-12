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
  @HiveField(6)
  bool pendingDelete; // true si está pendiente de eliminar

  ClientHive({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.balance,
    this.synced = false,
    this.pendingDelete = false,
  });

  factory ClientHive.fromMap(Map<String, dynamic> map) {
    final idValue = map['id'];
    final nameValue = map['name'];
    if (idValue == null ||
        idValue.toString() == 'null' ||
        idValue.toString().isEmpty) {
      print('[CLIENT_HIVE][ERROR] id inválido en fromMap: $map');
      throw ArgumentError(
        "El campo 'id' es obligatorio y no puede ser null o vacío en ClientHive.fromMap",
      );
    }
    if (nameValue == null || nameValue.toString() == 'null') {
      print('[CLIENT_HIVE][ERROR] name inválido en fromMap: $map');
      throw ArgumentError(
        "El campo 'name' es obligatorio y no puede ser null en ClientHive.fromMap",
      );
    }
    final client = ClientHive(
      id: idValue.toString(),
      name: nameValue.toString(),
      email: map['email']?.toString(),
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
    );
    print(
      '[CLIENT_HIVE][fromMap] Instancia creada: id=[36m${client.id}[0m, name=[36m${client.name}[0m, pendingDelete=${client.pendingDelete}, synced=${client.synced}',
    );
    return client;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'balance': balance,
    'synced': synced,
    'pendingDelete': pendingDelete,
  };
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ClientHiveAdapter extends TypeAdapter<ClientHive> {
  @override
  final int typeId = 0;

  @override
  ClientHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ClientHive(
      id: fields[0] as String,
      name: fields[1] as String,
      email: fields[2] as String?,
      phone: fields[3] as String?,
      balance: fields[4] as double,
      synced: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ClientHive obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.balance)
      ..writeByte(5)
      ..write(obj.synced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionHiveAdapter extends TypeAdapter<TransactionHive> {
  @override
  final int typeId = 1;

  @override
  TransactionHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionHive(
      id: fields[0] as String,
      clientId: fields[1] as String,
      type: fields[2] as String,
      amount: fields[3] as double,
      date: fields[4] as DateTime,
      description: fields[6] as String,
      synced: fields[5] as bool,
      pendingDelete: fields[7] as bool,
      userId: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionHive obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.clientId)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.synced)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.pendingDelete)
      ..writeByte(8)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

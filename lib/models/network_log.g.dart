// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NetworkLogAdapter extends TypeAdapter<NetworkLog> {
  @override
  final int typeId = 0;

  @override
  NetworkLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NetworkLog(
      timestamp: fields[0] as DateTime,
      latitude: fields[1] as double,
      longitude: fields[2] as double,
      signalStrength: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, NetworkLog obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.timestamp)
      ..writeByte(1)
      ..write(obj.latitude)
      ..writeByte(2)
      ..write(obj.longitude)
      ..writeByte(3)
      ..write(obj.signalStrength);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

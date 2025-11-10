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
      downloadKb: fields[0] as double,
      uploadKb: fields[1] as double,
      signalStrength: fields[2] as int?,
      latitude: fields[3] as double?,
      longitude: fields[4] as double?,
      weather: fields[5] as String?,
      temperature: fields[6] as double?,
      timestamp: fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, NetworkLog obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.downloadKb)
      ..writeByte(1)
      ..write(obj.uploadKb)
      ..writeByte(2)
      ..write(obj.signalStrength)
      ..writeByte(3)
      ..write(obj.latitude)
      ..writeByte(4)
      ..write(obj.longitude)
      ..writeByte(5)
      ..write(obj.weather)
      ..writeByte(6)
      ..write(obj.temperature)
      ..writeByte(7)
      ..write(obj.timestamp);
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

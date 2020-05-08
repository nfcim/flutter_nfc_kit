// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flutter_nfc_kit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NFCTag _$NFCTagFromJson(Map<String, dynamic> json) {
  return NFCTag(
    _$enumDecodeNullable(_$NFCTagTypeEnumMap, json['type']),
    json['id'] as String,
    json['standard'] as String,
    json['atqa'] as String,
    json['sak'] as String,
    json['historicalBytes'] as String,
    json['protocolInfo'] as String,
    json['applicationData'] as String,
    json['hiLayerResponse'] as String,
    json['manufacturer'] as String,
    json['systemCode'] as String,
    json['dsfId'] as String,
    json['ndefAvailable'] as bool,
    json['ndefType'] as String,
    json['ndefCapacity'] as int,
    json['ndefWritable'] as bool,
    json['ndefCanMakeReadOnly'] as bool,
  );
}

Map<String, dynamic> _$NFCTagToJson(NFCTag instance) => <String, dynamic>{
      'type': _$NFCTagTypeEnumMap[instance.type],
      'standard': instance.standard,
      'id': instance.id,
      'atqa': instance.atqa,
      'sak': instance.sak,
      'historicalBytes': instance.historicalBytes,
      'hiLayerResponse': instance.hiLayerResponse,
      'protocolInfo': instance.protocolInfo,
      'applicationData': instance.applicationData,
      'manufacturer': instance.manufacturer,
      'systemCode': instance.systemCode,
      'dsfId': instance.dsfId,
      'ndefAvailable': instance.ndefAvailable,
      'ndefType': instance.ndefType,
      'ndefCapacity': instance.ndefCapacity,
      'ndefWritable': instance.ndefWritable,
      'ndefCanMakeReadOnly': instance.ndefCanMakeReadOnly,
    };

T _$enumDecode<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }

  final value = enumValues.entries
      .singleWhere((e) => e.value == source, orElse: () => null)
      ?.key;

  if (value == null && unknownValue == null) {
    throw ArgumentError('`$source` is not one of the supported values: '
        '${enumValues.values.join(', ')}');
  }
  return value ?? unknownValue;
}

T _$enumDecodeNullable<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source, unknownValue: unknownValue);
}

const _$NFCTagTypeEnumMap = {
  NFCTagType.iso7816: 'iso7816',
  NFCTagType.iso15693: 'iso15693',
  NFCTagType.mifare_classic: 'mifare_classic',
  NFCTagType.mifare_ultralight: 'mifare_ultralight',
  NFCTagType.mifare_desfire: 'mifare_desfire',
  NFCTagType.mifare_plus: 'mifare_plus',
  NFCTagType.felica: 'felica',
  NFCTagType.unknown: 'unknown',
};

NDEFRecord _$NDEFRecordFromJson(Map<String, dynamic> json) {
  return NDEFRecord(
    json['identifier'] as String,
    json['payload'] as String,
    json['type'] as String,
    _$enumDecodeNullable(_$NDEFTypeNameFormatEnumMap, json['typeNameFormat']),
  );
}

Map<String, dynamic> _$NDEFRecordToJson(NDEFRecord instance) =>
    <String, dynamic>{
      'identifier': instance.identifier,
      'payload': instance.payload,
      'type': instance.type,
      'typeNameFormat': _$NDEFTypeNameFormatEnumMap[instance.typeNameFormat],
    };

const _$NDEFTypeNameFormatEnumMap = {
  NDEFTypeNameFormat.absoluteURI: 'absoluteURI',
  NDEFTypeNameFormat.empty: 'empty',
  NDEFTypeNameFormat.media: 'media',
  NDEFTypeNameFormat.nfcExternal: 'nfcExternal',
  NDEFTypeNameFormat.nfcWellKnown: 'nfcWellKnown',
  NDEFTypeNameFormat.unchanged: 'unchanged',
  NDEFTypeNameFormat.unknown: 'unknown',
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flutter_nfc_kit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NFCTag _$NFCTagFromJson(Map<String, dynamic> json) {
  return NFCTag(
    _$enumDecode(_$NFCTagTypeEnumMap, json['type']),
    json['id'] as String,
    json['standard'] as String,
    json['atqa'] as String?,
    json['sak'] as String?,
    json['historicalBytes'] as String?,
    json['protocolInfo'] as String?,
    json['applicationData'] as String?,
    json['hiLayerResponse'] as String?,
    json['manufacturer'] as String?,
    json['systemCode'] as String?,
    json['dsfId'] as String?,
    json['ndefAvailable'] as bool?,
    json['ndefType'] as String?,
    json['ndefCapacity'] as int?,
    json['ndefWritable'] as bool?,
    json['ndefCanMakeReadOnly'] as bool?,
    json['webUSBCustomProbeData'] as String?,
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
      'webUSBCustomProbeData': instance.webUSBCustomProbeData,
    };

K _$enumDecode<K, V>(
  Map<K, V> enumValues,
  Object? source, {
  K? unknownValue,
}) {
  if (source == null) {
    throw ArgumentError(
      'A value must be provided. Supported values: '
      '${enumValues.values.join(', ')}',
    );
  }

  return enumValues.entries.singleWhere(
    (e) => e.value == source,
    orElse: () {
      if (unknownValue == null) {
        throw ArgumentError(
          '`$source` is not one of the supported values: '
          '${enumValues.values.join(', ')}',
        );
      }
      return MapEntry(unknownValue, enumValues.values.first);
    },
  ).key;
}

const _$NFCTagTypeEnumMap = {
  NFCTagType.iso7816: 'iso7816',
  NFCTagType.iso15693: 'iso15693',
  NFCTagType.iso18092: 'iso18092',
  NFCTagType.mifare_classic: 'mifare_classic',
  NFCTagType.mifare_ultralight: 'mifare_ultralight',
  NFCTagType.mifare_desfire: 'mifare_desfire',
  NFCTagType.mifare_plus: 'mifare_plus',
  NFCTagType.webusb: 'webusb',
  NFCTagType.unknown: 'unknown',
};

NDEFRawRecord _$NDEFRawRecordFromJson(Map<String, dynamic> json) {
  return NDEFRawRecord(
    json['identifier'] as String,
    json['payload'] as String,
    json['type'] as String,
    _$enumDecode(_$TypeNameFormatEnumMap, json['typeNameFormat']),
  );
}

Map<String, dynamic> _$NDEFRawRecordToJson(NDEFRawRecord instance) =>
    <String, dynamic>{
      'identifier': instance.identifier,
      'payload': instance.payload,
      'type': instance.type,
      'typeNameFormat': _$TypeNameFormatEnumMap[instance.typeNameFormat],
    };

const _$TypeNameFormatEnumMap = {
  TypeNameFormat.empty: 'empty',
  TypeNameFormat.nfcWellKnown: 'nfcWellKnown',
  TypeNameFormat.media: 'media',
  TypeNameFormat.absoluteURI: 'absoluteURI',
  TypeNameFormat.nfcExternal: 'nfcExternal',
  TypeNameFormat.unknown: 'unknown',
  TypeNameFormat.unchanged: 'unchanged',
};

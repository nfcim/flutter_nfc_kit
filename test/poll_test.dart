import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_nfc_kit/method');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'poll':
          return jsonEncode({
            'type': 'iso7816',
            'standard': 'ISO 14443',
            'id': '00',
            'ndefAvailable': false,
            'ndefWritable': false,
            'ndefCapacity': 0,
            'ndefType': '',
            'ndefCanMakeReadOnly': false,
          });
        case 'transceive':
          return '9000';
        case 'finish':
          return null;
        default:
          fail('Unexpected method: ${call.method}');
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('poll preserves automatic NDEF discovery by default', () async {
    await FlutterNfcKit.poll();
    final args = calls.single.arguments as Map;
    expect(args['iosCheckNDEF'], isTrue);
    expect(args['technologies'], 0x0b);
  });

  test('skipping iOS NDEF discovery does not alter Android flags', () async {
    await FlutterNfcKit.poll(iosCheckNDEF: false);
    final args = calls.single.arguments as Map;
    expect(args['iosCheckNDEF'], isFalse);
    expect(args['technologies'], 0x0b);
  });

  test('Android NDEF skip flag leaves iOS discovery enabled', () async {
    await FlutterNfcKit.poll(androidCheckNDEF: false);
    final args = calls.single.arguments as Map;
    expect(args['iosCheckNDEF'], isTrue);
    expect(args['technologies'], 0x8b);
  });

  test('both platforms can skip discovery before raw commands', () async {
    final tag = await FlutterNfcKit.poll(
      androidCheckNDEF: false,
      iosCheckNDEF: false,
    );
    final args = calls.single.arguments as Map;
    expect(args['iosCheckNDEF'], isFalse);
    expect(args['technologies'], 0x8b);
    expect(tag.ndefAvailable, isFalse);
    expect(tag.ndefWritable, isFalse);
    expect(tag.ndefCapacity, 0);
    expect(await FlutterNfcKit.transceive('00A4040000'), '9000');
    await FlutterNfcKit.finish();
    expect(calls.map((call) => call.method), ['poll', 'transceive', 'finish']);
  });
}

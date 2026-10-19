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
    expect(args['checkNDEF'], isTrue);
    expect(args['technologies'], 0x0b);
  });

  test('legacy Android opt-out leaves iOS discovery enabled', () async {
    await FlutterNfcKit.poll(androidCheckNDEF: false);
    final args = calls.single.arguments as Map;
    expect(args['checkNDEF'], isTrue);
    expect(args['technologies'], 0x8b);
  });

  test(
    'legacy Android opt-in overrides shared opt-out on Android only',
    () async {
      await FlutterNfcKit.poll(checkNDEF: false, androidCheckNDEF: true);
      final args = calls.single.arguments as Map;
      expect(args['checkNDEF'], isFalse);
      expect(args['technologies'], 0x0b);
    },
  );

  test(
    'legacy Android opt-out overrides shared opt-in on Android only',
    () async {
      await FlutterNfcKit.poll(checkNDEF: true, androidCheckNDEF: false);
      final args = calls.single.arguments as Map;
      expect(args['checkNDEF'], isTrue);
      expect(args['technologies'], 0x8b);
    },
  );

  test(
    'shared opt-out skips discovery on both platforms before raw commands',
    () async {
      final tag = await FlutterNfcKit.poll(checkNDEF: false);
      final args = calls.single.arguments as Map;
      expect(args['checkNDEF'], isFalse);
      expect(args['technologies'], 0x8b);
      expect(tag.ndefAvailable, isFalse);
      expect(tag.ndefWritable, isFalse);
      expect(tag.ndefCapacity, 0);
      expect(await FlutterNfcKit.transceive('00A4040000'), '9000');
      await FlutterNfcKit.finish();
      expect(calls.map((call) => call.method), [
        'poll',
        'transceive',
        'finish',
      ]);
    },
  );
}

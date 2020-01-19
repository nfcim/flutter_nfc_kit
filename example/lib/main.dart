import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  NFCAvailability _availability = NFCAvailability.not_supported;
  NFCTag _tag;
  String _result;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // String platformVersion;
    // // Platform messages may fail, so we use a try/catch PlatformException.
    // try {
    //   //platformVersion = await FlutterNfcKit.platformVersion;
    // } on PlatformException {
    //   platformVersion = 'Failed to get platform version.';
    // }

    NFCAvailability availability;
    try {
      availability = await FlutterNfcKit.nfcAvailability;
    } on PlatformException {
      availability = NFCAvailability.not_supported;
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      // _platformVersion = platformVersion;
      _availability = availability;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('NFC Flutter Kit Example App'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Running on: $_platformVersion\nNFC: $_availability'),
              RaisedButton(
                onPressed: () async {
                  NFCTag tag = await FlutterNfcKit.poll();
                  setState(() {
                    _tag = tag;
                  });
                  String result1 = await FlutterNfcKit.transceive("00B0950000");
                  String result2 = await FlutterNfcKit.transceive("00A4040009A00000000386980701");
                  String result3 = await FlutterNfcKit.transceive("00B0960027");
                  String result4 = await FlutterNfcKit.transceive("805C000104");
                  String result5 = await FlutterNfcKit.transceive("00B201C400");
                  setState(() {
                    _result = '1: $result1\n2: $result2\n3: $result3\n4: $result4\n5: $result5';
                  });
                  await FlutterNfcKit.finish();
                },
                child: Text('Start polling'),
              ),
              Text(
                  'Id: ${_tag?.id}\nStandard: ${_tag?.standard}\nATQA: ${_tag?.atqa}\nSAK: ${_tag?.sak}\nHistorical Bytes: ${_tag?.historicalBytes}\nProtocol Info: ${_tag?.protocolInfo}\nApplication Data: ${_tag?.applicationData}\nTransceive Result:\n$_result'),
            ],
          ),
        ),
      ),
    );
  }
}

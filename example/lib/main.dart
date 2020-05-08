import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform, sleep;

import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion =
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
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
                  try {
                    NFCTag tag = await FlutterNfcKit.poll();
                    setState(() {
                      _tag = tag;
                    });
                    await FlutterNfcKit.setIosAlertMessage("working on it...");
                    if (tag.standard == "ISO 14443-4 (Type B)") {
                      String result1 =
                          await FlutterNfcKit.transceive("00B0950000");
                      String result2 = await FlutterNfcKit.transceive(
                          "00A4040009A00000000386980701");
                      setState(() {
                        _result = '1: $result1\n2: $result2\n';
                      });
                    } else if (tag.type == NFCTagType.felica) {
                      String result1 =
                          await FlutterNfcKit.transceive("060080080100");
                      setState(() {
                        _result = '1: $result1\n';
                      });
                    } else if (tag.type == NFCTagType.mifare_ultralight) {
                      List<NDEFRecord> result1 = await FlutterNfcKit.readNDEF();
                      setState(() {
                        _result = '1: ${jsonEncode(result1)}\n';
                      });
                    }
                  } catch (e) {
                    setState(() {
                      _result = 'error: $e';
                    });
                  }

                  // Pretend that we are working
                  sleep(new Duration(seconds: 1));
                  await FlutterNfcKit.finish(iosAlertMessage: "Finished!");
                },
                child: Text('Start polling'),
              ),
              Text(
                  'ID: ${_tag?.id}\nStandard: ${_tag?.standard}\nType: ${_tag?.type}\nATQA: ${_tag?.atqa}\nSAK: ${_tag?.sak}\nHistorical Bytes: ${_tag?.historicalBytes}\nProtocol Info: ${_tag?.protocolInfo}\nApplication Data: ${_tag?.applicationData}\nHigher Layer Response: ${_tag?.hiLayerResponse}\nManufacturer: ${_tag?.manufacturer}\nSystem Code: ${_tag?.systemCode}\nDSF ID: ${_tag?.dsfId}\nNDEF Available: ${_tag?.ndefAvailable}\nNDEF Type: ${_tag?.ndefType}\nNDEF Writable: ${_tag?.ndefWritable}\nNDEF Can Make Read Only: ${_tag?.ndefCanMakeReadOnly}\nNDEF Capacity: ${_tag?.ndefCapacity}\n\n Transceive Result:\n$_result'),
            ],
          ),
        ),
      ),
    );
  }
}

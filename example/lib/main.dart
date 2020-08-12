import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform, sleep;

import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;

void main() => runApp(MaterialApp(home: MyApp()));

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  String _platformVersion =
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  NFCAvailability _availability = NFCAvailability.not_supported;
  NFCTag _tag;
  String _result, _writeResult;
  TabController _tabController;
  List<NDEFRawRecord> _message;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _tabController = new TabController(length: 2, vsync: this);
    _message = new List<NDEFRawRecord>();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
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
            bottom: TabBar(
              tabs: <Widget>[
                Tab(text: 'read'),
                Tab(text: 'write'),
              ],
              controller: _tabController,
            )),
        body: new TabBarView(controller: _tabController, children: <Widget>[
          Scrollbar(
              child: SingleChildScrollView(
                  child: Center(
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
                      await FlutterNfcKit.setIosAlertMessage(
                          "working on it...");
                      if (tag.standard == "ISO 14443-4 (Type B)") {
                        String result1 =
                            await FlutterNfcKit.transceive("00B0950000");
                        String result2 = await FlutterNfcKit.transceive(
                            "00A4040009A00000000386980701");
                        setState(() {
                          _result = '1: $result1\n2: $result2\n';
                        });
                      } else if (tag.type == NFCTagType.iso18092) {
                        String result1 =
                            await FlutterNfcKit.transceive("060080080100");
                        setState(() {
                          _result = '1: $result1\n';
                        });
                      } else if (tag.type == NFCTagType.mifare_ultralight ||
                          tag.type == NFCTagType.mifare_classic) {
                        var ndefRecords = await FlutterNfcKit.readNDEFRecords();
                        var ndefString = ndefRecords
                            .map((r) => r.toString())
                            .reduce((value, element) => value + "\n" + element);
                        setState(() {
                          _result = '1: $ndefString\n';
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
              ])))),
          Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      RaisedButton(
                        onPressed: () async {
                          if (_message.length != 0) {
                            try {
                              NFCTag tag = await FlutterNfcKit.poll();
                              setState(() {
                                _tag = tag;
                              });
                              if (tag.type == NFCTagType.mifare_ultralight ||
                                  tag.type == NFCTagType.mifare_classic) {
                                await FlutterNfcKit.writeNDEFRawRecords(_message);
                                setState(() {
                                  _writeResult = 'OK';
                                });
                              } else {
                                setState(() {
                                  _writeResult =
                                      'error: NDEF not supported: ${tag.type}';
                                });
                              }
                            } catch (e) {
                              setState(() {
                                _writeResult = 'error: $e';
                              });
                            }
                          } else {
                            setState(() {
                              _writeResult = 'error: No record';
                            });
                          }
                        },
                        child: Text("Start writing"),
                      ),
                      RaisedButton(
                        onPressed: () {
                          setState(() {
                            _message.add(NDEFRawRecord(
                                "", "", "", ndef.TypeNameFormat.empty));
                          });
                        },
                        child: Text("Add record"),
                      )
                    ],
                  ),
                  Text('Result:$_writeResult'),
                  Expanded(
                    flex: 1,
                    child: ListView(
                        shrinkWrap: true,
                        children: List<Widget>.generate(
                            _message.length,
                            (index) => GestureDetector(
                                  child: Text(
                                      'id:${_message[index].identifier}\ntnf:${_message[index].typeNameFormat}\ntype:${_message[index].type}\npayload:${_message[index].payload}\n'),
                                  onTap: () async {
                                    final result = await Navigator.push(context,
                                        MaterialPageRoute(builder: (context) {
                                      return NDEFRecordSetting(
                                          record: _message[index]);
                                    }));
                                    if (result != null) {
                                      if (result is NDEFRawRecord) {
                                        setState(() {
                                          _message[index] = result;
                                        });
                                      } else if (result is String &&
                                          result == "Delete") {
                                        _message.removeAt(index);
                                      }
                                    }
                                  },
                                ))),
                  ),
                ]),
          )
        ]),
      ),
    );
  }
}

class NDEFRecordSetting extends StatefulWidget {
  NDEFRawRecord record;
  NDEFRecordSetting({Key key, this.record}) : super(key: key);
  @override
  _NDEFRecordSetting createState() => _NDEFRecordSetting();
}

class _NDEFRecordSetting extends State<NDEFRecordSetting> {
  GlobalKey _formKey = new GlobalKey<FormState>();
  TextEditingController _identifierController;
  TextEditingController _payloadController;
  TextEditingController _typeController;
  ndef.TypeNameFormat _tnf = ndef.TypeNameFormat.empty;
  int _dropButtonValue;

  @override
  initState() {
    _identifierController = new TextEditingController.fromValue(
        TextEditingValue(text: widget.record.identifier));
    _payloadController = new TextEditingController.fromValue(
        TextEditingValue(text: widget.record.payload));
    _typeController = new TextEditingController.fromValue(
        TextEditingValue(text: widget.record.type));
    _tnf = widget.record.typeNameFormat;
    _dropButtonValue = ndef.TypeNameFormat.values.indexOf(_tnf);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
            appBar: AppBar(
              title: Text('Set Record'),
            ),
            body: Center(
                child: Form(
                    key: _formKey,
                    autovalidate: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        DropdownButton(
                          value: _dropButtonValue,
                          items: [
                            DropdownMenuItem(
                              child: Text('empty'),
                              value: 0,
                            ),
                            DropdownMenuItem(
                              child: Text('nfcWellKnown'),
                              value: 1,
                            ),
                            DropdownMenuItem(
                              child: Text('media'),
                              value: 2,
                            ),
                            DropdownMenuItem(
                              child: Text('absoluteURI'),
                              value: 3,
                            ),
                            DropdownMenuItem(
                                child: Text('nfcExternal'), value: 4),
                            DropdownMenuItem(
                                child: Text('unchanged'), value: 5),
                            DropdownMenuItem(
                              child: Text('unknown'),
                              value: 6,
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _tnf = ndef.TypeNameFormat.values[value];
                              _dropButtonValue =
                                  ndef.TypeNameFormat.values.indexOf(_tnf);
                            });
                          },
                        ),
                        TextFormField(
                          decoration: InputDecoration(labelText: 'identifier'),
                          validator: (v) {
                            return v.trim().length % 2 == 0
                                ? null
                                : 'length must be even';
                          },
                          controller: _identifierController,
                        ),
                        TextFormField(
                          decoration: InputDecoration(labelText: 'type'),
                          validator: (v) {
                            return v.trim().length % 2 == 0
                                ? null
                                : 'length must be even';
                          },
                          controller: _typeController,
                        ),
                        TextFormField(
                          decoration: InputDecoration(labelText: 'payload'),
                          validator: (v) {
                            return v.trim().length % 2 == 0
                                ? null
                                : 'length must be even';
                          },
                          controller: _payloadController,
                        ),
                        RaisedButton(
                          child: Text('OK'),
                          onPressed: () {
                            if ((_formKey.currentState as FormState)
                                .validate()) {
                              Navigator.pop(
                                  context,
                                  NDEFRawRecord(
                                      (_identifierController.text == null
                                          ? ""
                                          : _identifierController.text),
                                      (_payloadController.text == null
                                          ? ""
                                          : _payloadController.text),
                                      (_typeController.text == null
                                          ? ""
                                          : _typeController.text),
                                      _tnf));
                            }
                          },
                        ),
                        RaisedButton(
                          child: Text('Delete'),
                          onPressed: () {
                            if ((_formKey.currentState as FormState)
                                .validate()) {
                              Navigator.pop(context, 'Delete');
                            }
                          },
                        ),
                      ],
                    )))));
  }
}


import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform, sleep;

import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;

import 'record-setting/raw_record_setting.dart';
import 'record-setting/text_record_setting.dart';
import 'record-setting/uri_record_setting.dart';

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
  List<ndef.NDEFRecord> _message;

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
    _message = new List<ndef.NDEFRecord>();
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
            child:
                Column(mainAxisAlignment: MainAxisAlignment.start, children: <
                    Widget>[
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
                            await FlutterNfcKit.writeNDEFRecords(_message);
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
                        } finally {
                          await FlutterNfcKit.finish();
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
                      showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return SimpleDialog(
                                title: Text("Record Type"),
                                children: <Widget>[
                                  SimpleDialogOption(
                                    child: Text("Text Record"),
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) {
                                        return TextRecordSetting();
                                      }));
                                      if(result!=null) {
                                        if (result is ndef.TextRecord) {
                                          setState(() {
                                            _message.add(result);
                                          });
                                        }
                                      }
                                    },
                                  ),
                                  SimpleDialogOption(
                                    child: Text("Uri Record"),
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) {
                                        return UriRecordSetting();
                                      }));
                                      if(result!=null) {
                                        if (result is ndef.UriRecord) {
                                          setState(() {
                                            _message.add(result);
                                          });
                                        }
                                      }
                                    },
                                  ),
                                  SimpleDialogOption(
                                    child: Text("Raw Record"),
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) {
                                        return NDEFRecordSetting();
                                      }));
                                      if (result != null) {
                                        if (result is ndef.NDEFRecord) {
                                          setState(() {
                                            _message.add(result);
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ]);
                          });
                    },
                    child: Text("Add record"),
                  )
                ],
              ),
              Text('Result:$_writeResult'),
              Expanded(
                flex: 1,
                child: ListView (
                    shrinkWrap: true,
                    children: List<Widget>.generate(
                        _message.length,
                        (index) => GestureDetector(
                              child: Text(
                                //id:${_message[index].id.toHexString()}\n
                                  'tnf:${_message[index].tnf}\ntype:${_message[index].type.toHexString()}\npayload:${_message[index].payload.toHexString()}\n'),
                              onTap: () async {
                                final result = await Navigator.push(context,
                                    MaterialPageRoute(builder: (context) {
                                  return NDEFRecordSetting(
                                      record: _message[index]);
                                }));
                                if (result != null) {
                                  if (result is ndef.NDEFRecord) {
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

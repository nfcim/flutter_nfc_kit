import 'dart:async';
import 'dart:io' show Platform, sleep;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:logging/logging.dart';
import 'package:ndef/ndef.dart' as ndef;
import 'package:ndef/utilities.dart';

import 'ndef_record/raw_record_setting.dart';
import 'ndef_record/text_record_setting.dart';
import 'ndef_record/uri_record_setting.dart';

void main() {
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  runApp(MaterialApp(theme: ThemeData(useMaterial3: true), home: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  State createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  String _platformVersion = '';
  NFCAvailability _availability = NFCAvailability.not_supported;
  NFCTag? _tag;
  String? _result, _writeResult, _mifareResult;
  String? _sessionErrorResult;
  bool _streaming = false;
  int _streamCount = 0;
  late TabController _tabController;
  List<ndef.NDEFRecord>? _records;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _platformVersion =
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } else {
      _platformVersion = 'Web';
    }
    initPlatformState();
    _tabController = TabController(length: 2, vsync: this);
    _records = [];
    FlutterNfcKit.tagStream.listen((tag) {
      setState(() {
        _tag = tag;
        print(_tag);
      });
    });
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

  // A benign command used to keep the session busy. Exact bytes depend on the
  // tag; unsupported-command errors are ignored while streaming, so any tag works.
  String _dummyCommandFor(NFCTag tag) {
    if (tag.type == NFCTagType.iso18092) return "060080080100";
    return "00A4040000"; // ISO7816 SELECT (no AID)
  }

  // Validates iOS session-invalidation errors by keeping the session genuinely
  // busy: after polling, it continuously transceives dummy data until you stop
  // it (tap again) or a session error fires. Tap Cancel on the iOS sheet while
  // streaming to see UserCanceled (409) surface mid-transceive. SystemIsBusy
  // (503) may also surface here. Both are CoreNFC-only (iOS).
  Future<void> _streamDummyData() async {
    if (_streaming) {
      setState(() => _streaming = false); // request stop
      return;
    }
    setState(() {
      _streaming = true;
      _streamCount = 0;
      _sessionErrorResult = 'Polling…';
    });
    try {
      NFCTag tag = await FlutterNfcKit.poll(
          iosAlertMessage: "Streaming — tap Cancel to test UserCanceled");
      final dummy = _dummyCommandFor(tag);
      while (_streaming) {
        try {
          await FlutterNfcKit.transceive(dummy);
        } on PlatformException catch (e) {
          // Only a transient tag-level comm error (500, e.g. the tag rejecting
          // our dummy command) is ignored so streaming continues. Any other code
          // means the session ended — canceled (409), busy (503), timed out
          // (408), terminated unexpectedly (502), or no longer active (406) —
          // so stop and report it instead of spinning.
          if (e.code != '500') rethrow;
        }
        setState(() {
          _streamCount++;
          _sessionErrorResult = 'Streaming dummy data… ($_streamCount sent)';
        });
        await Future.delayed(const Duration(milliseconds: 100));
      }
      await FlutterNfcKit.finish(iosAlertMessage: "Stopped");
      setState(() =>
          _sessionErrorResult = 'Stopped after $_streamCount commands.');
    } on PlatformException catch (e) {
      setState(() => _sessionErrorResult = 'code=${e.code} message=${e.message}');
    } finally {
      setState(() => _streaming = false);
    }
  }

  // Drives the real SystemIsBusy (503) flow: stream dummy data until iOS kicks
  // us off (502 SessionTerminatedUnexpectedly), then retry immediately — too
  // soon, so iOS returns SystemIsBusy (503). It then backs off and retries to
  // show the session recovers. iOS-only (CoreNFC).
  Future<void> _testSystemIsBusy() async {
    setState(() => _sessionErrorResult = 'Streaming until iOS kicks us off…');
    try {
      // 1. Hold the session busy until iOS terminates it.
      NFCTag tag = await FlutterNfcKit.poll(
          iosAlertMessage: "Hold still until kicked off…");
      final dummy = _dummyCommandFor(tag);
      var sent = 0;
      while (true) {
        try {
          await FlutterNfcKit.transceive(dummy);
          setState(() =>
              _sessionErrorResult = 'Streaming… (${++sent} sent), waiting to be kicked off');
        } on PlatformException catch (e) {
          if (e.code == '500') continue; // transient tag error, keep streaming
          // Session ended (expected: 502 kicked off) — break out to retry.
          setState(() => _sessionErrorResult =
              'Kicked off after $sent: code=${e.code} (${e.message}). Retrying instantly…');
          break;
        }
      }

      // 2. Retry immediately — too soon, so iOS should report SystemIsBusy.
      try {
        await FlutterNfcKit.poll(
            timeout: const Duration(seconds: 5), iosAlertMessage: "Instant retry");
        await FlutterNfcKit.finish();
        setState(() => _sessionErrorResult =
            'Instant retry unexpectedly succeeded (no SystemIsBusy this run).');
        return;
      } on PlatformException catch (e) {
        setState(() => _sessionErrorResult =
            'Instant retry → code=${e.code} message=${e.message}');
        if (e.code != '503') return; // demo only continues if we actually got busy
      }

      // 3. Back off, then retry — the session should now recover.
      await Future.delayed(const Duration(seconds: 3));
      await FlutterNfcKit.poll(iosAlertMessage: "Retry after backoff");
      await FlutterNfcKit.finish();
      setState(() => _sessionErrorResult =
          'Got 503 SystemIsBusy on instant retry; recovered after 3s backoff. ✓');
    } on PlatformException catch (e) {
      setState(() => _sessionErrorResult = 'code=${e.code} message=${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
            title: const Text('NFC Flutter Kit Example App'),
            bottom: TabBar(
              tabs: <Widget>[
                Tab(text: 'Read'),
                Tab(text: 'Write'),
              ],
              controller: _tabController,
            )),
        body: TabBarView(controller: _tabController, children: <Widget>[
          Scrollbar(
              child: SingleChildScrollView(
                  child: Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                const SizedBox(height: 20),
                Text('Running on: $_platformVersion\nNFC: $_availability'),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      NFCTag tag = await FlutterNfcKit.poll();
                      setState(() {
                        _tag = tag;
                      });
                      await FlutterNfcKit.setIosAlertMessage(
                          "Working on it...");
                      _mifareResult = null;
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
                      } else if (tag.ndefAvailable ?? false) {
                        var ndefRecords = await FlutterNfcKit.readNDEFRecords();
                        var ndefString = '';
                        for (int i = 0; i < ndefRecords.length; i++) {
                          ndefString += '${i + 1}: ${ndefRecords[i]}\n';
                        }
                        setState(() {
                          _result = ndefString;
                        });
                      } else if (tag.type == NFCTagType.webusb) {
                        var r = await FlutterNfcKit.transceive(
                            "00A4040006D27600012401");
                        print(r);
                      }
                    } catch (e) {
                      setState(() {
                        _result = 'error: $e';
                      });
                    }

                    // Pretend that we are working
                    if (!kIsWeb) sleep(Duration(seconds: 1));
                    await FlutterNfcKit.finish(iosAlertMessage: "Finished!");
                  },
                  child: Text('Start polling'),
                ),
                const SizedBox(height: 10),
                const Divider(),
                const Text('Session error test (iOS)'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: _streamDummyData,
                      child:
                          Text(_streaming ? 'Stop streaming' : 'Stream dummy data'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _streaming ? null : _testSystemIsBusy,
                      child: const Text('Test SystemIsBusy'),
                    ),
                  ],
                ),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(_sessionErrorResult == null
                        ? 'Stream dummy data to keep the session busy, then tap Cancel '
                            'on the iOS sheet to see UserCanceled. SystemIsBusy is '
                            'OS-driven and may not reproduce every run.'
                        : 'Session error: $_sessionErrorResult')),
                const Divider(),
                const SizedBox(height: 10),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _tag != null
                        ? Text(
                            'ID: ${_tag!.id}\nStandard: ${_tag!.standard}\nType: ${_tag!.type}\nATQA: ${_tag!.atqa}\nSAK: ${_tag!.sak}\nHistorical Bytes: ${_tag!.historicalBytes}\nProtocol Info: ${_tag!.protocolInfo}\nApplication Data: ${_tag!.applicationData}\nHigher Layer Response: ${_tag!.hiLayerResponse}\nManufacturer: ${_tag!.manufacturer}\nSystem Code: ${_tag!.systemCode}\nDSF ID: ${_tag!.dsfId}\nNDEF Available: ${_tag!.ndefAvailable}\nNDEF Type: ${_tag!.ndefType}\nNDEF Writable: ${_tag!.ndefWritable}\nNDEF Can Make Read Only: ${_tag!.ndefCanMakeReadOnly}\nNDEF Capacity: ${_tag!.ndefCapacity}\nMifare Info:${_tag!.mifareInfo}\nTransceive Result:\n$_result\n\nBlock Message:\n$_mifareResult')
                        : const Text('No tag polled yet.')),
              ])))),
          Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: () async {
                          if (_records!.isNotEmpty) {
                            try {
                              NFCTag tag = await FlutterNfcKit.poll();
                              setState(() {
                                _tag = tag;
                              });
                              if (tag.type == NFCTagType.mifare_ultralight ||
                                  tag.type == NFCTagType.mifare_classic ||
                                  tag.type == NFCTagType.iso15693) {
                                await FlutterNfcKit.writeNDEFRecords(_records!);
                                setState(() {
                                  _writeResult = 'OK';
                                });
                              } else {
                                setState(() {
                                  _writeResult =
                                      'error: NDEF not supported: ${tag.type}';
                                });
                              }
                            } catch (e, stacktrace) {
                              setState(() {
                                _writeResult = 'error: $e';
                              });
                              print(stacktrace);
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
                      ElevatedButton(
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
                                          Navigator.pop(context);
                                          final result = await Navigator.push(
                                              context, MaterialPageRoute(
                                                  builder: (context) {
                                            return NDEFTextRecordSetting();
                                          }));
                                          if (result != null) {
                                            if (result is ndef.TextRecord) {
                                              setState(() {
                                                _records!.add(result);
                                              });
                                            }
                                          }
                                        },
                                      ),
                                      SimpleDialogOption(
                                        child: Text("Uri Record"),
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          final result = await Navigator.push(
                                              context, MaterialPageRoute(
                                                  builder: (context) {
                                            return NDEFUriRecordSetting();
                                          }));
                                          if (result != null) {
                                            if (result is ndef.UriRecord) {
                                              setState(() {
                                                _records!.add(result);
                                              });
                                            }
                                          }
                                        },
                                      ),
                                      SimpleDialogOption(
                                        child: Text("Raw Record"),
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          final result = await Navigator.push(
                                              context, MaterialPageRoute(
                                                  builder: (context) {
                                            return NDEFRecordSetting();
                                          }));
                                          if (result != null) {
                                            if (result is ndef.NDEFRecord) {
                                              setState(() {
                                                _records!.add(result);
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
                  const SizedBox(height: 10),
                  Text('Result: $_writeResult'),
                  const SizedBox(height: 10),
                  Expanded(
                    flex: 1,
                    child: ListView(
                        shrinkWrap: true,
                        children: List<Widget>.generate(
                            _records!.length,
                            (index) => GestureDetector(
                                  child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Text(
                                          'id:${_records![index].idString}\ntnf:${_records![index].tnf}\ntype:${_records![index].type?.toHexString()}\npayload:${_records![index].payload?.toHexString()}\n')),
                                  onTap: () async {
                                    final result = await Navigator.push(context,
                                        MaterialPageRoute(builder: (context) {
                                      return NDEFRecordSetting(
                                          record: _records![index]);
                                    }));
                                    if (result != null) {
                                      if (result is ndef.NDEFRecord) {
                                        setState(() {
                                          _records![index] = result;
                                        });
                                      } else if (result is String &&
                                          result == "Delete") {
                                        _records!.removeAt(index);
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

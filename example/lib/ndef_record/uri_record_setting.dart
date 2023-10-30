import 'package:flutter/material.dart';

import 'package:ndef/ndef.dart' as ndef;

class NDEFUriRecordSetting extends StatefulWidget {
  final ndef.UriRecord record;
  NDEFUriRecordSetting({Key? key, ndef.UriRecord? record})
      : record = record ?? ndef.UriRecord(prefix: '', content: ''),
        super(key: key);
  @override
  _NDEFUriRecordSetting createState() => _NDEFUriRecordSetting();
}

class _NDEFUriRecordSetting extends State<NDEFUriRecordSetting> {
  GlobalKey _formKey = new GlobalKey<FormState>();
  late TextEditingController _contentController;
  String? _dropButtonValue;

  @override
  initState() {
    super.initState();

    _contentController = new TextEditingController.fromValue(
        TextEditingValue(text: widget.record.content!));
    _dropButtonValue = widget.record.prefix;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
            appBar: AppBar(
              title: Text('Set Record'),
            ),
            body: Center(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.always,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            DropdownButton(
                              value: _dropButtonValue,
                              items: ndef.UriRecord.prefixMap.map((value) {
                                return DropdownMenuItem<String>(
                                    child: Text(value), value: value);
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _dropButtonValue = value as String?;
                                });
                              },
                            ),
                            TextFormField(
                              decoration: InputDecoration(labelText: 'content'),
                              controller: _contentController,
                            ),
                            ElevatedButton(
                              child: Text('OK'),
                              onPressed: () {
                                if ((_formKey.currentState as FormState)
                                    .validate()) {
                                  Navigator.pop(
                                      context,
                                      ndef.UriRecord(
                                        prefix: _dropButtonValue,
                                        content: (_contentController.text),
                                      ));
                                }
                              },
                            ),
                          ],
                        ))))));
  }
}

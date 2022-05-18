import 'package:flutter/material.dart';

import 'package:ndef/ndef.dart' as ndef;

class TextRecordSetting extends StatefulWidget {
  final ndef.TextRecord record;
  TextRecordSetting({Key? key, ndef.TextRecord? record})
      : record = record ?? ndef.TextRecord(language: 'en', text: ''),
        super(key: key);
  @override
  _TextRecordSetting createState() => _TextRecordSetting();
}

class _TextRecordSetting extends State<TextRecordSetting> {
  GlobalKey _formKey = new GlobalKey<FormState>();
  late TextEditingController _languageController;
  late TextEditingController _textController;
  late int _dropButtonValue;

  @override
  initState() {
    super.initState();

    _languageController = new TextEditingController.fromValue(
        TextEditingValue(text: widget.record.language!));
    _textController = new TextEditingController.fromValue(
        TextEditingValue(text: widget.record.text!));
    _dropButtonValue = ndef.TextEncoding.values.indexOf(widget.record.encoding);
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
                              items: [
                                DropdownMenuItem(
                                    child: Text('UTF-8'), value: 0),
                                DropdownMenuItem(
                                    child: Text('UTF-16'), value: 1),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _dropButtonValue = value as int;
                                });
                              },
                            ),
                            TextFormField(
                              decoration:
                                  InputDecoration(labelText: 'language'),
                              validator: (v) {
                                return v!.trim().length % 2 == 0
                                    ? null
                                    : 'length must not be blank';
                              },
                              controller: _languageController,
                            ),
                            TextFormField(
                              decoration: InputDecoration(labelText: 'text'),
                              controller: _textController,
                            ),
                            ElevatedButton(
                              child: Text('OK'),
                              onPressed: () {
                                if ((_formKey.currentState as FormState)
                                    .validate()) {
                                  Navigator.pop(
                                      context,
                                      ndef.TextRecord(
                                          encoding: ndef.TextEncoding
                                              .values[_dropButtonValue],
                                          language: (_languageController.text),
                                          text: (_textController.text)));
                                }
                              },
                            ),
                          ],
                        ))))));
  }
}

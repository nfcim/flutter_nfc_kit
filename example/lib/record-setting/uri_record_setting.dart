import 'package:flutter/material.dart';

import 'package:ndef/ndef.dart' as ndef;

class UriRecordSetting extends StatefulWidget {
  ndef.UriRecord record;
  UriRecordSetting({Key key, ndef.UriRecord record}) : super(key: key) {
    if(record==null) {
      this.record = ndef.UriRecord(uriData: '', uriPrefix: '');
    } else {
      this.record = record;
    }
  }
  @override
  _UriRecordSetting createState() => _UriRecordSetting();
}

class _UriRecordSetting extends State<UriRecordSetting> {
  GlobalKey _formKey = new GlobalKey<FormState>();
  TextEditingController _contentController;
  String _dropButtonValue;

  @override
  initState() {
    _contentController = new TextEditingController.fromValue(
        TextEditingValue(text: widget.record.uriData));
    _dropButtonValue = widget.record.uriPrefix;
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
                          items: ndef.UriRecord.uriPrefixMap.map((value){
                            return DropdownMenuItem<String>(child: Text(value),value: value);
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _dropButtonValue = value;
                            });
                          },
                        ),
                        TextFormField(
                          decoration: InputDecoration(labelText: 'content'),
                          controller: _contentController,
                        ),
                        RaisedButton(
                          child: Text('OK'),
                          onPressed: () {
                            if ((_formKey.currentState as FormState)
                                .validate()) {
                              Navigator.pop(
                                  context,
                                  ndef.UriRecord(
                                      uriPrefix: _dropButtonValue,
                                      uriData:
                                          (_contentController.text == null
                                              ? ""
                                              : _contentController.text),
                                      ));
                            }
                          },
                        ),
                      ],
                    )))));
  }
}
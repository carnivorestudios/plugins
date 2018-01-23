// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Image Picker Demo',
      home: new MyHomePage(title: 'Image Picker Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Future<File> _imageFile;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: const Text('Image Picker Example'),
      ),
      body: new Column(children: <Widget>[
        new FutureBuilder<File>(
            future: _imageFile,
            builder: (BuildContext context, AsyncSnapshot<File> snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return new Image.file(snapshot.data);
              } else {
                return const Text('You have not yet picked an image.');
              }
            }),
        new RaisedButton(
          onPressed: () {
            setState(() {
              _imageFile = ImagePicker.pickImage(
                type: ImageType.video,
              );
            });
          },
          child: new Text("Pick Video"),
        ),
        new RaisedButton(
          onPressed: () {
            setState(() {
              _imageFile = ImagePicker.pickImage(
                type: ImageType.picture,
              );
            });
          },
          child: new Text("Pick Image"),
        ),
      ]),
    );
  }
}

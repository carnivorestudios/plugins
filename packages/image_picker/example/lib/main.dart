// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
  List<File> _imageFiles;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: const Text('Image Picker Example'),
      ),
      body: new Center(
        child: _imageFiles != null
            ? new GridView.extent(
                maxCrossAxisExtent: 120.0,
                children: _imageFiles.map((f) {
                  return new Image.file(f);
                }).toList(growable: false),
              )
            : const Text('You have not yet picked an image.'),
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: () async {
          final List<File> selectedFiles = await ImagePicker.pickImage(
            folderMode: true,
            selectMode: SelectMode.multi,
            includeVideo: true,
          );

          setState(() {
            _imageFiles = selectedFiles;
          });
        },
        tooltip: 'Pick Image',
        child: new Icon(Icons.add_a_photo),
      ),
    );
  }
}

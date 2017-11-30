import 'package:chq_native_ads/chq_native_ads.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(new MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: const Text('ChqNativeAd Example'),
        ),
        body: new Center(
          child: new ChqNativeAd(),
        ),
      ),
    );
  }
}

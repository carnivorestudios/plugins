// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of firebase_storage;

class FirebaseStorage {
  static const MethodChannel _channel =
      const MethodChannel('plugins.flutter.io/firebase_storage');

  static bool _initialized = false;

  // TODO: change "const FirebaseApp()" to "FirebaseApp.instance" after firebase_core is updated to latest version
  FirebaseStorage({FirebaseApp app, this.bucketURL})
      : this.app = app ?? const FirebaseApp() {
    if (_initialized) return;
    _channel.setMethodCallHandler((MethodCall call) {
      _methodStreamController.add(call);
    });
    _initialized = true;
  }

  /// Used to dispatch method calls
  final StreamController<MethodCall> _methodStreamController =
      new StreamController.broadcast(); // ignore: close_sinks
  Stream<MethodCall> get _methodStream => _methodStreamController.stream;

  /// Gets the instance of FirebaseStorage for the default Firebase app.
  static final FirebaseStorage instance = new FirebaseStorage();

  /// The [FirebaseApp] instance to which this [FirebaseStorage] belongs.
  ///
  /// If null, the default [FirebaseApp] is used.
  final FirebaseApp app;

  /// The URL to which this [FirebaseStorage] belongs
  ///
  /// If null, the URL of the specified [FirebaseApp] is used
  final String bucketURL;

  @override
  bool operator ==(dynamic o) => o is FirebaseStorage && o.app == app;

  @override
  int get hashCode => app.hashCode;

  /// Gets a DatabaseReference for the root of your Firebase Database.
  StorageReference reference() => new StorageReference._(this, <String>[]);
}

/// Metadata for a [StorageReference]. Metadata stores default attributes such as
/// size and content type.
class StorageMetadata {
  const StorageMetadata({
    this.cacheControl,
    this.contentDisposition,
    this.contentEncoding,
    this.contentLanguage,
    this.contentType,
  })  : bucket = null,
        generation = null,
        metadataGeneration = null,
        path = null,
        name = null,
        sizeBytes = null,
        creationTimeMillis = null,
        updatedTimeMillis = null,
        md5Hash = null;

  StorageMetadata._fromMap(Map<dynamic, dynamic> map)
      : bucket = map['bucket'],
        generation = map['generation'],
        metadataGeneration = map['metadataGeneration'],
        path = map['path'],
        name = map['name'],
        sizeBytes = map['sizeBytes'],
        creationTimeMillis = map['creationTimeMillis'],
        updatedTimeMillis = map['updatedTimeMillis'],
        md5Hash = map['md5Hash'],
        cacheControl = map['cacheControl'],
        contentDisposition = map['contentDisposition'],
        contentLanguage = map['contentLanguage'],
        contentType = map['contentType'],
        contentEncoding = map['contentEncoding'];

  /// The owning Google Cloud Storage bucket for the [StorageReference].
  final String bucket;

  /// A version String indicating what version of the [StorageReference].
  final String generation;

  /// A version String indicating the version of this [StorageMetadata].
  final String metadataGeneration;

  /// The path of the [StorageReference] object.
  final String path;

  /// A simple name of the [StorageReference] object.
  final String name;

  /// The stored Size in bytes of the [StorageReference] object.
  final int sizeBytes;

  /// The time the [StorageReference] was created in milliseconds since the epoch.
  final int creationTimeMillis;

  /// The time the [StorageReference] was last updated in milliseconds since the epoch.
  final int updatedTimeMillis;

  /// The MD5Hash of the [StorageReference] object.
  final String md5Hash;

  /// The Cache Control setting of the [StorageReference].
  final String cacheControl;

  /// The content disposition of the [StorageReference].
  final String contentDisposition;

  /// The content encoding for the [StorageReference].
  final String contentEncoding;

  /// The content language for the StorageReference, specified as a 2-letter
  /// lowercase language code defined by ISO 639-1.
  final String contentLanguage;

  /// The content type (MIME type) of the [StorageReference].
  final String contentType;
}

// Copyright 2017, the Flutter project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of firebase_storage;

/// Represents a UploadTask
/// This class should manage all state of the upload task from platform side
abstract class UploadTask {
  UploadTask({
    @required FirebaseStorage storage,
    @required StorageReference reference,
    StorageMetadata metadata,
  })  : _storage = storage,
        _reference = reference,
        _metadata = metadata,
        assert(storage != null);

  final FirebaseStorage _storage;
  final StorageMetadata _metadata;
  final StorageReference _reference;

  Future<dynamic> _platformMethod();

  int _handle;

  bool isCanceled = false;
  bool isComplete = false;
  bool isInProgress = false;
  bool isPaused = false;
  bool isSuccessful = false;

  Completer<StorageTaskSnapshot> _completer =
      new Completer<StorageTaskSnapshot>();
  Future<StorageTaskSnapshot> get onComplete => _completer.future;

  StreamController<StorageTaskSnapshot> _snapshotController =
      new StreamController<StorageTaskSnapshot>();
  Stream<StorageTaskSnapshot> get progress => _snapshotController.stream;

  /// Returns a StorageTaskSnapshot on complete, or throws error
  Future<StorageTaskSnapshot> _start({
    void onSuccess(StorageTaskSnapshot s),
    void onFailure(StorageTaskSnapshot s),
    void onProgress(StorageTaskSnapshot s),
    void onPause(StorageTaskSnapshot s),
    void onResume(StorageTaskSnapshot s),
  }) async {
    _handle = await _platformMethod().then<int>((dynamic result) => result);
    return await _storage._methodStream
        .where((MethodCall m) => m.method == 'StorageTaskEvent')
        .where((MethodCall m) => m.arguments['handle'] == _handle)
        .map((m) {
          print(m.method);
          print(m.arguments);
          return m;
        })
        .map<Map<dynamic, dynamic>>((m) => m.arguments)
        .map<StorageTaskEvent>(
            (m) => new StorageTaskEvent._(m['type'], m['snapshot']))
        .map<StorageTaskEvent>((e) {
          _resetState();
          Function callback;
          switch (e.type) {
            case StorageTaskEventType.progress:
              print('ON PROGRESS');
              callback = onProgress;
              isInProgress = true;
              break;
            case StorageTaskEventType.resume:
              print('ON RESUME');
              callback = onResume;
              isInProgress = true;
              break;
            case StorageTaskEventType.pause:
              print('ON PAUSE');
              callback = onPause;
              isPaused = true;
              break;
            case StorageTaskEventType.success:
              print('ON SUCCESS');
              callback = onSuccess;
              isSuccessful = true;
              isComplete = true;
              _completer.complete(e.snapshot);
              break;
            case StorageTaskEventType.failure:
              print('ON FAILURE');
              callback = onFailure;
              isComplete = true;
              final error = Exception(
                  'FirebaseStorage file failed to upload: ${e.snapshot.error}');
              _completer.completeError(error);
              throw error;
              break;
          }
          if (callback != null) {
            callback(e.snapshot);
          }
          return e;
        })
        .firstWhere((e) => e.type == StorageTaskEventType.success)
        .then<StorageTaskSnapshot>((event) => event.snapshot);
  }

  void _resetState() {
    isCanceled = false;
    isComplete = false;
    isInProgress = false;
    isPaused = false;
    isSuccessful = false;
  }

  /// Pause the upload
  void pause() => FirebaseStorage._channel
      .invokeMethod('UploadTask#pause', <String, dynamic>{'handle': _handle});

  /// Resume the upload
  void resume() => FirebaseStorage._channel
      .invokeMethod('UploadTask#resume', <String, dynamic>{'handle': _handle});

  /// Cancel the upload
  void cancel() => FirebaseStorage._channel
      .invokeMethod('UploadTask#cancel', <String, dynamic>{'handle': _handle});
}

class FileUploadTask extends UploadTask {
  FileUploadTask({
    @required FirebaseStorage storage,
    @required StorageReference reference,
    StorageMetadata metadata,
    @required this.file,
  }) : super(storage: storage, reference: reference, metadata: metadata);

  final File file;

  @override
  Future<dynamic> _platformMethod() {
    return FirebaseStorage._channel.invokeMethod(
      'StorageReference#putFile',
      <String, dynamic>{
        'app': _storage.app?.name,
        'databaseURL': _storage.bucketURL,
        'filename': file.absolute.path,
        'path': _reference.path,
        'metadata':
            _metadata == null ? null : _buildMetadataUploadMap(_metadata),
      },
    );
  }
}

class DataUploadTask extends UploadTask {
  DataUploadTask({
    @required FirebaseStorage storage,
    @required StorageReference reference,
    StorageMetadata metadata,
    @required this.data,
  }) : super(storage: storage, reference: reference, metadata: metadata);

  final Uint8List data;

  @override
  Future<dynamic> _platformMethod() {
    return FirebaseStorage._channel.invokeMethod(
      'StorageReference#putFile',
      <String, dynamic>{
        'app': _storage.app?.name,
        'databaseURL': _storage.bucketURL,
        'data': data,
        'path': _reference.path,
        'metadata':
            _metadata == null ? null : _buildMetadataUploadMap(_metadata),
      },
    );
  }
}

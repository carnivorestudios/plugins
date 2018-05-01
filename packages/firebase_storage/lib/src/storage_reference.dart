part of firebase_storage;

class StorageReference {
  StorageReference._(
    FirebaseStorage storage,
    List<String> pathComponents,
  )   : _storage = storage,
        _pathComponents = pathComponents,
        assert(storage != null);

  final FirebaseStorage _storage;
  final List<String> _pathComponents;

  /// Returns a new instance of [StorageReference] pointing to a child
  /// location of the current reference.
  StorageReference child(String path) {
    return new StorageReference._(_storage,
        new List<String>.from(_pathComponents)..addAll(path.split("/")));
  }

  /// Returns a new instance of [StorageReference] pointing to the parent
  /// location or null if this instance references the root location.
  StorageReference parent() {
    if (_pathComponents.isEmpty ||
        _pathComponents.every((String e) => e.isEmpty)) {
      return null;
    }

    final List<String> parentPath = new List<String>.from(_pathComponents);
    // Trim for trailing empty path components that can
    // come from trailing slashes in the path.
    while (parentPath.last.isEmpty) {
      parentPath.removeLast();
    }
    parentPath.removeLast();

    return new StorageReference._(_storage, parentPath);
  }

  /// Returns a new instance of [StorageReference] pointing to the root location.
  StorageReference root() {
    return new StorageReference._(_storage, <String>[]);
  }

  /// Returns the [FirebaseStorage] service which created this reference.
  FirebaseStorage getStorage() {
    return _storage;
  }

  /// Asynchronously uploads a file to the currently specified
  /// [StorageReference], with an optional [metadata].
  UploadTask putFile(
    File file, {
    StorageMetadata metadata,
    void onSuccess(StorageTaskSnapshot s),
    void onFailure(StorageTaskSnapshot s),
    void onProgress(StorageTaskSnapshot s),
    void onPause(StorageTaskSnapshot s),
    void onResume(StorageTaskSnapshot s),
  }) {
    final UploadTask task = new FileUploadTask(
      storage: _storage,
      reference: this,
      file: file,
      metadata: metadata,
    );
    task._start(
      onProgress: onProgress,
      onFailure: onFailure,
      onPause: onPause,
      onSuccess: onSuccess,
      onResume: onResume,
    );
    return task;
  }

  /// Asynchronously uploads byte data to the currently specified
  /// [StorageReference], with an optional [metadata].
  UploadTask putData(
    Uint8List data, {
    StorageMetadata metadata,
    void onSuccess(StorageTaskSnapshot s),
    void onFailure(StorageTaskSnapshot s),
    void onProgress(StorageTaskSnapshot s),
    void onPause(StorageTaskSnapshot s),
    void onResume(StorageTaskSnapshot s),
  }) {
    final UploadTask task = new DataUploadTask(
      storage: _storage,
      reference: this,
      data: data,
      metadata: metadata,
    );
    task._start(
      onProgress: onProgress,
      onFailure: onFailure,
      onPause: onPause,
      onSuccess: onSuccess,
      onResume: onResume,
    );
    return task;
  }

  /// Returns the Google Cloud Storage bucket that holds this object.
  Future<String> getBucket() async {
    return await FirebaseStorage._channel
        .invokeMethod("StorageReference#getBucket", <String, String>{
      'path': _pathComponents.join("/"),
    });
  }

  /// Returns the full path to this object, not including the Google Cloud
  /// Storage bucket.
  Future<String> getPath() async {
    return await FirebaseStorage._channel
        .invokeMethod("StorageReference#getPath", <String, String>{
      'path': _pathComponents.join("/"),
    });
  }

  /// Returns the short name of this object.
  Future<String> getName() async {
    return await FirebaseStorage._channel
        .invokeMethod("StorageReference#getName", <String, String>{
      'path': _pathComponents.join("/"),
    });
  }

  /// Asynchronously downloads the object at the StorageReference to a list in memory.
  /// A list of the provided max size will be allocated.
  Future<Uint8List> getData(int maxSize) async {
    return await FirebaseStorage._channel.invokeMethod(
      "StorageReference#getData",
      <String, dynamic>{
        'maxSize': maxSize,
        'path': _pathComponents.join("/"),
      },
    );
  }

  /// Asynchronously retrieves a long lived download URL with a revokable token.
  /// This can be used to share the file with others, but can be revoked by a
  /// developer in the Firebase Console if desired.
  Future<dynamic> getDownloadURL() async {
    return await FirebaseStorage._channel
        .invokeMethod("StorageReference#getDownloadUrl", <String, String>{
      'path': _pathComponents.join("/"),
    });
  }

  Future<void> delete() {
    return FirebaseStorage._channel.invokeMethod("StorageReference#delete",
        <String, String>{'path': _pathComponents.join("/")});
  }

  /// Retrieves metadata associated with an object at this [StorageReference].
  Future<StorageMetadata> getMetadata() async {
    return new StorageMetadata._fromMap(await FirebaseStorage._channel
        .invokeMethod("StorageReference#getMetadata", <String, String>{
      'path': _pathComponents.join("/"),
    }));
  }

  /// Updates the metadata associated with this [StorageReference].
  ///
  /// Returns a [Future] that will complete to the updated [StorageMetadata].
  ///
  /// This method ignores fields of [metadata] that cannot be set by the public
  /// [StorageMetadata] constructor. Writable metadata properties can be deleted
  /// by passing the empty string.
  Future<StorageMetadata> updateMetadata(StorageMetadata metadata) async {
    return new StorageMetadata._fromMap(await FirebaseStorage._channel
        .invokeMethod("StorageReference#updateMetadata", <String, dynamic>{
      'path': _pathComponents.join("/"),
      'metadata': metadata == null ? null : _buildMetadataUploadMap(metadata),
    }));
  }

  String get path => _pathComponents.join('/');
}

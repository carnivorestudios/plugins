// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.firebase.storage;

import android.net.Uri;
import android.support.annotation.NonNull;
import android.util.SparseArray;

import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.FirebaseApp;
import com.google.firebase.storage.FirebaseStorage;
import com.google.firebase.storage.OnPausedListener;
import com.google.firebase.storage.OnProgressListener;
import com.google.firebase.storage.StorageMetadata;
import com.google.firebase.storage.StorageReference;
import com.google.firebase.storage.UploadTask;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import java.io.File;
import java.util.HashMap;
import java.util.Map;

/** FirebaseStoragePlugin */
public class FirebaseStoragePlugin implements MethodCallHandler {

  private final MethodChannel channel;

  private int nextHandle = 0;
  private final SparseArray<UploadTask> uploadTasks = new SparseArray<>();

  public static void registerWith(Registrar registrar) {
    final MethodChannel channel =
        new MethodChannel(registrar.messenger(), "plugins.flutter.io/firebase_storage");
    channel.setMethodCallHandler(new FirebaseStoragePlugin(channel));
  }

  private FirebaseStoragePlugin(MethodChannel channel) {
    this.channel = channel;
  }

  @Override
  public void onMethodCall(MethodCall call, final Result result) {
    final Map<String, Object> arguments = call.arguments();
    FirebaseStorage storage;
    String appName = (String) arguments.get("app");
    String bucketURL = (String) arguments.get("bucketURL");
    if (appName != null && bucketURL != null) {
      storage = FirebaseStorage.getInstance(FirebaseApp.getInstance(appName), bucketURL);
    } else if (appName != null) {
      storage = FirebaseStorage.getInstance(FirebaseApp.getInstance(appName));
    } else if (bucketURL != null) {
      storage = FirebaseStorage.getInstance(bucketURL);
    } else {
      storage = FirebaseStorage.getInstance();
    }

    // Common arguments among all methods
    String path = (String) arguments.get("path");
    StorageReference ref = null;
    if(path != null) {
      ref = storage.getReference().child(path);
    }
    @SuppressWarnings("unchecked")
    Map<String, Object> metadata = (Map<String, Object>) arguments.get("metadata");

    switch (call.method) {
      case "StorageReference#putFile":
      {
        String filename = (String) arguments.get("filename");
        File file = new File(filename);
        UploadTask uploadTask;
        if (metadata == null) {
          uploadTask = ref.putFile(Uri.fromFile(file));
        } else {
          uploadTask = ref.putFile(Uri.fromFile(file), buildMetadataFromMap(metadata));
        }
        final int handle = addListeners(uploadTask);
        result.success(handle);
        break;
      }
      case "StorageReference#putData":
      {
        byte[] bytes = (byte[]) arguments.get("data");
        UploadTask uploadTask;
        if (metadata == null) {
          uploadTask = ref.putBytes(bytes);
        } else {
          uploadTask = ref.putBytes(bytes, buildMetadataFromMap(metadata));
        }
        final int handle = addListeners(uploadTask);
        result.success(handle);
        break;
      }
      case "StorageReference#getData": {
        Integer maxSize = (Integer) arguments.get("maxSize");
        Task<byte[]> downloadTask = ref.getBytes(maxSize);
        downloadTask.addOnSuccessListener(
            new OnSuccessListener<byte[]>() {
              @Override
              public void onSuccess(byte[] bytes) {
                result.success(bytes);
              }
            });
        downloadTask.addOnFailureListener(
            new OnFailureListener() {
              @Override
              public void onFailure(@NonNull Exception e) {
                result.error("download_error", e.getMessage(), null);
              }
            });
        break;
      }
      case "StorageReference#delete":
      {
        final Task<Void> deleteTask = ref.delete();
        deleteTask.addOnSuccessListener(
            new OnSuccessListener<Void>() {
              @Override
              public void onSuccess(Void aVoid) {
                result.success(null);
              }
            });
        deleteTask.addOnFailureListener(
            new OnFailureListener() {
              @Override
              public void onFailure(@NonNull Exception e) {
                result.error("deletion_error", e.getMessage(), null);
              }
            });
        break;
      }
      case "StorageReference#getBucket": {
        result.success(ref.getBucket());
        break;
      }
      case "StorageReference#getName": {
        result.success(ref.getName());
        break;
      }
      case "StorageReference#getPath": {
        result.success(ref.getPath());
        break;
      }
      case "StorageReference#getDownloadUrl": {
        ref.getDownloadUrl()
            .addOnSuccessListener(
                new OnSuccessListener<Uri>() {
                  @Override
                  public void onSuccess(Uri uri) {
                    result.success(uri.toString());
                  }
                })
            .addOnFailureListener(
                new OnFailureListener() {
                  @Override
                  public void onFailure(@NonNull Exception e) {
                    result.error("download_error", e.getMessage(), null);
                  }
                });
        break;
      }
      case "StorageReference#getMetadata": {
        ref.getMetadata()
            .addOnSuccessListener(
                new OnSuccessListener<StorageMetadata>() {
                  @Override
                  public void onSuccess(StorageMetadata storageMetadata) {
                    result.success(buildMapFromMetadata(storageMetadata));
                  }
                })
            .addOnFailureListener(
                new OnFailureListener() {
                  @Override
                  public void onFailure(@NonNull Exception e) {
                    result.error("metadata_error", e.getMessage(), null);
                  }
                });
        break;
      }
      case "StorageReference#updateMetadata": {
        ref.updateMetadata(buildMetadataFromMap(metadata))
            .addOnSuccessListener(
                new OnSuccessListener<StorageMetadata>() {
                  @Override
                  public void onSuccess(StorageMetadata storageMetadata) {
                    result.success(buildMapFromMetadata(storageMetadata));
                  }
                })
            .addOnFailureListener(
                new OnFailureListener() {
                  @Override
                  public void onFailure(@NonNull Exception e) {
                    result.error("metadata_error", e.getMessage(), null);
                  }
                });
        break;
      }
      case "UploadTask#pause": {
        int handle = (Integer) arguments.get("handle");
        UploadTask task = uploadTasks.get(handle);
        if(task != null) {
          task.pause();
        }
        result.success(null);
        break;
      }
      case "UploadTask#resume": {
        int handle = (Integer) arguments.get("handle");
        UploadTask task = uploadTasks.get(handle);
        if(task != null) {
          task.resume();
        }
        result.success(null);
        break;
      }
      case "UploadTask#cancel": {
        int handle = (Integer) arguments.get("handle");
        UploadTask task = uploadTasks.get(handle);
        if(task != null) {
          task.cancel();
        }
        result.success(null);
        break;
      }
      default:
        result.notImplemented();
        break;
    }
  }

  private int addListeners(final UploadTask task) {
    final int handle = ++nextHandle;
    task.addOnSuccessListener(
        new OnSuccessListener<UploadTask.TaskSnapshot>() {
          @Override
          public void onSuccess(UploadTask.TaskSnapshot snapshot) {
            invokeStorageTaskEvent(handle, StorageTaskEventType.success, snapshot, null);
          }
        });
    task.addOnProgressListener(
        new OnProgressListener<UploadTask.TaskSnapshot>() {
          @Override
          public void onProgress(UploadTask.TaskSnapshot snapshot) {
            invokeStorageTaskEvent(handle, StorageTaskEventType.progress, snapshot, null);
          }
        }
    );
    task.addOnPausedListener(
        new OnPausedListener<UploadTask.TaskSnapshot>() {
          @Override
          public void onPaused(UploadTask.TaskSnapshot snapshot) {
            invokeStorageTaskEvent(handle, StorageTaskEventType.pause, snapshot, null);
          }
        }
    );
    task.addOnCompleteListener(
        new OnCompleteListener<UploadTask.TaskSnapshot>() {
          @Override
          public void onComplete(@NonNull Task<UploadTask.TaskSnapshot> task) {
            uploadTasks.remove(handle);
          }
        }
    );
    task.addOnFailureListener(
        new OnFailureListener() {
          @Override
          public void onFailure(@NonNull Exception e) {
            invokeStorageTaskEvent(handle, StorageTaskEventType.failure, task.getSnapshot(), e);
          }
        });
    uploadTasks.put(handle, task);
    return handle;
  }

  private enum StorageTaskEventType {
    resume,
    progress,
    pause,
    success,
    failure
  }

  private void invokeStorageTaskEvent(int handle, StorageTaskEventType type, UploadTask.TaskSnapshot snapshot, Exception error) {
    channel.invokeMethod(
        "StorageTaskEvent",
        buildMapFromTaskEvent(handle, type, snapshot, error)
    );
  }

  private Map<String, Object> buildMapFromTaskEvent(int handle, StorageTaskEventType type, UploadTask.TaskSnapshot snapshot, Exception error) {
    Map<String, Object> map = new HashMap<>();
    map.put("handle", handle);
    map.put("type", type.ordinal());
    map.put("snapshot", buildMapFromTaskSnapshot(snapshot, error));
    return map;
  }

  private Map<String, Object> buildMapFromTaskSnapshot(UploadTask.TaskSnapshot snapshot, Exception error) {
    Map<String, Object> map = new HashMap<>();
    if(snapshot.getDownloadUrl() != null) {
      map.put("downloadUrl", snapshot.getDownloadUrl().toString());
    }
    map.put("bytesTransferred", snapshot.getBytesTransferred());
    map.put("totalByteCount", snapshot.getTotalByteCount());
    if(snapshot.getUploadSessionUri() != null) {
      map.put("uploadSessionUri", snapshot.getUploadSessionUri().toString());
    }
    if(error != null) {
      map.put("error", error.getMessage());
    }
    if(snapshot.getMetadata() != null) {
      map.put("storageMetadata", buildMapFromMetadata(snapshot.getMetadata()));
    }
    return map;
  }

  private StorageMetadata buildMetadataFromMap(Map<String, Object> map) {
    StorageMetadata.Builder builder = new StorageMetadata.Builder();
    builder.setCacheControl((String) map.get("cacheControl"));
    builder.setContentEncoding((String) map.get("contentEncoding"));
    builder.setContentDisposition((String) map.get("contentDisposition"));
    builder.setContentLanguage((String) map.get("contentLanguage"));
    builder.setContentType((String) map.get("contentType"));
    return builder.build();
  }

  private Map<String, Object> buildMapFromMetadata(StorageMetadata storageMetadata) {
    Map<String, Object> map = new HashMap<>();
    map.put("name", storageMetadata.getName());
    map.put("bucket", storageMetadata.getBucket());
    map.put("generation", storageMetadata.getGeneration());
    map.put("metadataGeneration", storageMetadata.getMetadataGeneration());
    map.put("path", storageMetadata.getPath());
    map.put("sizeBytes", storageMetadata.getSizeBytes());
    map.put("creationTimeMillis", storageMetadata.getCreationTimeMillis());
    map.put("updatedTimeMillis", storageMetadata.getUpdatedTimeMillis());
    map.put("md5Hash", storageMetadata.getMd5Hash());
    map.put("cacheControl", storageMetadata.getCacheControl());
    map.put("contentDisposition", storageMetadata.getContentDisposition());
    map.put("contentEncoding", storageMetadata.getContentEncoding());
    map.put("contentLanguage", storageMetadata.getContentLanguage());
    map.put("contentType", storageMetadata.getContentType());
    return map;
  }
}

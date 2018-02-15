import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_example/video_classes.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';

class MediaFileView extends StatelessWidget {
  final ImageResult image;

  MediaFileView(this.image);
  @override
  Widget build(BuildContext context) {
    final String mimeType = lookupMimeType(image.file.path);

    final bool isVideo = mimeType?.startsWith("video") ?? false;
    final bool isImage = mimeType?.startsWith("image") ?? false;

    if (isVideo) {
      return new Image.file(image.thumb);
    }
    if (isImage) {
      return new Image.file(image.file);
    }
    return const Text("Unsupported MIME type");
  }
}

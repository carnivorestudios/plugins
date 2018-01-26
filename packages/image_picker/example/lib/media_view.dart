import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker_example/video_player_view.dart';
import 'package:mime/mime.dart';

class MediaFileView extends StatelessWidget {
  final File file;

  MediaFileView(this.file);
  @override
  Widget build(BuildContext context) {
    final String mimeType = lookupMimeType(file.path);

    final bool isVideo = mimeType.startsWith("video");
    final bool isImage = mimeType.startsWith("image");

    if(isVideo) {
      return new VideoPlayerView(file);
    }
    if (isImage) {
      return new Image.file(file);
    }
    return const Text("Unsupported MIME type");
  }
}

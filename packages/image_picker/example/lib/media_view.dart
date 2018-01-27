import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker_example/video_classes.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';

class MediaFileView extends StatelessWidget {
  final File file;

  MediaFileView(this.file);
  @override
  Widget build(BuildContext context) {
    final String mimeType = lookupMimeType(file.path);

    final bool isVideo = mimeType.startsWith("video");
    final bool isImage = mimeType.startsWith("image");

    if (isVideo) {
      return new PlayerLifeCycle(
        file.uri.toString(),
        (BuildContext context, VideoPlayerController controller) =>
            new AspectRatioVideo(controller),
      );
    }
    if (isImage) {
      return new Image.file(file);
    }
    return const Text("Unsupported MIME type");
  }
}

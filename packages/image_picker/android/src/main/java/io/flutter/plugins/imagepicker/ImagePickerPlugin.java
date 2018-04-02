// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.imagepicker;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.ExifInterface;
import android.media.MediaMetadataRetriever;
import android.util.Log;
import android.webkit.MimeTypeMap;

import com.esafirm.imagepicker.features.ImagePicker;
import com.esafirm.imagepicker.features.camera.DefaultCameraModule;
import com.esafirm.imagepicker.features.camera.OnImageReadyListener;
import com.esafirm.imagepicker.model.Image;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener;

/**
 * Location Plugin
 */
public class ImagePickerPlugin implements MethodCallHandler, ActivityResultListener {
    private static String TAG = "ImagePicker";
    private static final String CHANNEL = "plugins.flutter.io/image_picker";

    public static final int REQUEST_CODE_PICK = 2342;
    public static final int REQUEST_CODE_CAMERA = 2343;

    private static final int SOURCE_ASK_USER = 0;
    private static final int SOURCE_CAMERA = 1;
    private static final int SOURCE_GALLERY = 2;

    private static final int MODE_SINGLE = 0;
    private static final int MODE_MULTI = 1;

    private static final DefaultCameraModule cameraModule = new DefaultCameraModule();

    private final PluginRegistry.Registrar registrar;

    // Pending method call to obtain an image
    private Result pendingResult;
    private MethodCall methodCall;

    public static void registerWith(PluginRegistry.Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), CHANNEL);
        final ImagePickerPlugin instance = new ImagePickerPlugin(registrar);
        registrar.addActivityResultListener(instance);
        channel.setMethodCallHandler(instance);
    }

    private ImagePickerPlugin(PluginRegistry.Registrar registrar) {
        this.registrar = registrar;
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        if (pendingResult != null) {
            result.error("ALREADY_ACTIVE", "Image picker is already active", null);
            return;
        }

        Activity activity = registrar.activity();
        if (activity == null) {
            result.error("no_activity", "image_picker plugin requires a foreground activity.", null);
            return;
        }

        pendingResult = result;
        methodCall = call;

        if (call.method.equals("pickImage")) {
            int imageSource = call.argument("source");
            boolean folderMode = call.argument("folderMode");
            boolean includeVideo = call.argument("includeVideo");
            int mode = call.argument("mode");
            int maxItems = call.argument("maxItems");

            ImagePicker picker = ImagePicker.create(activity);

            switch (mode) {
                case MODE_SINGLE:
                    picker = picker.single();
                    break;
                case MODE_MULTI:
                    picker = picker.multi();
                    break;
                default:
                    throw new IllegalArgumentException("Invalid select mode: " + mode);
            }

            if (mode == MODE_MULTI && maxItems > 0) {
                picker.limit(maxItems);
            }

            picker = picker.folderMode(folderMode);
            picker = picker.includeVideo(includeVideo);

            switch (imageSource) {
                case SOURCE_ASK_USER:
                    picker.start(REQUEST_CODE_PICK);
                    break;
                case SOURCE_GALLERY:
                    picker.showCamera(false).start(REQUEST_CODE_PICK);
                    break;
                case SOURCE_CAMERA:
                    activity.startActivityForResult(
                            cameraModule.getCameraIntent(activity), REQUEST_CODE_CAMERA);
                    break;
                default:
                    throw new IllegalArgumentException("Invalid image source: " + imageSource);
            }
        } else {
            throw new IllegalArgumentException("Unknown method " + call.method);
        }
    }

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == REQUEST_CODE_PICK) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                ArrayList<Image> images = (ArrayList<Image>) ImagePicker.getImages(data);

                Double maxWidth = methodCall.argument("maxWidth");
                Double maxHeight = methodCall.argument("maxHeight");

                ArrayList<Map<String, String>> processedImages = new ArrayList<>();
                for (Image image : images) {
                    Map<String, String> processedImagePath = processImage(image, maxWidth, maxHeight);
                    processedImages.add(processedImagePath);
                }
                pendingResult.success(processedImages);
            } else if (resultCode != Activity.RESULT_CANCELED) {
                pendingResult.error("PICK_ERROR", "Error picking image", null);
            }

            pendingResult = null;
            methodCall = null;
            return true;
        }
        if (requestCode == REQUEST_CODE_CAMERA) {
            if (resultCode == Activity.RESULT_OK) {
                cameraModule.getImage(
                        registrar.context(),
                        data,
                        new OnImageReadyListener() {
                            @Override
                            public void onImageReady(List<Image> images) {
                                handleResult(images.get(0));
                            }
                        });
                return true;
            } else if (resultCode != Activity.RESULT_CANCELED) {
                pendingResult.error("PICK_ERROR", "Error taking photo", null);
            }

            pendingResult = null;
            methodCall = null;
            return true;
        }
        return false;
    }

    private void handleResult(Image image) {
        if (pendingResult != null) {
            Double maxWidth = methodCall.argument("maxWidth");
            Double maxHeight = methodCall.argument("maxHeight");
            ArrayList<Map<String, String>> processedImages = new ArrayList<>();

            processedImages.add(processImage(image, maxWidth, maxHeight));

            pendingResult.success(processedImages);

            pendingResult = null;
            methodCall = null;
        } else {
            throw new IllegalStateException("Received images from picker that were not requested");
        }
    }

    private Map<String, String> processImage(Image image, Double maxWidth, Double maxHeight) {
        boolean shouldScale = maxWidth != null || maxHeight != null;
        String mimeType = getMimeType(image.getPath());
        boolean isImage = mimeType != null && mimeType.startsWith("image");
        boolean isVideo = mimeType != null && mimeType.startsWith("video");

        Map<String, String> returnMap = new HashMap<>();

        if (isImage) {
            if (shouldScale) {
                try {
                    ImageScaleResult scaleResult = scaleImage(image, maxWidth, maxHeight);
                    returnMap.put("path", scaleResult.imageFile.getPath());
                    returnMap.put("width", Integer.toString(scaleResult.width));
                    returnMap.put("height", Integer.toString(scaleResult.height));
                } catch (IOException e) {
                    throw new RuntimeException(e);
                }
            } else {
                try {
                    ExifInterface exif = new ExifInterface(image.getPath());
                    int orientation = exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, 0);
                    int width = exif.getAttributeInt(ExifInterface.TAG_IMAGE_WIDTH, 0);
                    int height = exif.getAttributeInt(ExifInterface.TAG_IMAGE_LENGTH, 0);

                    switch (orientation) {
                        case ExifInterface.ORIENTATION_ROTATE_90:
                        case ExifInterface.ORIENTATION_ROTATE_270:
                            returnMap.put("width", Integer.toString(height));
                            returnMap.put("height", Integer.toString(width));
                            break;
                        default:
                            returnMap.put("width", Integer.toString(width));
                            returnMap.put("height", Integer.toString(height));
                    }

                } catch (Exception ex) {
                    Log.e(TAG, "Error getting Exif data from selected image: " + ex);
                    Bitmap bmp = BitmapFactory.decodeFile(image.getPath());

                    returnMap.put("width", Integer.toString(bmp.getWidth()));
                    returnMap.put("height", Integer.toString(bmp.getHeight()));
                }

                returnMap.put("path", image.getPath());
            }
        } else if (isVideo) {
            MediaMetadataRetriever metaRetriever = new MediaMetadataRetriever();
            metaRetriever.setDataSource(image.getPath());
            String height = metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT);
            String width = metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH);

            returnMap.put("path", image.getPath());
            returnMap.put("width", width);
            returnMap.put("height", height);
        } else {
            returnMap.put("path", image.getPath());
        }

        return returnMap;
    }

    // From https://stackoverflow.com/questions/8589645/how-to-determine-mime-type-of-file-in-android
    public static String getMimeType(String url) {
        String type = null;
        String extension = MimeTypeMap.getFileExtensionFromUrl(url);
        if (extension != null) {
            type = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
        }
        return type;
    }

    private ImageScaleResult scaleImage(Image image, Double maxWidth, Double maxHeight) throws IOException {
        Bitmap bmp = BitmapFactory.decodeFile(image.getPath());

        double originalWidth = bmp.getWidth() * 1.0;
        double originalHeight = bmp.getHeight() * 1.0;

        boolean hasMaxWidth = maxWidth != null;
        boolean hasMaxHeight = maxHeight != null;

        Double width = hasMaxWidth ? Math.min(originalWidth, maxWidth) : originalWidth;
        Double height = hasMaxHeight ? Math.min(originalHeight, maxHeight) : originalHeight;

        boolean shouldDownscaleWidth = hasMaxWidth && maxWidth < originalWidth;
        boolean shouldDownscaleHeight = hasMaxHeight && maxHeight < originalHeight;
        boolean shouldDownscale = shouldDownscaleWidth || shouldDownscaleHeight;

        if (shouldDownscale) {
            double downscaledWidth = (height / originalHeight) * originalWidth;
            double downscaledHeight = (width / originalWidth) * originalHeight;

            if (width < height) {
                if (!hasMaxWidth) {
                    width = downscaledWidth;
                } else {
                    height = downscaledHeight;
                }
            } else if (height < width) {
                if (!hasMaxHeight) {
                    height = downscaledHeight;
                } else {
                    width = downscaledWidth;
                }
            } else {
                if (originalWidth < originalHeight) {
                    width = downscaledWidth;
                } else if (originalHeight < originalWidth) {
                    height = downscaledHeight;
                }
            }
        }

        Bitmap scaledBmp = Bitmap.createScaledBitmap(bmp, width.intValue(), height.intValue(), false);
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        scaledBmp.compress(Bitmap.CompressFormat.JPEG, 100, outputStream);

        String scaledCopyPath = image.getPath().replace(image.getName(), "scaled_" + image.getName());
        File imageFile = new File(scaledCopyPath);

        FileOutputStream fileOutput = new FileOutputStream(imageFile);
        fileOutput.write(outputStream.toByteArray());
        fileOutput.close();

        if (shouldDownscale) {
            copyExif(image.getPath(), scaledCopyPath);
        }

        return new ImageScaleResult(imageFile, width.intValue(), height.intValue());
    }

    private void copyExif(String filePathOri, String filePathDest) {
        try {
            ExifInterface oldExif = new ExifInterface(filePathOri);
            ExifInterface newExif = new ExifInterface(filePathDest);

            List<String> attributes =
                    Arrays.asList(
                            "FNumber",
                            "ExposureTime",
                            "ISOSpeedRatings",
                            "GPSAltitude",
                            "GPSAltitudeRef",
                            "FocalLength",
                            "GPSDateStamp",
                            "WhiteBalance",
                            "GPSProcessingMethod",
                            "GPSTimeStamp",
                            "DateTime",
                            "Flash",
                            "GPSLatitude",
                            "GPSLatitudeRef",
                            "GPSLongitude",
                            "GPSLongitudeRef",
                            "Make",
                            "Model",
                            "Orientation");
            for (String attribute : attributes) {
                setIfNotNull(oldExif, newExif, attribute);
            }

            newExif.saveAttributes();

        } catch (Exception ex) {
            Log.e(TAG, "Error preserving Exif data on selected image: " + ex);
        }
    }

    private void setIfNotNull(ExifInterface oldExif, ExifInterface newExif, String property) {
        if (oldExif.getAttribute(property) != null) {
            newExif.setAttribute(property, oldExif.getAttribute(property));
        }
    }

    private class ImageScaleResult {
        public final File imageFile;
        public final int width;
        public final int height;

        public ImageScaleResult(File imageFile, int width, int height) {
            this.imageFile = imageFile;
            this.width = width;
            this.height = height;
        }
    }
}

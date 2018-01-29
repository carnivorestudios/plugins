// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@import UIKit;


#import "ImagePickerPlugin.h"
#import <QBImagePickerController/QBImagePickerController.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface FLTImagePickerPlugin ()<UINavigationControllerDelegate, UIImagePickerControllerDelegate, QBImagePickerControllerDelegate>
@end

static const int SOURCE_ASK_USER = 0;
static const int SOURCE_CAMERA = 1;
static const int SOURCE_GALLERY = 2;

static const int SELECT_MODE_SINGLE = 0;
static const int SELECT_MODE_MULTI = 1;

@implementation FLTImagePickerPlugin {
  FlutterResult _result;
  NSDictionary *_arguments;
  QBImagePickerController *_multiImagePickerController;
  UIImagePickerController *_singleImagePickerController;
  UIViewController *_viewController;
  NSArray *_selectedAssets;
  NSMutableArray *_resultPaths;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"image_picker"
                                  binaryMessenger:[registrar messenger]];
  UIViewController *viewController =
      [UIApplication sharedApplication].delegate.window.rootViewController;
  FLTImagePickerPlugin *instance =
      [[FLTImagePickerPlugin alloc] initWithViewController:viewController];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)initWithViewController:(UIViewController *)viewController {
  self = [super init];
  if (self) {
    _viewController = viewController;
  }
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if (_result) {
    _result([FlutterError errorWithCode:@"multiple_request"
                                message:@"Cancelled by a second request"
                                details:nil]);
    _result = nil;
  }

  if ([@"pickImage" isEqualToString:call.method]) {
    _multiImagePickerController.modalPresentationStyle = UIModalPresentationCurrentContext;
    _multiImagePickerController.delegate = self;

    _result = result;
    _arguments = call.arguments;

    int imageSource = [[_arguments objectForKey:@"source"] intValue];

    switch (imageSource) {
      case SOURCE_ASK_USER:
        [self showImageSourceSelector];
        break;
      case SOURCE_CAMERA:
        [self showCamera];
        break;
      case SOURCE_GALLERY:
        [self showPhotoLibrary];
        break;
      default:
        result([FlutterError errorWithCode:@"invalid_source"
                                   message:@"Invalid image source."
                                   details:nil]);
        break;
    }
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)showImageSourceSelector {
  UIAlertControllerStyle style = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
                                     ? UIAlertControllerStyleAlert
                                     : UIAlertControllerStyleActionSheet;

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:style];
  UIAlertAction *camera = [UIAlertAction actionWithTitle:@"Take Photo"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *action) {
                                                   [self showCamera];
                                                 }];
  UIAlertAction *library = [UIAlertAction actionWithTitle:@"Choose Photo"
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction *action) {
                                                    [self showPhotoLibrary];
                                                  }];
  UIAlertAction *cancel =
      [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
  [alert addAction:camera];
  [alert addAction:library];
  [alert addAction:cancel];
  [_viewController presentViewController:alert animated:YES completion:nil];
}

- (void)showCamera {
  // Camera is not available on simulators
  _singleImagePickerController = [[UIImagePickerController alloc] init];
  _singleImagePickerController.delegate = self;
  BOOL includeVideo = [[_arguments objectForKey:@"includeVideo"] boolValue];
  NSArray *mediaTypes = includeVideo ? [UIImagePickerController availableMediaTypesForSourceType:
                                        UIImagePickerControllerSourceTypeCamera] : @[(NSString *)kUTTypeImage];
  if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] && mediaTypes.count > 0) {
    _singleImagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    _singleImagePickerController.mediaTypes = mediaTypes;
    [_viewController presentViewController:_singleImagePickerController animated:YES completion:nil];
  } else {
    [[[UIAlertView alloc] initWithTitle:@"Error"
                                message:@"Camera not available."
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
  }
}

- (void)showPhotoLibrary {
  int selectMode = [[_arguments objectForKey:@"mode"] intValue];
  if (selectMode == SELECT_MODE_SINGLE) {
    [self showSingleSelectLibrary];
  }
  else {
    [self showMultiSelectLibrary];
  }
}

- (NSArray *)getAssetTypes {
  NSMutableArray *assetTypes = [NSMutableArray array];
  [assetTypes addObject:@(PHAssetCollectionSubtypeSmartAlbumUserLibrary)];
  [assetTypes addObject:@(PHAssetCollectionSubtypeSmartAlbumFavorites)];
  if (@available(iOS 9, *)) {
    [assetTypes addObject:@(PHAssetCollectionSubtypeSmartAlbumScreenshots)];
  }
  if (@available(iOS 11, *)) {
    [assetTypes addObject:@(PHAssetCollectionSubtypeSmartAlbumAnimated)];
  }
  //  [assetTypes addObject:@(PHAssetCollectionSubtypeSmartAlbumVideos)]; //TODO: uncomment once supported
  if (@available(iOS 9, *)) {
    [assetTypes addObject:@(PHAssetCollectionSubtypeSmartAlbumSelfPortraits)];
  }
  if (@available(iOS 10.3, *)) {
    [assetTypes addObject:@(PHAssetCollectionSubtypeSmartAlbumLivePhotos)];
  }
  [assetTypes addObject:@(PHAssetCollectionSubtypeSmartAlbumPanoramas)];
  [assetTypes addObject:@(PHAssetCollectionSubtypeSmartAlbumTimelapses)];
  [assetTypes addObject:@(PHAssetCollectionSubtypeSmartAlbumSlomoVideos)];
  [assetTypes addObject:@(PHAssetCollectionSubtypeSmartAlbumBursts)];
  if (@available(iOS 10.2, *)) {
    [assetTypes addObject:@(PHAssetCollectionSubtypeSmartAlbumDepthEffect)];
  }
  if (@available(iOS 11, *)) {
    [assetTypes addObject:@(PHAssetCollectionSubtypeSmartAlbumLongExposures)];
  }
  [assetTypes addObject:@(PHAssetCollectionSubtypeAlbumMyPhotoStream)];
  [assetTypes addObject:@(PHAssetCollectionSubtypeAlbumCloudShared)];
  return assetTypes;
}

- (void)showMultiSelectLibrary {
  _multiImagePickerController = [[QBImagePickerController alloc] init];
  _multiImagePickerController.delegate = self;
  _multiImagePickerController.allowsMultipleSelection = YES;
  _multiImagePickerController.showsNumberOfSelectedAssets = YES;

  _multiImagePickerController.assetCollectionSubtypes = [self getAssetTypes];
  BOOL includeVideo = [[_arguments objectForKey:@"includeVideo"] boolValue];
  _multiImagePickerController.mediaType = includeVideo ? QBImagePickerMediaTypeAny : QBImagePickerMediaTypeImage;
  [_viewController presentViewController:_multiImagePickerController animated:YES completion:nil];
}

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didFinishPickingAssets:(NSArray *)assets {
  [_viewController dismissViewControllerAnimated:YES completion:nil];
  [self finishResultWithAssets:assets];
}

- (void)showSingleSelectLibrary {
  _singleImagePickerController = [[UIImagePickerController alloc] init];
  _singleImagePickerController.delegate = self;
  BOOL includeVideo = [[_arguments objectForKey:@"includeVideo"] boolValue];
  NSArray *mediaTypes = includeVideo ? [UIImagePickerController availableMediaTypesForSourceType:
                                        UIImagePickerControllerSourceTypePhotoLibrary] : @[(NSString *)kUTTypeImage];
  _singleImagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
  _singleImagePickerController.mediaTypes = mediaTypes;
  [_viewController presentViewController:_singleImagePickerController animated:YES completion:nil];
}

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController {
  [_viewController dismissViewControllerAnimated:YES completion:nil];
  _result(nil);
  [self cleanup];
}

- (void)imagePickerController:(UIImagePickerController *)picker
    didFinishPickingMediaWithInfo:(NSDictionary<NSString *, id> *)info {
  [_viewController dismissViewControllerAnimated:YES completion:nil];
  NSURL *imageUrl = [info objectForKey:UIImagePickerControllerImageURL];
  NSString *extension = imageUrl.pathExtension.lowercaseString;
  if ([extension isEqualToString:@"gif"] || [extension isEqualToString:@"png"]) {
    PHAsset *asset = [info objectForKey:UIImagePickerControllerPHAsset];
    if (asset != nil) {
      [self finishResultWithAssets:@[asset]];
      return;
    }
  }
  _resultPaths = [NSMutableArray arrayWithCapacity:1];
  if ([[info valueForKey:UIImagePickerControllerMediaType] isEqualToString:(NSString*)kUTTypeMovie]) {
    NSURL *url = [info valueForKey:UIImagePickerControllerMediaURL];
    AVAsset *asset = [AVAsset assetWithURL:url];
    AVAssetExportSession *session = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetMediumQuality];
    _selectedAssets = @[asset];
    [self exportVideoWithSession:session index:0 originalURL:url];
    return;
  }
  
  UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
  if (image == nil) {
    image = [info objectForKey:UIImagePickerControllerOriginalImage];
  }
  [self finishResultWithImage:image];
}

- (PHVideoRequestOptions *)videoOptions {
  PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
  options.networkAccessAllowed = YES;
  return options;
}

- (PHImageRequestOptions *)imageOptions {
  PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
  options.networkAccessAllowed = YES;
  return options;
}

- (void)finishResultWithAssets:(NSArray *)assets {
  _selectedAssets = assets;
  _resultPaths = [NSMutableArray arrayWithCapacity:assets.count];
  PHImageManager *manager = [PHImageManager defaultManager];
  for (int i = 0; i < assets.count; i++) {
    PHAsset *asset = assets[i];
    if (@available(iOS 9.1, *) && ((asset.mediaSubtypes & PHAssetMediaSubtypePhotoLive) == PHAssetMediaSubtypePhotoLive)) {
      [manager requestImageForAsset:asset targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeDefault options:[self imageOptions] resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        [self finishResultWithImage:result];
      }];
    }
    else if (asset.mediaType == PHAssetMediaTypeVideo) {
      [manager requestExportSessionForVideo:asset options:[self videoOptions] exportPreset:AVAssetExportPresetMediumQuality resultHandler:^(AVAssetExportSession * _Nullable exportSession, NSDictionary * _Nullable info) {
        [self exportVideoWithSession:exportSession index:i originalURL:nil];
      }];
    }
    else {
      [manager requestImageDataForAsset:asset options:[self imageOptions] resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
        NSString *type = dataUTI.pathExtension;
        [self finishResultWithPath:[self writeData:imageData withType:type] index:i];
      }];
    }
  }
}

- (void)finishResultWithImage:(UIImage *)image {
  image = [self normalizedImage:image];
  
  NSNumber *maxWidth = [_arguments objectForKey:@"maxWidth"];
  NSNumber *maxHeight = [_arguments objectForKey:@"maxHeight"];
  
  if (maxWidth != (id)[NSNull null] || maxHeight != (id)[NSNull null]) {
    image = [self scaledImage:image maxWidth:maxWidth maxHeight:maxHeight];
  }
  
  NSData *data = UIImageJPEGRepresentation(image, 1.0);
  _selectedAssets = @[image];
  [self finishResultWithPath:[self writeData:data withType:@"jpg"] index:0];
}

- (void)exportVideoWithSession:(AVAssetExportSession *)exportSession index:(NSUInteger)index originalURL:(NSURL *)originalURL {
  exportSession.outputFileType = AVFileTypeMPEG4;
  AVAsset *asset = exportSession.asset;
  NSString *fileName = [self createFileNameForType:@"mp4"];
  NSURL *tmpDirectory = [NSFileManager defaultManager].temporaryDirectory;
  NSURL *outputURL = [tmpDirectory URLByAppendingPathComponent:fileName];
  exportSession.outputURL = outputURL;
  exportSession.videoComposition = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:asset];
  [exportSession exportAsynchronouslyWithCompletionHandler:^{
    [self finishResultWithPath:outputURL.path index:index];
    if (originalURL != nil) {
      [[NSFileManager defaultManager] removeItemAtURL:originalURL error:nil];
    }
  }];
}

- (void)finishResultWithPath:(NSString *)resultPath index:(NSUInteger)index {
  if (_result == nil) return;
  BOOL done = false;
  if (resultPath != nil) {
    _resultPaths[index] = resultPath;
    if (_resultPaths.count == _selectedAssets.count) {
      _result(_resultPaths);
      done = YES;
    }
  } else {
    _result([FlutterError errorWithCode:@"create_error"
                                message:@"Temporary file could not be created"
                                details:nil]);
    done = YES;
  }
  
  if (done) {
    [self cleanup];
  }
}

- (void)cleanup {
  _selectedAssets = nil;
  _resultPaths = nil;
  _result = nil;
  _arguments = nil;
  _multiImagePickerController = nil;
  _singleImagePickerController = nil;
}

- (NSString *)writeData:(NSData *)data withType:(NSString *)fileType {
  // TODO(jackson): Using the cache directory might be better than temporary
  // directory.
  NSString *tmpDirectory = NSTemporaryDirectory();
  NSString *tmpPath = [tmpDirectory stringByAppendingPathComponent:[self createFileNameForType:fileType]];
  if ([[NSFileManager defaultManager] createFileAtPath:tmpPath contents:data attributes:nil]) {
    return tmpPath;
  } else {
    return nil;
  }
}

- (NSString *)createFileNameForType:(NSString *)type {
  NSString *guid = [[NSProcessInfo processInfo] globallyUniqueString];
  return [NSString stringWithFormat:@"image_picker_%@.%@", guid, type];
}

// The way we save images to the tmp dir currently throws away all EXIF data
// (including the orientation of the image). That means, pics taken in portrait
// will not be orientated correctly as is. To avoid that, we rotate the actual
// image data.
// TODO(goderbauer): investigate how to preserve EXIF data.
- (UIImage *)normalizedImage:(UIImage *)image {
  if (image.imageOrientation == UIImageOrientationUp) return image;

  UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
  [image drawInRect:(CGRect){0, 0, image.size}];
  UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return normalizedImage;
}

- (UIImage *)scaledImage:(UIImage *)image
                maxWidth:(NSNumber *)maxWidth
               maxHeight:(NSNumber *)maxHeight {
  double originalWidth = image.size.width;
  double originalHeight = image.size.height;

  bool hasMaxWidth = maxWidth != (id)[NSNull null];
  bool hasMaxHeight = maxHeight != (id)[NSNull null];

  double width = hasMaxWidth ? MIN([maxWidth doubleValue], originalWidth) : originalWidth;
  double height = hasMaxHeight ? MIN([maxHeight doubleValue], originalHeight) : originalHeight;

  bool shouldDownscaleWidth = hasMaxWidth && [maxWidth doubleValue] < originalWidth;
  bool shouldDownscaleHeight = hasMaxHeight && [maxHeight doubleValue] < originalHeight;
  bool shouldDownscale = shouldDownscaleWidth || shouldDownscaleHeight;

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

  UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), NO, 1.0);
  [image drawInRect:CGRectMake(0, 0, width, height)];

  UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  return scaledImage;
}

@end

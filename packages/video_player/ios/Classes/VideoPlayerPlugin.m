// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "VideoPlayerPlugin.h"
#import <AVFoundation/AVFoundation.h>

int64_t FLTCMTimeToMillis(CMTime time) { return time.value * 1000 / time.timescale; }
static inline CGFloat RadiansToDegrees(CGFloat radians) {
    return radians * 180 / M_PI;
};

static inline CGFloat DegreesToRadians(CGFloat deg) {
    return deg / 180 * M_PI;
};

@interface FLTFrameUpdater : NSObject
@property(nonatomic) int64_t textureId;
@property(nonatomic, readonly) NSObject<FlutterTextureRegistry>* registry;
- (void)onDisplayLink:(CADisplayLink*)link;
@end

@implementation FLTFrameUpdater
- (FLTFrameUpdater*)initWithRegistry:(NSObject<FlutterTextureRegistry>*)registry {
  NSAssert(self, @"super init cannot be nil");
  if (self == nil) return nil;
  _registry = registry;
  return self;
}

- (void)onDisplayLink:(CADisplayLink*)link {
  [_registry textureFrameAvailable:_textureId];
}
@end

@interface FLTVideoPlayer : NSObject<FlutterTexture, FlutterStreamHandler>
@property(readonly, nonatomic) AVPlayer* player;
@property(readonly, nonatomic) AVPlayerItemVideoOutput* videoOutput;
@property(readonly, nonatomic) CADisplayLink* displayLink;
@property(nonatomic) FlutterEventChannel* eventChannel;
@property(nonatomic) FlutterEventSink eventSink;
@property(nonatomic, readonly) bool disposed;
@property(nonatomic, readonly) bool isPlaying;
@property(nonatomic, readonly) bool isLooping;
@property(nonatomic, readonly) bool isInitialized;
- (instancetype)initWithURL:(NSURL*)url frameUpdater:(FLTFrameUpdater*)frameUpdater;
- (void)play;
- (void)pause;
- (void)setIsLooping:(bool)isLooping;
- (void)updatePlayingState;
@end

static void* timeRangeContext = &timeRangeContext;
static void* statusContext = &statusContext;
static void* playbackLikelyToKeepUpContext = &playbackLikelyToKeepUpContext;

@implementation FLTVideoPlayer
- (instancetype)initWithURL:(NSURL*)url frameUpdater:(FLTFrameUpdater*)frameUpdater {
  self = [super init];
  NSAssert(self, @"super init cannot be nil");
  _isInitialized = false;
  _isPlaying = false;
  _disposed = false;
  _player = [[AVPlayer alloc] init];
  _player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
  [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                                                    object:[_player currentItem]
                                                     queue:[NSOperationQueue mainQueue]
                                                usingBlock:^(NSNotification* note) {
                                                  if (_isLooping) {
                                                    AVPlayerItem* p = [note object];
                                                    [p seekToTime:kCMTimeZero];
                                                  } else {
                                                    if (_eventSink) {
                                                      _eventSink(@{@"event" : @"completed"});
                                                    }
                                                  }
                                                }];
  NSDictionary* pixBuffAttributes = @{
    (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
    (id)kCVPixelBufferIOSurfacePropertiesKey : @{}
  };
  _videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
  AVPlayerItem* item = [AVPlayerItem playerItemWithURL:url];

  [item addObserver:self
         forKeyPath:@"loadedTimeRanges"
            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
            context:timeRangeContext];
  [item addObserver:self
         forKeyPath:@"status"
            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
            context:statusContext];
  [item addObserver:self
         forKeyPath:@"playbackLikelyToKeepUp"
            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
            context:playbackLikelyToKeepUpContext];

  AVAsset* asset = [item asset];
  void (^assetCompletionHandler)(void) = ^{
    if ([asset statusOfValueForKey:@"tracks" error:nil] == AVKeyValueStatusLoaded) {
      NSArray* tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
      if ([tracks count] > 0) {

          AVAssetTrack* videoTrack    = [tracks objectAtIndex:0];
          CGAffineTransform txf       = [videoTrack preferredTransform];
          CGFloat videoAngleInDegree  = RadiansToDegrees(atan2(txf.b, txf.a));
          NSLog(@"Preferred angle %f", videoAngleInDegree);

          
          AVMutableComposition *composition = [AVMutableComposition composition];
          
          
          AVMutableCompositionTrack *compositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                                      preferredTrackID:kCMPersistentTrackID_Invalid];
          [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                                         ofTrack:videoTrack
                                          atTime:kCMTimeZero error:nil];

          CGFloat rotation = 0.0f;
          if (videoAngleInDegree) {
              rotation = videoAngleInDegree;
          }
          
            if (rotation) {
                [FLTVideoPlayer rotateAsset:asset fileName:[url lastPathComponent] withDegrees:rotation completion:^(AVPlayerItem *item) {
                    [item addObserver:self
                    forKeyPath:@"loadedTimeRanges"
                    options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                    context:timeRangeContext];
                    [item addObserver:self
                    forKeyPath:@"status"
                    options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                    context:statusContext];
                    [item addObserver:self
                    forKeyPath:@"playbackLikelyToKeepUp"
                    options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                    context:playbackLikelyToKeepUpContext];

                    [self.player replaceCurrentItemWithPlayerItem:item];
                }];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.player replaceCurrentItemWithPlayerItem:item];
                });
                return;
            }

      }
    }
  };
  [asset loadValuesAsynchronouslyForKeys:@[ @"tracks" ] completionHandler:assetCompletionHandler];
  _displayLink =
      [CADisplayLink displayLinkWithTarget:frameUpdater selector:@selector(onDisplayLink:)];
  [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
  _displayLink.paused = YES;
  return self;
}

- (void)observeValueForKeyPath:(NSString*)path
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context {
  if (context == timeRangeContext) {
    if (_eventSink != nil) {
      NSMutableArray<NSArray<NSNumber*>*>* values = [[NSMutableArray alloc] init];
      for (NSValue* rangeValue in [object loadedTimeRanges]) {
        CMTimeRange range = [rangeValue CMTimeRangeValue];
        int64_t start = FLTCMTimeToMillis(range.start);
        [values addObject:@[ @(start), @(start + FLTCMTimeToMillis(range.duration)) ]];
      }
      _eventSink(@{@"event" : @"bufferingUpdate", @"values" : values});
    }
  } else if (context == statusContext) {
    if (_eventSink != nil) {
      AVPlayerItem* item = (AVPlayerItem*)object;
      switch (item.status) {
        case AVPlayerStatusFailed:
          _eventSink([FlutterError
              errorWithCode:@"VideoError"
                    message:[@"Failed to load video: "
                                stringByAppendingString:[item.error localizedDescription]]
                    details:nil]);
          break;
        case AVPlayerItemStatusUnknown:
          break;
        case AVPlayerItemStatusReadyToPlay:
          _isInitialized = true;
          [item addOutput:_videoOutput];
          [self sendInitialized];
          [self updatePlayingState];
          break;
      }
    }
  } else if (context == playbackLikelyToKeepUpContext) {
    if ([[_player currentItem] isPlaybackLikelyToKeepUp]) {
      [self updatePlayingState];
    }
  }
}

- (void)updatePlayingState {
  if (!_isInitialized) {
    return;
  }
  if (_isPlaying) {
    [_player play];
  } else {
    [_player pause];
  }
  _displayLink.paused = !_isPlaying;
}

- (void)sendInitialized {
  if (_eventSink && _isInitialized) {
    CGSize size = [self.player currentItem].presentationSize;
    _eventSink(@{
      @"event" : @"initialized",
      @"duration" : @([self duration]),
      @"width" : @(size.width),
      @"height" : @(size.height),
    });
  }
}

- (void)play {
  _isPlaying = true;
  [self updatePlayingState];
}

- (void)pause {
  _isPlaying = false;
  [self updatePlayingState];
}

- (int64_t)position {
  return FLTCMTimeToMillis([_player currentTime]);
}

- (int64_t)duration {
  return FLTCMTimeToMillis([[_player currentItem] duration]);
}

- (void)seekTo:(int)location {
  [_player seekToTime:CMTimeMake(location, 1000)];
}

- (void)setIsLooping:(bool)isLooping {
  _isLooping = isLooping;
}

- (void)setVolume:(double)volume {
  _player.volume = (volume < 0.0) ? 0.0 : ((volume > 1.0) ? 1.0 : volume);
}

- (CVPixelBufferRef)copyPixelBuffer {
  CMTime outputItemTime = [_videoOutput itemTimeForHostTime:CACurrentMediaTime()];
  if ([_videoOutput hasNewPixelBufferForItemTime:outputItemTime]) {
    return [_videoOutput copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
  } else {
    return NULL;
  }
}

- (FlutterError* _Nullable)onCancelWithArguments:(id _Nullable)arguments {
  _eventSink = nil;
  return nil;
}

- (FlutterError* _Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:(nonnull FlutterEventSink)events {
  _eventSink = events;
  [self sendInitialized];
  return nil;
}

- (void)dispose {
  _disposed = true;
  [_displayLink invalidate];
  [[_player currentItem] removeObserver:self forKeyPath:@"status" context:statusContext];
  [[_player currentItem] removeObserver:self
                             forKeyPath:@"loadedTimeRanges"
                                context:timeRangeContext];
  [[_player currentItem] removeObserver:self
                             forKeyPath:@"playbackLikelyToKeepUp"
                                context:playbackLikelyToKeepUpContext];
  [_player replaceCurrentItemWithPlayerItem:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_eventChannel setStreamHandler:nil];
}

+ (void)rotateAsset:(AVAsset *)asset fileName:(NSString *)fileName withDegrees:(float)degrees completion:(void (^)(AVPlayerItem *item))completion {
    
    AVMutableComposition *composition;
    AVMutableVideoComposition *videoComposition;
    AVMutableVideoCompositionInstruction * instruction;
    
    AVMutableVideoCompositionLayerInstruction *layerInstruction = nil;
    CGAffineTransform t1;
    CGAffineTransform t2;
    AVAssetTrack *assetVideoTrack = nil;
    AVAssetTrack *assetAudioTrack = nil;
    // Check if the asset contains video and audio tracks
    if ([[asset tracksWithMediaType:AVMediaTypeVideo] count] != 0) {
        assetVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    }
    if ([[asset tracksWithMediaType:AVMediaTypeAudio] count] != 0) {
        assetAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    }
    CMTime insertionPoint = kCMTimeInvalid;
    NSError *error = nil;
    
    
    // Step 1
    // Create a new composition
    composition = [AVMutableComposition composition];
    // Insert the video and audio tracks from AVAsset
    if (assetVideoTrack != nil) {
        AVMutableCompositionTrack *compositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration]) ofTrack:assetVideoTrack atTime:insertionPoint error:&error];
    }
    if (assetAudioTrack != nil) {
        AVMutableCompositionTrack *compositionAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration]) ofTrack:assetAudioTrack atTime:insertionPoint error:&error];
    }
    
    
    
    
    // Step 2
    // Calculate position and size of render video after rotating
    
    
    float width=assetVideoTrack.naturalSize.width;
    float height=assetVideoTrack.naturalSize.height;
    float toDiagonal=sqrt(width*width+height*height);
    float toDiagonalAngle=RadiansToDegrees(acosf(width/toDiagonal));
    float toDiagonalAngle2=90-RadiansToDegrees(acosf(width/toDiagonal));
    
    float toDiagonalAngleComple = 0;
    float toDiagonalAngleComple2 = 0;
    float finalHeight = 0;
    float finalWidth = 0;
    
    
    if(degrees>=0&&degrees<=90){
        
        toDiagonalAngleComple=toDiagonalAngle+degrees;
        toDiagonalAngleComple2=toDiagonalAngle2+degrees;
        
        finalHeight=ABS(toDiagonal*sinf(DegreesToRadians(toDiagonalAngleComple)));
        finalWidth=ABS(toDiagonal*sinf(DegreesToRadians(toDiagonalAngleComple2)));
        
        t1 = CGAffineTransformMakeTranslation(height*sinf(DegreesToRadians(degrees)), 0.0);
    }
    else if(degrees>90&&degrees<=180){
        
        float degrees2 = degrees-90;
        
        toDiagonalAngleComple=toDiagonalAngle+degrees2;
        toDiagonalAngleComple2=toDiagonalAngle2+degrees2;
        
        finalHeight=ABS(toDiagonal*sinf(DegreesToRadians(toDiagonalAngleComple2)));
        finalWidth=ABS(toDiagonal*sinf(DegreesToRadians(toDiagonalAngleComple)));
        
        t1 = CGAffineTransformMakeTranslation(width*sinf(DegreesToRadians(degrees2))+height*cosf(DegreesToRadians(degrees2)), height*sinf(DegreesToRadians(degrees2)));
    }
    else if(degrees>=-90&&degrees<0){
        
        float degrees2 = degrees-90;
        float degreesabs = ABS(degrees);
        
        toDiagonalAngleComple=toDiagonalAngle+degrees2;
        toDiagonalAngleComple2=toDiagonalAngle2+degrees2;
        
        finalHeight=ABS(toDiagonal*sinf(DegreesToRadians(toDiagonalAngleComple2)));
        finalWidth=ABS(toDiagonal*sinf(DegreesToRadians(toDiagonalAngleComple)));
        
        t1 = CGAffineTransformMakeTranslation(0, width*sinf(DegreesToRadians(degreesabs)));
        
    }
    else if(degrees>=-180&&degrees<-90){
        
        float degreesabs = ABS(degrees);
        float degreesplus = degreesabs-90;
        
        toDiagonalAngleComple=toDiagonalAngle+degrees;
        toDiagonalAngleComple2=toDiagonalAngle2+degrees;
        
        finalHeight=ABS(toDiagonal*sinf(DegreesToRadians(toDiagonalAngleComple)));
        finalWidth=ABS(toDiagonal*sinf(DegreesToRadians(toDiagonalAngleComple2)));
        
        t1 = CGAffineTransformMakeTranslation(width*sinf(DegreesToRadians(degreesplus)), height*sinf(DegreesToRadians(degreesplus))+width*cosf(DegreesToRadians(degreesplus)));
        
    }
    
    
    // Rotate transformation
    t2 = CGAffineTransformRotate(t1, DegreesToRadians(degrees));
    
    
    // Step 3
    // Set the appropriate render sizes and rotational transforms
    
    
    // Create a new video composition
    videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.renderSize = CGSizeMake(finalWidth,finalHeight);
    videoComposition.frameDuration = CMTimeMake(1, 30);
    
    // The rotate transform is set on a layer instruction
    instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, [composition duration]);
    
    layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:[composition.tracks objectAtIndex:0]];
    [layerInstruction setTransform:t2 atTime:kCMTimeZero];
    
    
    
    // Step  4
    
    // Add the transform instructions to the video composition
    
    instruction.layerInstructions = [NSArray arrayWithObject:layerInstruction];
    videoComposition.instructions = [NSArray arrayWithObject:instruction];
    
    
    AVPlayerItem *playerItem_ = [[AVPlayerItem alloc] initWithAsset:composition];
    playerItem_.videoComposition = videoComposition;
    
    
    
    CMTime time;
    
    
    time=kCMTimeZero;
    //Export rotated video to the file
    
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetMediumQuality] ;
    exportSession.outputFileType = AVFileTypeMPEG4;
    exportSession.videoComposition = videoComposition;
    exportSession.shouldOptimizeForNetworkUse = YES;
    exportSession.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *outputURL = paths[0];
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createDirectoryAtPath:outputURL withIntermediateDirectories:YES attributes:nil error:nil];
    outputURL = [outputURL stringByAppendingPathComponent:fileName];
    
    if ([manager fileExistsAtPath:outputURL]) {
        AVPlayerItem* item = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:outputURL]];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(item);
        });
    } else {
        exportSession.outputFileType = AVFileTypeQuickTimeMovie;
        exportSession.outputURL = [NSURL fileURLWithPath:outputURL];
        
        
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            AVPlayerItem* item = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:outputURL]];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(item);
            });
        }];
    }
}


@end

@interface FLTVideoPlayerPlugin ()
@property(readonly, nonatomic) NSObject<FlutterTextureRegistry>* registry;
@property(readonly, nonatomic) NSObject<FlutterBinaryMessenger>* messenger;
@property(readonly, nonatomic) NSMutableDictionary* players;
@end

@implementation FLTVideoPlayerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel =
      [FlutterMethodChannel methodChannelWithName:@"flutter.io/videoPlayer"
                                  binaryMessenger:[registrar messenger]];
  FLTVideoPlayerPlugin* instance =
      [[FLTVideoPlayerPlugin alloc] initWithRegistry:[registrar textures]
                                           messenger:[registrar messenger]];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)initWithRegistry:(NSObject<FlutterTextureRegistry>*)registry
                       messenger:(NSObject<FlutterBinaryMessenger>*)messenger {
  self = [super init];
  NSAssert(self, @"super init cannot be nil");
  _registry = registry;
  _messenger = messenger;
  _players = [NSMutableDictionary dictionaryWithCapacity:1];
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"init" isEqualToString:call.method]) {
    for (NSNumber* textureId in _players) {
      [_registry unregisterTexture:[textureId unsignedIntegerValue]];
      [[_players objectForKey:textureId] dispose];
    }
    [_players removeAllObjects];
  } else if ([@"create" isEqualToString:call.method]) {
    NSDictionary* argsMap = call.arguments;
    NSString* dataSource = argsMap[@"dataSource"];
    FLTFrameUpdater* frameUpdater = [[FLTFrameUpdater alloc] initWithRegistry:_registry];
    FLTVideoPlayer* player = [[FLTVideoPlayer alloc] initWithURL:[NSURL URLWithString:dataSource]
                                                    frameUpdater:frameUpdater];
    int64_t textureId = [_registry registerTexture:player];
    frameUpdater.textureId = textureId;
    FlutterEventChannel* eventChannel = [FlutterEventChannel
        eventChannelWithName:[NSString stringWithFormat:@"flutter.io/videoPlayer/videoEvents%lld",
                                                        textureId]
             binaryMessenger:_messenger];
    [eventChannel setStreamHandler:player];
    player.eventChannel = eventChannel;
    _players[@(textureId)] = player;
    result(@{ @"textureId" : @(textureId) });
  } else {
    NSDictionary* argsMap = call.arguments;
    int64_t textureId = ((NSNumber*)argsMap[@"textureId"]).unsignedIntegerValue;
    FLTVideoPlayer* player = _players[@(textureId)];
    if ([@"dispose" isEqualToString:call.method]) {
      [_registry unregisterTexture:textureId];
      [_players removeObjectForKey:@(textureId)];
      [player dispose];
    } else if ([@"setLooping" isEqualToString:call.method]) {
      [player setIsLooping:[[argsMap objectForKey:@"looping"] boolValue]];
      result(nil);
    } else if ([@"setVolume" isEqualToString:call.method]) {
      [player setVolume:[[argsMap objectForKey:@"volume"] doubleValue]];
      result(nil);
    } else if ([@"play" isEqualToString:call.method]) {
      [player play];
      result(nil);
    } else if ([@"position" isEqualToString:call.method]) {
      result(@([player position]));
    } else if ([@"seekTo" isEqualToString:call.method]) {
      [player seekTo:[[argsMap objectForKey:@"location"] intValue]];
      result(nil);
    } else if ([@"pause" isEqualToString:call.method]) {
      [player pause];
      result(nil);
    } else {
      result(FlutterMethodNotImplemented);
    }
  }
}



@end
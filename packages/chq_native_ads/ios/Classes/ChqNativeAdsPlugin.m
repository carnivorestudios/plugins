#import "ChqNativeAdsPlugin.h"
#import <UIKit/UIKit.h>
#import <FBAudienceNetwork/FBAudienceNetwork.h>

@interface FBNativeAd (Chq)
@property(readonly, nonatomic) NSString *adId;
- (BOOL)performClick;
@end

@interface ChqNativeAdsPlugin ()<FBNativeAdDelegate>
@property (strong, nonatomic) NSMutableDictionary *nativeAds;
@property (strong, nonatomic) NSMutableDictionary *flutterResults;
@property (strong, nonatomic) UIView *dummyView;
@property (strong, nonatomic) NSString *placementId;
@end

@implementation ChqNativeAdsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"chq_native_ads"
            binaryMessenger:[registrar messenger]];
  ChqNativeAdsPlugin* instance = [[ChqNativeAdsPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    self.nativeAds = [NSMutableDictionary dictionary];
    self.flutterResults = [NSMutableDictionary dictionary];
    self.dummyView = [[UIView alloc] init];
  }
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"setPlacementId" isEqualToString:call.method]) {
    self.placementId = call.arguments[@"placementId"];
    result(nil);
  } else if ([@"loadAd" isEqualToString:call.method]) {
    if (self.placementId == nil) {
      result([FlutterError errorWithCode:@"MissingPlacementId"
                                 message:@"Must call setPlacementId before calling loadAd"
                                 details:nil]);
    }
    else {
      FBNativeAd *nativeAd = [[FBNativeAd alloc] initWithPlacementID:self.placementId];
      nativeAd.delegate = self;
      self.nativeAds[nativeAd.adId] = nativeAd;
      self.flutterResults[nativeAd.adId] = result;
      [nativeAd loadAd];
    }
  } else if ([@"clickAd" isEqualToString:call.method]) {
    FBNativeAd *ad = self.nativeAds[call.arguments[@"id"]];
    if (ad != nil) {
      if ([ad performClick]) {
        result(@"Ok");
      }
      else {
        result([FlutterError errorWithCode:@"AdFailedToHandleAction"
                                   message:@"FBNativeAd does not respond to selector handleTap:"
                                   details:call.arguments[@"id"]]);
      }
    }
    else {
      result([FlutterError errorWithCode:@"NoAdForID"
                                 message:@"Could not find ad for ad ID"
                                 details:call.arguments[@"id"]]);
    }
  } else if ([@"unloadAd" isEqualToString:call.method]) {
    FBNativeAd *ad = self.nativeAds[call.arguments[@"id"]];
    [ad unregisterView];
    NSLog(@"Native ad (%@) was unloaded.", call.arguments[@"id"]);
    result(nil);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)nativeAdDidLoad:(FBNativeAd *)nativeAd
{
  FlutterResult result = self.flutterResults[nativeAd.adId];
  [self.flutterResults removeObjectForKey:nativeAd.adId];
  
  id<UIApplicationDelegate> appDelegate = [UIApplication sharedApplication].delegate;
  UIViewController *rootViewController = appDelegate.window.rootViewController;
  UIView *rootView = rootViewController.view;
  [nativeAd registerViewForInteraction:rootView withViewController:rootViewController withClickableViews:@[self.dummyView]];
  
  NSNumber *choices_height = [NSNumber numberWithLong: nativeAd.adChoicesIcon.height];
  NSNumber *choices_width = [NSNumber numberWithLong: nativeAd.adChoicesIcon.width];
  NSString *choices_url = nativeAd.adChoicesIcon.url.absoluteString;
  NSString *choices_link = nativeAd.adChoicesLinkURL.absoluteString;
  NSString *choices_text = nativeAd.adChoicesText;
  
  NSNumber *icon_height = [NSNumber numberWithLong: nativeAd.icon.height];
  NSNumber *icon_width = [NSNumber numberWithLong: nativeAd.icon.width];
  NSString *icon_url = nativeAd.icon.url.absoluteString;
  
  NSNumber *coverImage_height = [NSNumber numberWithLong: nativeAd.coverImage.height];
  NSNumber *coverImage_width = [NSNumber numberWithLong: nativeAd.coverImage.width];
  NSString *coverImage_url = nativeAd.coverImage.url.absoluteString;
  
  NSString *title = nativeAd.title;
  NSString *socialContext = nativeAd.socialContext;
  NSString *body = nativeAd.body;
  NSString *callToAction = nativeAd.callToAction;
  
  NSDictionary *adChoicesDictionary = @{@"height": choices_height,
                                   @"width": choices_width,
                                   @"url": choices_url,
                                   @"link": choices_link,
                                   @"text": choices_text};
  
  NSDictionary *iconDictionary = @{@"height": icon_height,
                                   @"width": icon_width,
                                   @"url": icon_url};
  
  NSDictionary *coverImageDictionary = @{@"height": coverImage_height,
                                         @"width": coverImage_width,
                                         @"url": coverImage_url};
  
  NSDictionary *adDictionary = @{@"id": nativeAd.adId,
                                 @"icon": iconDictionary,
                                 @"coverImage": coverImageDictionary,
                                 @"choices": adChoicesDictionary,
                                 @"title": title,
                                 @"socialContext": socialContext,
                                 @"body": body,
                                 @"callToAction": callToAction};
  
  result(adDictionary);
  NSLog(@"Native ad (%@) was loaded.", nativeAd.adId);
}

- (void)nativeAd:(FBNativeAd *)nativeAd didFailWithError:(NSError *)error
{
  NSLog(@"Native ad (%@) failed to load with error: %@", nativeAd.adId, error);
}

- (void)nativeAdDidClick:(FBNativeAd *)nativeAd
{
  NSLog(@"Native (%@) ad was clicked.", nativeAd.adId);
}

- (void)nativeAdDidFinishHandlingClick:(FBNativeAd *)nativeAd
{
  NSLog(@"Native ad (%@) did finish click handling.", nativeAd.adId);
}

- (void)nativeAdWillLogImpression:(FBNativeAd *)nativeAd
{
  NSLog(@"Native ad (%@) impression is being captured.", nativeAd.adId);
}

@end

@implementation FBNativeAd (Chq)
- (NSString *)adId {
  return [NSString stringWithFormat:@"%lu", (unsigned long)self.hash];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
- (BOOL)performClick {
  if ([self respondsToSelector:@selector(handleTap:)]) {
    [self performSelector:@selector(handleTap:) withObject:nil];
    return YES;
  }
  return NO;
}
#pragma clang diagnostic pop
@end

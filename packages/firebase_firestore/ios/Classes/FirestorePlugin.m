// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FirestorePlugin.h"

#import <Firebase/Firebase.h>

@interface NSError (FlutterError)
@property(readonly, nonatomic) FlutterError *flutterError;
@end

@implementation NSError (FlutterError)
- (FlutterError *)flutterError {
  return [FlutterError errorWithCode:[NSString stringWithFormat:@"Error %ld", self.code]
                             message:self.domain
                             details:self.localizedDescription];
}
@end

@interface FIRDocumentSnapshot (Flutter)
- (NSDictionary<NSString *, id> *)flutterData;
@end

@implementation FIRDocumentSnapshot (Flutter)
- (NSDictionary<NSString *, id> *)flutterData {
  NSMutableDictionary *cleaned = self.data.mutableCopy;
  for (NSString *key in self.data) {
    id value = self.data[key];
    if ([value isKindOfClass:NSDate.class]) {
      cleaned[key] = @((long)([(NSDate *)value timeIntervalSince1970] * 1000));
    }
  }
  return cleaned;
}
@end

FIRQuery *getQuery(NSDictionary *arguments) {
  FIRQuery *query = [[FIRFirestore firestore] collectionWithPath:arguments[@"path"]];
  // TODO(jackson): Implement query parameters
  NSDictionary *parameters = arguments[@"parameters"];
  NSLog(@"Firestore query parameters: %@", parameters);
  if (parameters != nil) {
    NSNumber *limit = parameters[@"limit"];
    if (limit != nil) {
      NSLog(@"Firestore query limit: %@", limit);
      query = [query queryLimitedTo:limit.integerValue];
    }
  }
  return query;
}

@interface FirestorePlugin ()
@property(nonatomic, retain) FlutterMethodChannel *channel;
@end

@implementation FirestorePlugin {
  NSMutableDictionary<NSNumber *, id<FIRListenerRegistration>> *_listeners;
  int _nextListenerHandle;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"plugins.flutter.io/firebase_firestore"
                                  binaryMessenger:[registrar messenger]];
  FirestorePlugin *instance = [[FirestorePlugin alloc] init];
  instance.channel = channel;
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    if (![FIRApp defaultApp]) {
      [FIRApp configure];
    }
    _listeners = [NSMutableDictionary<NSNumber *, id<FIRListenerRegistration>> dictionary];
    _nextListenerHandle = 0;
  }
  return self;
}

+ (NSDictionary *)replaceServerTimestamps:(NSDictionary *)data {
  static NSString * const sServerTimestampKey = @".sv";
  NSMutableDictionary *replaced = data.mutableCopy;
  for (NSString *key in data) {
    if ([data[key] isEqual:sServerTimestampKey]) {
      NSLog(@"replacing value for key %@ with server timestamp", key);
      replaced[key] = [FIRFieldValue fieldValueForServerTimestamp];
    }
  }
  return replaced;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  void (^defaultCompletionBlock)(NSError *) = ^(NSError *error) {
    result(error.flutterError);
  };
  if ([@"DocumentReference#setData" isEqualToString:call.method]) {
    NSString *path = call.arguments[@"path"];
    FIRDocumentReference *reference = [[FIRFirestore firestore] documentWithPath:path];
    NSDictionary *data = [FirestorePlugin replaceServerTimestamps:call.arguments[@"data"]];
    [reference setData:data completion:defaultCompletionBlock];
  } else if ([@"Query#addSnapshotListener" isEqualToString:call.method]) {
    __block NSNumber *handle = [NSNumber numberWithInt:_nextListenerHandle++];
    id<FIRListenerRegistration> listener = [getQuery(call.arguments)
        addSnapshotListener:^(FIRQuerySnapshot *_Nullable snapshot, NSError *_Nullable error) {
          if (error) result(error.flutterError);
          NSMutableArray *documents = [NSMutableArray array];
          for (FIRDocumentSnapshot *document in snapshot.documents) {
            [documents addObject:document.flutterData];
          }
          NSMutableArray *documentChanges = [NSMutableArray array];
          for (FIRDocumentChange *documentChange in snapshot.documentChanges) {
            NSString *type;
            switch (documentChange.type) {
              case FIRDocumentChangeTypeAdded:
                type = @"DocumentChangeType.added";
                break;
              case FIRDocumentChangeTypeModified:
                type = @"DocumentChangeType.modified";
                break;
              case FIRDocumentChangeTypeRemoved:
                type = @"DocumentChangeType.removed";
                break;
            }
            [documentChanges addObject:@{
              @"type" : type,
              @"document" : documentChange.document.flutterData,
              @"oldIndex" : [NSNumber numberWithUnsignedInteger:documentChange.oldIndex],
              @"newIndex" : [NSNumber numberWithUnsignedInteger:documentChange.newIndex],
            }];
          }
          [self.channel invokeMethod:@"QuerySnapshot"
                           arguments:@{
                             @"handle" : handle,
                             @"documents" : documents,
                             @"documentChanges" : documentChanges
                           }];
        }];
    _listeners[handle] = listener;
    result(handle);
  } else if ([@"Query#addDocumentListener" isEqualToString:call.method]) {
    __block NSNumber *handle = [NSNumber numberWithInt:_nextListenerHandle++];
    FIRDocumentReference *reference =
        [[FIRFirestore firestore] documentWithPath:call.arguments[@"path"]];
    id<FIRListenerRegistration> listener =
        [reference addSnapshotListener:^(FIRDocumentSnapshot *snapshot, NSError *_Nullable error) {
          if (error) result(error.flutterError);
          [self.channel invokeMethod:@"DocumentSnapshot"
                           arguments:@{
                             @"handle" : handle,
                             @"data" : snapshot.exists ? snapshot.flutterData : [NSNull null],
                           }];
        }];
    _listeners[handle] = listener;
    result(handle);
  } else if ([@"Query#removeListener" isEqualToString:call.method]) {
    NSNumber *handle = call.arguments[@"handle"];
    [[_listeners objectForKey:handle] remove];
    [_listeners removeObjectForKey:handle];
    result(nil);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

@end

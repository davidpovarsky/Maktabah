//
//  ChavrusaSefariaBridgeModule.m
//  Maktabah
//
//  Objective-C registration interface exposing ChavrusaSefariaBridgeModule
//  to the React Native runtime and NativeModules dictionary.
//

#import <Foundation/Foundation.h>

#if __has_include(<React/RCTBridgeModule.h>)
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#elif __has_feature(modules)
@import React;
#else
#import "RCTBridgeModule.h"
#import "RCTEventEmitter.h"
#endif

RCT_EXTERN_MODULE(ChavrusaSefariaBridgeModule, RCTEventEmitter)

RCT_EXTERN_METHOD(deliverResponse:(NSString *)jsonString)
RCT_EXTERN_METHOD(deliverEvent:(NSString *)jsonString)
RCT_EXTERN_METHOD(echo:(NSString *)message
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

@end

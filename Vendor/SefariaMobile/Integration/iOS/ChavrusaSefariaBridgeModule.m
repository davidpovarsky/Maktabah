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
#elif __has_include("RCTBridgeModule.h")
#import "RCTBridgeModule.h"
#endif

#ifdef RCT_EXTERN_MODULE

@interface RCT_EXTERN_MODULE(ChavrusaSefariaBridgeModule, NSObject)

RCT_EXTERN_METHOD(registerJSDispatcher:(id)dispatcher)
RCT_EXTERN_METHOD(deliverResponse:(NSString *)jsonString)
RCT_EXTERN_METHOD(deliverEvent:(NSString *)jsonString)

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

@end

#endif

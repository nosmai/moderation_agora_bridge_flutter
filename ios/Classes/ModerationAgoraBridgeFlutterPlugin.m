#import "ModerationAgoraBridgeFlutterPlugin.h"
#import "VideoModerationController.h"

@interface ModerationAgoraBridgeFlutterPlugin ()
@property(nonatomic, strong) VideoModerationController *controller;
@end

@implementation ModerationAgoraBridgeFlutterPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel =
      [FlutterMethodChannel methodChannelWithName:@"moderation_agora_bridge_flutter"
                                  binaryMessenger:[registrar messenger]];
  ModerationAgoraBridgeFlutterPlugin* instance = [[ModerationAgoraBridgeFlutterPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"getNativeHandle" isEqualToString:call.method]) {
    NSString *appId = call.arguments[@"appId"];
    if (appId.length == 0) {
      result([FlutterError errorWithCode:@"NO_APP_ID"
                                 message:@"agoraAppId is required"
                                 details:nil]);
      return;
    }
    [self.controller dispose];
    self.controller = [[VideoModerationController alloc] initWith:appId];
    intptr_t handle = [self.controller getNativeHandle];
    result(@((int64_t)handle));
  } else if ([@"notifyCameraSwitch" isEqualToString:call.method]) {
    [self.controller notifyCameraSwitch];
    result(nil);
  } else if ([@"disposeNative" isEqualToString:call.method]) {
    [self.controller dispose];
    self.controller = nil;
    result(nil);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

@end

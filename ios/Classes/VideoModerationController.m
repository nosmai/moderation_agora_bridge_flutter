#import <Foundation/Foundation.h>
#import "VideoModerationController.h"
#import <AgoraRtcKit/AgoraRtcKit.h>
#import <CoreVideo/CoreVideo.h>
#import <objc/message.h>

// Forward a captured frame to the Nosmai Moderation plugin over the ObjC
// runtime, so this bridge links no Nosmai code and ships no models. The
// nosmai_moderation_sdk plugin exposes:
//   + (void)pushExternalPixelBuffer:(CVPixelBufferRef)buffer rotationDegrees:(int)degrees
static void CallNosmaiPushFrame(CVPixelBufferRef buffer, int degrees) {
    Class cls = NSClassFromString(@"NosmaiExternalFrame");
    SEL sel = @selector(pushExternalPixelBuffer:rotationDegrees:);
    if (cls && [cls respondsToSelector:sel]) {
        void (*fn)(Class, SEL, CVPixelBufferRef, int) =
            (void (*)(Class, SEL, CVPixelBufferRef, int))objc_msgSend;
        fn(cls, sel, buffer, degrees);
    }
}

@interface VideoModerationController () <AgoraRtcEngineDelegate, AgoraVideoFrameDelegate>
@property(nonatomic, strong) AgoraRtcEngineKit *agoraRtcEngine;
@property(nonatomic, assign) int frameCount;
@end

@implementation VideoModerationController

- (instancetype)initWith:(NSString *)appId {
    self = [super init];
    if (self) {
        AgoraRtcEngineConfig *config = [[AgoraRtcEngineConfig alloc] init];
        config.appId = appId;
        self.agoraRtcEngine = [AgoraRtcEngineKit sharedEngineWithConfig:config delegate:self];
        [self.agoraRtcEngine setLocalVideoMirrorMode:AgoraVideoMirrorModeDisabled];
        self.frameCount = 0;
        [self.agoraRtcEngine setVideoFrameDelegate:self];
    }
    return self;
}

- (intptr_t)getNativeHandle {
    return (intptr_t)[self.agoraRtcEngine getNativeHandle];
}

- (void)notifyCameraSwitch {
    // Agora delivers upright BGRA frames and the moderation SDK re-detects per
    // frame, so nothing is needed here. Reserved for parity with Android.
}

- (void)dispose {
    [self.agoraRtcEngine setVideoFrameDelegate:NULL];
    [AgoraRtcEngineKit destroy];
    self.agoraRtcEngine = nil;
}

#pragma mark - AgoraVideoFrameDelegate

- (BOOL)onCaptureVideoFrame:(AgoraOutputVideoFrame *)videoFrame
                 sourceType:(AgoraVideoSourceType)sourceType {
    self.frameCount += 1;
    if (self.frameCount % 5 != 0) return YES;      // ~3 frames/sec to the detector
    if (videoFrame.type != 14) return YES;          // 14 = BGRA CVPixelBuffer
    CVPixelBufferRef buffer = videoFrame.pixelBuffer;
    if (buffer == NULL) return YES;
    // pushFrame snapshots the pixels synchronously inside the SDK, so it is safe
    // to hand it the buffer straight from the capture thread.
    CallNosmaiPushFrame(buffer, 0);
    return YES;    // read-only: the outgoing frame is never modified
}

- (AgoraVideoFormat)getVideoFormatPreference { return AgoraVideoFormatCVPixelBGRA; }
- (AgoraVideoFrameProcessMode)getVideoFrameProcessMode { return AgoraVideoFrameProcessModeReadOnly; }
- (BOOL)getRotationApplied { return YES; }
- (BOOL)getMirrorApplied { return NO; }

@end

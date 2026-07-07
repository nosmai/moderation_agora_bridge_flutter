#import <Foundation/Foundation.h>

@interface VideoModerationController : NSObject
- (instancetype)initWith:(NSString *)appId;
- (intptr_t)getNativeHandle;
- (void)notifyCameraSwitch;
- (void)dispose;
@end

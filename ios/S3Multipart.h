
#ifdef RCT_NEW_ARCH_ENABLED
#import "RNS3MultipartSpec.h"

@interface S3Multipart : NSObject <NativeS3MultipartSpec>
#else
#import <React/RCTBridgeModule.h>

@interface S3Multipart : NSObject <RCTBridgeModule>
#endif

@end

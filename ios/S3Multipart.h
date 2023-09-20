#import <AWSCore/AWSCore.h>
#import <AWSS3/AWSS3.h>

#ifdef RCT_NEW_ARCH_ENABLED

#import "RNS3MultipartSpec.h"
@interface S3Multipart : RCTEventEmitter <NativeS3MultipartSpec>

#else

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
@interface S3Multipart : RCTEventEmitter <RCTBridgeModule>

#endif

typedef NS_ENUM(NSInteger, CredentialType) {
    BASIC,
    COGNITO
};

+ (NSMutableDictionary*)nativeCredentialsOptions;
+ (CredentialType)credentialType: (NSString *)type;
+ (void)interceptApplication: (UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler;

@end

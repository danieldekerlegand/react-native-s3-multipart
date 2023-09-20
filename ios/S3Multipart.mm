#import "S3Multipart.h"
#import "RNS3STSCredentialsProvider.h"

static NSMutableDictionary *nativeCredentialsOptions;
static bool alreadyInitialize = false;
static bool enabledProgress = true;
static NSString* instanceKey = @"S3Multipart";
static int completedPercentage = 0;

@interface S3Multipart ()

@property (copy, nonatomic) AWSS3TransferUtilityMultiPartUploadCompletionHandlerBlock completionUploadHandler;
@property (copy, nonatomic) AWSS3TransferUtilityMultiPartProgressBlock uploadProgress;
@property (copy, nonatomic) AWSS3TransferUtilityDownloadCompletionHandlerBlock completionDownloadHandler;
@property (copy, nonatomic) AWSS3TransferUtilityProgressBlock downloadProgress;

@end

@implementation S3Multipart

+ (NSMutableDictionary *)nativeCredentialsOptions {
    if (nativeCredentialsOptions) {
        return nativeCredentialsOptions;
    }
    nativeCredentialsOptions = [NSMutableDictionary new];
    // default options
    [nativeCredentialsOptions setObject:@"eu-west-1" forKey:@"region"];
    [nativeCredentialsOptions setObject:@"eu-west-1" forKey:@"cognito_region"];
    [nativeCredentialsOptions setObject:@YES forKey:@"remember_last_instance"];
    return nativeCredentialsOptions;
};

+ (CredentialType)credentialType: (NSString *)type {
    if ([type isEqualToString:@"COGNITO"]) {
        return COGNITO;
    } else {
        return BASIC;
    }
}

+ (void)interceptApplication: (UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler {
  [AWSS3TransferUtility interceptApplication:application handleEventsForBackgroundURLSession:identifier completionHandler:completionHandler];
}

/*
 * Only referenced s3 support: http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region
 */
- (AWSRegionType)regionTypeFromString: (NSString*)region {
    AWSRegionType regionType = AWSRegionUnknown;
    if ([region isEqualToString:@"us-east-1"]) {
        regionType = AWSRegionUSEast1;
    } else if ([region isEqualToString:@"us-east-2"]) {
        regionType = AWSRegionUSEast2;
    } else if ([region isEqualToString:@"us-west-1"]) {
        regionType = AWSRegionUSWest1;
    } else if ([region isEqualToString:@"us-west-2"]) {
        regionType = AWSRegionUSWest2;
    } else if ([region isEqualToString:@"ca-central-1"]) {
        regionType = AWSRegionCACentral1;
    } else if ([region isEqualToString:@"ap-south-1"]) {
        regionType = AWSRegionAPSouth1;
    } else if ([region isEqualToString:@"ap-northeast-1"]) {
        regionType = AWSRegionAPNortheast1;
    } else if ([region isEqualToString:@"ap-northeast-2"]) {
        regionType = AWSRegionAPNortheast2;
    } else if ([region isEqualToString:@"ap-southeast-1"]) {
        regionType = AWSRegionAPSoutheast1;
    } else if ([region isEqualToString:@"ap-southeast-2"]) {
        regionType = AWSRegionAPSoutheast2;
    } else if ([region isEqualToString:@"eu-central-1"]) {
        regionType = AWSRegionEUCentral1;
    } else if ([region isEqualToString:@"eu-west-1"]) {
        regionType = AWSRegionEUWest1;
    } else if ([region isEqualToString:@"eu-west-2"]) {
        regionType = AWSRegionEUWest2;
    } else if ([region isEqualToString:@"sa-east-1"]) {
        regionType = AWSRegionSAEast1;
    } else if ([region isEqualToString:@"cn-north-1"]) {
        regionType = AWSRegionCNNorth1;
    }
    return regionType;
}

/*
 * We need keep last instance, otherwise JS reload will break background tasks
 * If you need setup again with different config, just set `remember_last_instance` to false
 */
- (BOOL)setup:(NSDictionary *)options {
    AWSS3TransferUtility *transferUtility = [AWSS3TransferUtility S3TransferUtilityForKey:instanceKey];
    if ([options[@"remember_last_instance"] boolValue] && transferUtility) {
      return YES;
    } else if (transferUtility) {
      NSLog(@"forget last instance");
      NSNotificationCenter * __weak center = [NSNotificationCenter defaultCenter];
      id __block token = [center addObserverForName:@"com.amazonaws.AWSS3TransferUtility.AWSS3TransferUtilityURLSessionDidBecomeInvalidNotification"
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *notification) {
          NSLog(@"instance destroyed");
          [self createNewTransferUtility:options];
          [center removeObserver:token];
        }];

      [AWSS3TransferUtility removeS3TransferUtilityForKey:instanceKey];
    } else {
      [self createNewTransferUtility:options];
    }
    return YES;
}

- (void) createNewTransferUtility:(NSDictionary *)options {
  id<AWSCredentialsProvider> credentialsProvider;

  NSString *accessKey = options[@"access_key"];
  NSString *secretKey = options[@"secret_key"];
  NSString *sessionKey = options[@"session_token"];

  if (sessionKey) {
    credentialsProvider = [[RNS3STSCredentialsProvider alloc] initWithAccessKey:accessKey secretKey:secretKey sessionKey:sessionKey];
  } else {
    credentialsProvider = [[AWSStaticCredentialsProvider alloc] initWithAccessKey:accessKey secretKey:secretKey];
  }

  AWSRegionType region = [self regionTypeFromString:options[@"region"]];
  AWSServiceConfiguration *configuration = [[AWSServiceConfiguration alloc] initWithRegion:region credentialsProvider:credentialsProvider];

  if ([options[@"allows_cellular_access"] boolValue]) {
    NSLog(@"allowsCellularAccess: true");
    configuration.allowsCellularAccess = true;
  } else {
    NSLog(@"allowsCellularAccess: false");
    configuration.allowsCellularAccess = false;
  }

  AWSS3TransferUtilityConfiguration *transferUtilityConfiguration = [[AWSS3TransferUtilityConfiguration alloc] init];
  transferUtilityConfiguration.timeoutIntervalForResource = 60 * 60 * 24;
  transferUtilityConfiguration.retryLimit = 10;

    NSLog(@"registerS3TransferUtilityWithConfiguration multipart");
    
  [AWSS3TransferUtility registerS3TransferUtilityWithConfiguration:configuration transferUtilityConfiguration:transferUtilityConfiguration forKey:instanceKey];

  //return YES;
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(multiply:(double)a
                  b:(double)b
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSNumber *result = @(a * b);

    resolve(result);
}

RCT_EXPORT_METHOD(setupWithNative: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    resolve(@([self setup:nativeCredentialsOptions]));
}

RCT_EXPORT_METHOD(setupWithBasic: (NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    NSMutableDictionary * mOptions = [options mutableCopy];
    [mOptions setObject:[NSNumber numberWithInt:BASIC] forKey:@"type"];
    resolve(@([self setup:mOptions]));
}

RCT_EXPORT_METHOD(setupWithCognito: (NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    NSMutableDictionary * mOptions = [options mutableCopy];
    [mOptions setObject:[NSNumber numberWithInt:COGNITO] forKey:@"type"];
    resolve(@([self setup:mOptions]));
}

RCT_EXPORT_METHOD(enableProgressSent: (BOOL)enabled resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    enabledProgress = enabled;
    resolve(@YES);
}

- (void) sendEvent:(AWSS3TransferUtilityMultiPartUploadTask *)task type:(NSString *)type state:(NSString *)state bytes:(int64_t)bytes totalBytes:(int64_t)totalBytes error:(NSError *)error {
    NSDictionary *errorObj = nil;
    if (error) {
        errorObj = @{
                     @"domain":[error domain],
                     @"code": @([error code]),
                     @"description": [error localizedDescription]
                     };
    }

    if ([state isEqual: @"in_progress"] && !enabledProgress) {
        return;
    }
    [self sendEventWithName:@"@_S3Multipart_Events"
     body:@{
            @"task":@{
                    @"id": [task transferID],
                    // @"bucket":[task bucket],
                    // @"key":[task key],
                    @"state":state,
                    @"bytes":@(bytes),
                    @"totalBytes":@(totalBytes)
                    },
            @"type":type,
            @"error":errorObj ? errorObj : [NSNull null]
            }];
}

RCT_EXPORT_METHOD(initializeRNS3) {
    if (alreadyInitialize) return;
    alreadyInitialize = NO;
    
    self.uploadProgress = ^(AWSS3TransferUtilityMultiPartUploadTask *task, NSProgress *progress) {
        float percentage = (100*progress.completedUnitCount)/progress.totalUnitCount;
        int percentageAsInt = (int)percentage;
        if (percentageAsInt > completedPercentage) {
            completedPercentage = (int)percentage;
            NSLog(@"completedPercentage: %i", completedPercentage);
            [self sendEvent:task
                       type:@"upload"
                      state:@"in_progress"
                      bytes:progress.completedUnitCount
                 totalBytes:progress.totalUnitCount
                      error:nil];
        }
    };
    
    self.completionUploadHandler = ^(AWSS3TransferUtilityMultiPartUploadTask *task, NSError *error) {
        NSString *state;
        if (error) state = @"failed"; else state = @"completed";
        [self sendEvent:task
                   type:@"upload"
                  state:state
                  bytes:0
             totalBytes:0
                  error:error];
    };
}

RCT_EXPORT_METHOD(upload: (NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    NSLog(@"start multipart upload");
    NSURL *fileURL = [NSURL fileURLWithPath:[options objectForKey:@"file"]];
    NSDictionary *meta = [options objectForKey:@"meta"];

    AWSS3TransferUtilityMultiPartUploadExpression  *expression = [AWSS3TransferUtilityMultiPartUploadExpression  new];
    if (meta) {
        for (id key in meta) {
            NSString *value = [meta objectForKey:key];
            [expression setValue:value forRequestHeader:key];
        }
    }

    expression.progressBlock = self.uploadProgress;

    completedPercentage = 0;

    AWSS3TransferUtility *transferUtility = [AWSS3TransferUtility S3TransferUtilityForKey:instanceKey];
    [[transferUtility uploadFileUsingMultiPart:fileURL
                                        bucket:[options objectForKey:@"bucket"]
                                           key:[options objectForKey:@"key"]
                                   contentType:[meta objectForKey:@"Content-Type"]
                                    expression:expression
                             completionHandler:self.completionUploadHandler] continueWithBlock:^id(AWSTask *task) {
        if (task.error) {
            reject([NSString stringWithFormat: @"%lu", (long)task.error.code], task.error.localizedDescription, task.error);
        } else if (task.result) {
            AWSS3TransferUtilityMultiPartUploadTask *uploadTask = task.result;
            resolve(@{
                      @"id": [uploadTask transferID],
                      // @"bucket": [uploadTask bucket],
                      // @"key": [uploadTask key],
                      @"state":@"waiting"
                      });
        }
        return nil;
    }];
}

RCT_EXPORT_METHOD(pause:(NSString *)taskIdentifier) {
    [self taskById:taskIdentifier completionHandler:^(NSDictionary *result) {
        if (result && ![result isEqual:[NSNull null]]) {
            NSString *type = [result objectForKey:@"type"];
            AWSS3TransferUtilityMultiPartUploadTask *task = [result objectForKey:@"task"];
            NSLog(@"Calling suspend on task: %@", task.transferID);
            [task suspend];
            [self sendEvent:task
                       type:type
                      state:@"paused"
                      bytes:0
                 totalBytes:0
                      error:nil];
        }
    }];

}

RCT_EXPORT_METHOD(resume:(NSString *)taskIdentifier) {
    [self taskById:taskIdentifier completionHandler:^(NSDictionary *result) {
        if (result && ![result isEqual:[NSNull null]]) {
            NSString *type = [result objectForKey:@"type"];
            AWSS3TransferUtilityMultiPartUploadTask *task = [result objectForKey:@"task"];
            NSLog(@"Calling resume on task: %@", task.transferID);
            [task resume];
            [self sendEvent:task
                       type:type
                      state:@"in_progress"
                      bytes:0
                 totalBytes:0
                      error:nil];
        }
    }];
}

RCT_EXPORT_METHOD(cancel:(NSString *)taskIdentifier) {
    [self taskById:taskIdentifier completionHandler:^(NSDictionary *result) {
        if (result && ![result isEqual:[NSNull null]]) {
            NSString *type = [result objectForKey:@"type"];
            AWSS3TransferUtilityMultiPartUploadTask *task = [result objectForKey:@"task"];
            [task cancel];
            [self sendEvent:task
                       type:type
                      state:@"canceled"
                      bytes:0
                 totalBytes:0
                      error:nil];
        }
    }];
}

RCT_EXPORT_METHOD(cancelAllUploads) {
    NSLog(@"TransferUtilityMultipart cancelAllUploads");
    AWSS3TransferUtility *transferUtility = [AWSS3TransferUtility S3TransferUtilityForKey:instanceKey];

    [[transferUtility getUploadTasks] continueWithBlock:^id(AWSTask *task) {
        if (task.result) {
            NSArray<AWSS3TransferUtilityUploadTask*> *uploadTasks = task.result;
            for (AWSS3TransferUtilityUploadTask *task in uploadTasks) {
                NSLog(@"TransferUtilityMultipart cancel task %@", [task transferID]);
                [task cancel];
            }
        }
        return nil;
    }];

    [[transferUtility getMultiPartUploadTasks] continueWithBlock:^id(AWSTask *task) {
        if (task.result) {
            NSArray<AWSS3TransferUtilityMultiPartUploadTask*> *uploadTasks = task.result;
            for (AWSS3TransferUtilityMultiPartUploadTask *task in uploadTasks) {
                NSLog(@"TransferUtilityMultipart cancel multipart task %@", [task transferID]);
                [task cancel];
            }
        }
        return nil;
    }];
}

- (void) taskById:(NSString *)taskIdentifier completionHandler:(void(^)(NSDictionary *))handler {
    NSLog(@"Get taskById: %@", taskIdentifier);
    //__block NSDictionary *result = [NSNull null];
    AWSS3TransferUtility *transferUtility = [AWSS3TransferUtility S3TransferUtilityForKey:instanceKey];
    [[transferUtility getMultiPartUploadTasks] continueWithBlock:^id(AWSTask *task) {
        if (task.result) {
            NSArray<AWSS3TransferUtilityMultiPartUploadTask*> *uploadTasks = task.result;

            for (AWSS3TransferUtilityMultiPartUploadTask *task in uploadTasks) {
                NSLog(@"Upload task: %@", task.transferID);
                if ([task.transferID isEqualToString:taskIdentifier]) {
                    NSLog(@"Found task");
                    handler(@{@"type":@"upload", @"task":task});
                    return nil;
                }
            }
        }
        handler(nil);
        return nil;
    }];
}

RCT_EXPORT_METHOD(getTask:(NSString *)taskIdentifier resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    [self taskById:taskIdentifier completionHandler:^(NSDictionary *result) {
        if (result && ![result isEqual:[NSNull null]]) {
            AWSS3TransferUtilityMultiPartUploadTask *task = [result objectForKey:@"task"];
            resolve(@{
                      @"id": [task transferID],
                      //@"bucket":[task bucket],
                      //@"key":[task key],
                      });
        } else {
            resolve([NSNull null]);
        }
    }];
}

RCT_EXPORT_METHOD(getTasks:(NSString *)type resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    AWSS3TransferUtility *transferUtility = [AWSS3TransferUtility S3TransferUtilityForKey:instanceKey];
    NSMutableArray *result = [[NSMutableArray alloc] init];
    if ([type isEqualToString:@"upload"]) {
        [[transferUtility getMultiPartUploadTasks] continueWithBlock:^id(AWSTask *task) {
            if (task.result) {
                NSArray<AWSS3TransferUtilityMultiPartUploadTask*> *uploadTasks = task.result;
                for (AWSS3TransferUtilityMultiPartUploadTask *task in uploadTasks) {
                    [result addObject:@{
                                        @"id":[task transferID],
                                        // @"bucket":[task bucket],
                                        // @"key":[task key],
                                        }];
                }
                resolve(result);
            } else {
                resolve(nil);
            }
            return nil;
        }];
    }
}

@end

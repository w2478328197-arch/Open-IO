#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
test_root=build/heart-rate-tests
mkdir -p "$test_root/stubs/UIKit" "$test_root/stubs/WatchConnectivity"
cat > "$test_root/stubs/UIKit/UIKit.h" <<'HEADER'
#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger,UIApplicationState){UIApplicationStateActive=0,UIApplicationStateBackground=2};
@interface UIApplication:NSObject
+ (instancetype)sharedApplication;
@property UIApplicationState applicationState;
@end
HEADER
cat > "$test_root/stubs/WatchConnectivity/WatchConnectivity.h" <<'HEADER'
#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger,WCSessionActivationState){WCSessionActivationStateNotActivated=0,WCSessionActivationStateActivated=2};
@interface WCSession:NSObject
+ (BOOL)isSupported;
+ (instancetype)defaultSession;
@property id delegate;
@property WCSessionActivationState activationState;
@property BOOL paired,watchAppInstalled,reachable;
@property NSDictionary *applicationContext,*lastMessage;
- (BOOL)updateApplicationContext:(NSDictionary *)context error:(NSError **)error;
- (void)sendMessage:(NSDictionary *)message replyHandler:(void (^)(NSDictionary *))reply errorHandler:(void (^)(NSError *))error;
@end
HEADER
xcrun clang -fobjc-arc -fblocks -fmodules -Wall -Wextra -Wno-unused-parameter -Wno-incompatible-pointer-types \
  -DTIO_WORKOUT_TEST_NO_FILES=1 -fsanitize=address,undefined -I"$test_root/stubs" -framework Foundation \
  HeartRateWatchBridge.m WorkoutDashboardCore.m HeartRateBridgeTests.m WorkoutDashboardTests.m -o "$test_root/check"
"$test_root/check"

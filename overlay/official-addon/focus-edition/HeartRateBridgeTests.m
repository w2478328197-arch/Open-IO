#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <WatchConnectivity/WatchConnectivity.h>
#import "HeartRateWatchBridge.h"

@implementation UIApplication
+ (instancetype)sharedApplication { static UIApplication *app; if(!app)app=[self new];return app; }
@end
@implementation WCSession
+ (BOOL)isSupported { return YES; }
+ (instancetype)defaultSession { static WCSession *session; if(!session)session=[self new];return session; }
- (BOOL)updateApplicationContext:(NSDictionary *)context error:(NSError **)error { self.applicationContext=context;return YES; }
- (void)sendMessage:(NSDictionary *)message replyHandler:(void (^)(NSDictionary *))reply errorHandler:(void (^)(NSError *))error { self.lastMessage=message; }
@end
@interface TCCueWatch:NSObject @end
@implementation TCCueWatch @end
@interface HRTestDefaults:NSUserDefaults
@property NSMutableDictionary *values;
@end
@implementation HRTestDefaults
- (id)objectForKey:(NSString *)key { return self.values[key]; }
- (void)setObject:(id)value forKey:(NSString *)key { self.values[key]=value; }
@end

void RunWorkoutDashboardTests(void);

int main(void) { @autoreleasepool {
    HRTestDefaults *defaults=[HRTestDefaults new];defaults.values=[NSMutableDictionary new];
    method_setImplementation(class_getClassMethod(NSUserDefaults.class,@selector(standardUserDefaults)),imp_implementationWithBlock(^id(id cls){return defaults;}));
    WCSession *session=WCSession.defaultSession;TCCueWatch *owner=[TCCueWatch new];session.delegate=owner;
    session.activationState=WCSessionActivationStateActivated;session.paired=YES;session.watchAppInstalled=YES;session.reachable=YES;
    UIApplication.sharedApplication.applicationState=UIApplicationStateActive;
    session.applicationContext=@{@"projects":@[@{@"id":@"existing-cue-project"}],@"revision":@8};
    TIOHeartRateWatchSetPageActive(YES);
    NSCAssert(session.delegate==owner,@"Heart-rate page must not replace the Cue Cards delegate");
    defaults.values[@"TIOHeartRateZoneStartsV1"]=@[@100,@120,@150,@180];
    NSCAssert(TIOHeartRateWatchContext()[@"zoneStarts"]==nil,@"Old manual thresholds must never reach Watch");
    NSCAssert([session.applicationContext[@"revision"] isEqual:@8]&&[session.applicationContext[@"projects"] count]==1,@"HealthKit mode must preserve Cue Cards context");
    NSCAssert(!TIOHeartRateWatchHandleMessage(@{@"action":@"start",@"projectID":@"cue"},nil),@"Cue Cards start must remain in the Cue Cards route");
    NSString *run=NSUUID.UUID.UUIDString;__block NSDictionary *answer;
    void (^reply)(NSDictionary *)=^(NSDictionary *a){answer=a;};
    TIOHeartRateWatchHandleMessage(@{@"version":@1,@"kind":@"start",@"runID":run,@"requestedAt":@(NSDate.date.timeIntervalSince1970)},reply);
    NSCAssert([answer[@"captureAllowed"] boolValue],@"Foreground heart-rate page allows explicit Watch start");
    NSTimeInterval now=NSDate.date.timeIntervalSince1970;
    NSMutableDictionary *sample=[@{@"version":@1,@"kind":@"heartRate",@"runID":run,@"source":@"healthkit-live-watch",@"heartRate":@152,@"sampleAt":@(now-1)} mutableCopy];
    TIOHeartRateWatchHandleMessage(sample,reply);
    NSCAssert([answer[@"accepted"] boolValue]&&[TIOHeartRateWatchSample()[@"heartRate"] isEqual:@152],@"Accept fresh sample in current run");
    sample[@"heartRate"]=@160;TIOHeartRateWatchHandleMessage(sample,reply);
    NSCAssert(![answer[@"accepted"] boolValue]&&[TIOHeartRateWatchSample()[@"heartRate"] isEqual:@152],@"Duplicate sample timestamps cannot replace readings");
    sample[@"sampleAt"]=@(now-16);TIOHeartRateWatchHandleMessage(sample,reply);
    NSCAssert(![answer[@"accepted"] boolValue],@"Reject stale data");
    sample[@"sampleAt"]=@(now);sample[@"runID"]=NSUUID.UUID.UUIDString;TIOHeartRateWatchHandleMessage(sample,reply);
    NSCAssert(![answer[@"accepted"] boolValue],@"Reject samples from another run");
    TIOHeartRateWatchSetPageActive(NO);
    NSCAssert(TIOHeartRateWatchSample()!=nil&&!session.lastMessage,@"Leaving the page must not stop an active outdoor run");
    UIApplication.sharedApplication.applicationState=UIApplicationStateBackground;
    sample[@"runID"]=run;sample[@"sampleAt"]=@(now+0.0001);
    sample[@"sampleAt"]=@(NSDate.date.timeIntervalSince1970);
    TIOHeartRateWatchHandleMessage(sample,reply);
    NSCAssert([answer[@"accepted"] boolValue]&&[answer[@"captureAllowed"] boolValue],@"Accept current-run data with the phone in background");
    TIOHeartRateWatchStop();TIOHeartRateWatchHandleMessage(sample,reply);
    NSCAssert([answer[@"stopRequested"] boolValue]&&TIOHeartRateWatchSample()!=nil,@"Explicit finish must wait for Watch saving receipt");
    TIOHeartRateWatchHandleMessage(@{@"version":@1,@"kind":@"finished",@"runID":run,@"saved":@YES,@"activity":@"outdoorRun"},reply);
    NSCAssert(!TIOHeartRateWatchSample(),@"Only completion ends the current run");
    TIOHeartRateWatchHandleMessage(@{@"version":@1,@"kind":@"start",@"runID":run,@"requestedAt":@(now-30)},reply);
    NSCAssert(![answer[@"captureAllowed"] boolValue],@"Do not accept delayed start requests");
    NSCAssert(session.delegate==owner,@"Cue Cards still owns connectivity after stop");
    RunWorkoutDashboardTests();
    NSLog(@"PASS shared Watch routing: cue context, explicit starts, zones, fresh samples, replay rejection and stop");
}return 0;}

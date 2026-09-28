#import <Foundation/Foundation.h>
#import "WorkoutDashboardCore.h"
#import "HeartRateWatchBridge.h"
#import <UIKit/UIKit.h>
#include "../../firmware-research/strix-1.0.4.12/native-navigation/workout/workout_wire.h"

void RunWorkoutDashboardTests(void) {
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    NSDictionary *configuration = @{@"source":@"healthkit", @"configurationSource":@"user", @"zones":@[
        @{@"index":@0,@"maximum":@123.5}, @{@"index":@1,@"minimum":@123.5,@"maximum":@140},
        @{@"index":@2,@"minimum":@140,@"maximum":@155}, @{@"index":@3,@"minimum":@155,@"maximum":@175}, @{@"index":@4,@"minimum":@175} ]};
    NSMutableDictionary *m = [@{@"version":@1, @"kind":@"workout", @"source":@"healthkit-live-watch", @"runID":NSUUID.UUID.UUIDString,
        @"snapshotAt":@(now - 0.1), @"startedAt":@(now - 100), @"sequence":@1, @"elapsedSeconds":@100,
        @"heartRate":@145.7, @"heartRateAt":@(now - 1), @"paceSecondsPerKM":@359.7, @"paceAt":@(now - 2),
        @"cadenceSPM":@174.3, @"cadenceAt":@(now - 3), @"strideMeters":@1.03, @"strideAt":@(now - 4),
        @"activeEnergyKcal":@212.3, @"energyAt":@(now - 50), @"distanceMeters":@1200, @"distanceAt":@(now - 4), @"zoneState":@"ready", @"zoneConfiguration":configuration,
        @"zoneIndex":@2, @"zoneUpdatedAt":@(now - 80), @"mode":@"outdoorRun"} mutableCopy];
    NSDictionary *clean = TIOWorkoutSanitize(m, now), *d = TIOWorkoutDisplay(clean, now);
    NSCAssert([d[@"heart"] isEqual:@"146"] && [d[@"pace"] isEqual:@"6′00″"], @"Round only display values, including minute carry");
    NSCAssert([d[@"zone"] isEqual:@"Z3"] && [d[@"zonePosition"] isEqual:@3], @"Use native index's ordinal; unchanged-zone callback need not repeat every 15 seconds");
    NSCAssert([d[@"stride"] isEqual:@"1.03"] && [d[@"cadence"] isEqual:@"174"] && [d[@"distance"] isEqual:@"1.20"], @"Metric units must be retained");
    NSCAssert([d[@"energy"] isEqual:@"212"], @"Active energy is a HealthKit workout total; older unchanged sample stays valid while the session is fresh");
    NSData *native=TIOWorkoutNativeFrame(clean,now); TWData w; NSCAssert(native.length==sizeof w,@"Native frame exists");[native getBytes:&w length:sizeof w];
    NSCAssert(w.heart==146 && !strcmp(w.zone_range,"140-<155") && w.zone==3,@"Wire preserves HealthKit current zone, never derives it from rounded heart rate");
    NSMutableDictionary *edge=[clean mutableCopy];edge[@"zoneIndex"]=@0;native=TIOWorkoutNativeFrame(edge,now);[native getBytes:&w length:sizeof w];
    NSCAssert(!strcmp(w.zone_range,"<123.5"),@"Fractional outer bound remains exact");
    edge[@"zoneIndex"]=@4;native=TIOWorkoutNativeFrame(edge,now);[native getBytes:&w length:sizeof w];NSCAssert(!strcmp(w.zone_range,">=175"),@"Open upper zone remains open");
    edge[@"paused"]=@YES;native=TIOWorkoutNativeFrame(edge,now);[native getBytes:&w length:sizeof w];NSCAssert(!w.zone&&!w.zone_range[0]&&w.heart==TW_MISSING16&&w.distance_cm==120000,@"Paused native frame retains totals only");
    NSCAssert(!TIOWorkoutNativeFrame(clean,now+16),@"Expired frame cannot refresh lens data");
    NSMutableDictionary *longRun=[m mutableCopy];longRun[@"startedAt"]=@(now-10800);longRun[@"elapsedSeconds"]=@10800;
    NSCAssert([TIOWorkoutDisplay(TIOWorkoutSanitize(longRun,now),now)[@"elapsed"] isEqual:@"3:00:00"], @"No 20-minute collection limit");
    NSString *text = TIOWorkoutGlassesText(clean, now);
    NSCAssert([text componentsSeparatedByString:@"\n"].count == 5 && [text lengthOfBytesUsingEncoding:NSUTF8StringEncoding] <= 384, @"Actual lens payload fits the five-line 384-byte contract");
    m[@"paceAt"]=@(now - 16); d = TIOWorkoutDisplay(TIOWorkoutSanitize(m, now), now);
    NSCAssert([d[@"pace"] isEqual:@"—"] && [d[@"heart"] isEqual:@"146"] && [d[@"stride"] isEqual:@"1.03"], @"Expire each sensor independently");
    d = TIOWorkoutDisplay(clean, now + 16);
    for (NSString *k in @[@"heart",@"pace",@"cadence",@"stride",@"distance",@"energy",@"zone",@"elapsed"]) NSCAssert([d[k] isEqual:@"—"], @"Do not leave stale values on the lens");
    [m removeObjectForKey:@"zoneIndex"]; d = TIOWorkoutDisplay(TIOWorkoutSanitize(m, now), now);
    NSCAssert([d[@"zone"] isEqual:@"—"], @"Do not infer a zone when native current zone is absent");
    m[@"zoneStarts"]=@[@100,@120,@150,@180]; m[@"zoneConfiguration"]=@{}; m[@"zoneIndex"]=@2;
    clean = TIOWorkoutSanitize(m, now); NSCAssert(clean[@"zoneConfiguration"] == nil && [clean[@"zoneState"] isEqual:@"unavailable"], @"Never fall back to manual or malformed zones");
    m[@"heartRate"]=@YES; m[@"strideMeters"]=@(NAN); m[@"cadenceAt"]=@(now + 1);
    clean = TIOWorkoutSanitize(m, now); NSCAssert(!clean[@"heartRate"] && !clean[@"strideMeters"] && !clean[@"cadenceSPM"], @"Reject booleans, NaN, and future timestamps");
    m[@"paused"]=@YES; clean = TIOWorkoutSanitize(m, now); NSCAssert(clean[@"distanceMeters"] && clean[@"activeEnergyKcal"] && !clean[@"heartRate"], @"Pause retains session totals and clears live readings");
    m[@"snapshotAt"]=@(now - 16); NSCAssert(!TIOWorkoutSanitize(m, now), @"Reject stale transport snapshots");

    UIApplication.sharedApplication.applicationState=UIApplicationStateActive; TIOHeartRateWatchSetPageActive(YES);
    NSString *run=NSUUID.UUID.UUIDString; __block NSDictionary *reply;
    TIOHeartRateWatchHandleMessage(@{@"version":@1,@"kind":@"start",@"runID":run,@"requestedAt":@(NSDate.date.timeIntervalSince1970)}, ^(NSDictionary *a){reply=a;});
    NSCAssert(reply[@"zoneStarts"]==nil, @"Start reply cannot overwrite HealthKit zones");
    m[@"runID"]=run; m[@"snapshotAt"]=@(now - 0.1); m[@"paused"]=@NO; m[@"heartRate"]=@145.7; m[@"zoneConfiguration"]=configuration;
    TIOHeartRateWatchHandleMessage(m, ^(NSDictionary *a){reply=a;}); NSCAssert([reply[@"accepted"] boolValue], @"Accept new workout snapshot");
    TIOHeartRateWatchHandleMessage(m, ^(NSDictionary *a){reply=a;}); NSCAssert(![reply[@"accepted"] boolValue], @"Reject duplicate snapshot sequence");
    m[@"sequence"]=@2; m[@"cadenceAt"]=@(now - 1); m[@"cadenceSPM"]=@180;
    TIOHeartRateWatchHandleMessage(m, ^(NSDictionary *a){reply=a;});
    NSCAssert([reply[@"accepted"] boolValue] && [TIOHeartRateWatchSample()[@"cadenceSPM"] isEqual:@180], @"Cadence can update without a new heart-rate sample");
    m[@"sequence"]=@3; m[@"startedAt"]=@(now - 110);
    TIOHeartRateWatchHandleMessage(m, ^(NSDictionary *a){reply=a;}); NSCAssert(![reply[@"accepted"] boolValue], @"A run cannot silently change its start time");
    TIOHeartRateWatchDisconnected(); NSCAssert(!TIOHeartRateWatchSample(), @"Disconnect clears full dashboard");
    NSLog(@"PASS workout dashboard: native zones, unit formatting, independent freshness, pause, five-line payload, run and sequence guards");
}

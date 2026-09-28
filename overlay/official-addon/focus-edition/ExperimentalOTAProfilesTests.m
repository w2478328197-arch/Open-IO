#import "ExperimentalOTA.h"
#import "ExperimentalOTAFeed.h"
#import "ExperimentalOTAFlash.h"
#import "ResearchCatalog.h"
#include <assert.h>
// Display transports are outside this offline firmware test.
BOOL TIOImageUploadIsScopedCall(NSString *m,NSDictionary *a){return NO;}
BOOL TDPPhoneIsScopedCall(NSString *m,NSDictionary *a){return NO;}
static void Var(NSMutableData *d,uint64_t n){do{uint8_t b=n&127;n>>=7;if(n)b|=128;[d appendBytes:&b length:1];}while(n);}
static NSData *Frame(unsigned type,id json,NSData *binary){NSMutableData *d=[NSMutableData data];Var(d,8);Var(d,1);Var(d,16);Var(d,type);NSData *j=[NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingSortedKeys error:nil];Var(d,26);Var(d,j.length);[d appendData:j];if(binary){Var(d,34);Var(d,binary.length);[d appendData:binary];}return d;}
static NSData *Get(NSString *url){dispatch_semaphore_t done=dispatch_semaphore_create(0);__block NSData *body;__block NSError *failure;NSURLSessionDataTask *task=[NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){body=data;failure=error;dispatch_semaphore_signal(done);}];[task resume];assert(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC))==0);assert(!failure);return body;}
int main(int argc,const char *argv[]){@autoreleasepool{
 assert(argc==3);NSString *fixture=[NSString stringWithUTF8String:argv[1]],*temporary=[NSString stringWithUTF8String:argv[2]];NSError *e=nil;
 NSArray *codes=TIOExperimentalOTAProfiles();NSMutableDictionary *archives=[NSMutableDictionary new];
 assert([TIOOTAFlashAuthorizationIssueForStatus(@{}) containsString:@"保护"]);
 assert([TIOOTAFlashAuthorizationIssueForStatus(@{@"protected":@YES}) containsString:@"自动更新"]);
 assert([TIOOTAFlashAuthorizationIssueForStatus(@{@"protected":@YES,@"automaticUpdateDisabled":@YES}) containsString:@"读取眼镜版本"]);
 assert(!TIOOTAFlashAuthorizationIssueForStatus(@{@"protected":@YES,@"automaticUpdateDisabled":@YES,@"recentTargetVersionRead":@YES}));
 assert(!TIOOTAAutoUpdateDisabled(@{}));assert(!TIOOTAAutoUpdateDisabled(@{@"fixture_ota_firmware_auto_update":@YES}));
 assert(TIOOTAAutoUpdateDisabled(@{@"fixture_ota_firmware_auto_update":@NO}));assert(TIOOTAAutoUpdateDisabled(@{@"fixture_ota_firmware_auto_update":@"false"}));
 for(NSString *code in codes){NSURL *archive=[NSURL fileURLWithPath:[[fixture stringByAppendingPathComponent:code] stringByAppendingPathExtension:@"zip"]];archives[code]=archive;assert(TIOReadExperimentalOTAForProfile(archive,code,&e));
  for(NSString *other in codes)if(![other isEqual:code])assert(!TIOReadExperimentalOTAForProfile(archive,other,&e));
  NSURL *dir=[NSURL fileURLWithPath:[fixture stringByAppendingPathComponent:code] isDirectory:YES];assert([TIOCheckExperimentalOTADirectoryForProfile(dir,code,&e)[@"checkedMembers"] integerValue]==15);
  NSURL *store=[NSURL fileURLWithPath:[temporary stringByAppendingPathComponent:code] isDirectory:YES];assert(TIOImportExperimentalOTAForProfile(archive,store,code,&e));
 }
 assert(!TIOExperimentalOTAProfile(@"../unknown"));
 assert(!TIOExperimentalOTAProfile(nil));
 assert(![TIOExperimentalOTAStoreDirectory(@"TFP1") isEqual:TIOExperimentalOTAStoreDirectory(@"TWK1")]);
 NSMutableSet *keys=[NSMutableSet new];for(NSDictionary *section in TIOResearchSections(@"diagnostics"))for(NSDictionary *row in section[@"rows"]){assert(![keys containsObject:row[@"key"]]);[keys addObject:row[@"key"]];if([row[@"key"] isEqual:@"experimentalOTA"])assert([row[@"title"] isEqual:@"眼镜导航固件 · FOCUS-04"]);}
 for(NSString *key in @[@"experimentalOTA",@"experimentalOTACueCards",@"experimentalOTAWorkout",@"workoutFirmwareLab",@"subtitleHUD",@"displayPhone",@"imageRXLab"])assert([keys containsObject:key]);
 TIOOTAFlashGate *gate=[TIOOTAFlashGate new];assert(![gate allows:Frame(4,@{@"Mode":@2},nil) device:@"fixture" uptime:0]);
 TIOExperimentalOTAFeed *feed=[TIOExperimentalOTAFeed new];assert([feed startOnPort:0 error:&e]);
 for(NSString *code in codes){assert([feed armArchive:archives[code] profile:code lifetime:60 error:&e]);assert([feed.status[@"profile"] isEqual:code]);assert([feed.status[@"downloadRequests"] integerValue]==0);
  NSString *other=[code isEqual:@"TFP1"]?@"TWK1":@"TFP1";assert(!TIOExperimentalOTAAcquireProfile(other,&e));
  NSDictionary *before=gate.status;assert(TIOReadExperimentalOTAForProfile(archives[other],other,&e));assert([before isEqual:gate.status]);assert([feed.status[@"profile"] isEqual:code]);
  NSString *url=[NSString stringWithFormat:@"http://127.0.0.1:%u/g/xxxxxxxA78p2M?packageType=firmware&packageName=strix%%20OS&glassesType=S3&deviceType=iOS&versionCode=01.00.04.0012",feed.port];
  NSDictionary *reply=[NSJSONSerialization JSONObjectWithData:Get(url) options:0 error:&e];NSDictionary *item=reply[@"data"];assert([item[@"taskName"] containsString:code]);NSData *download=Get(item[@"downloadUrl"]);assert(TIOCheckExperimentalOTAForProfile(download,code,&e));assert(!TIOCheckExperimentalOTAForProfile(download,other,&e));
  assert(![gate allows:Frame(4,@{@"Mode":@2},nil) device:@"fixture" uptime:1]);[feed disarm];
 }
 for(NSString *code in @[@"TFP1",@"TCC1"]){@autoreleasepool{
  TIOOTAFlashGate *legacy=[TIOOTAFlashGate new];NSURL *dir=[NSURL fileURLWithPath:[fixture stringByAppendingPathComponent:code] isDirectory:YES];
  assert([legacy prepareDirectory:dir profile:code device:@"fixture" uptime:10 error:&e]);assert([legacy.status[@"profile"] isEqual:code]);
  assert([legacy allows:Frame(3,@{@"OtaSize":TIOExperimentalOTAProfile(code)[@"bytes"]},nil) device:@"fixture" uptime:11]);
  assert([legacy allows:Frame(4,@{@"Mode":@2},nil) device:@"fixture" uptime:11]);assert([legacy allows:Frame(5,@{@"OtaVersion":@"Strix OS 1.0.4.12"},nil) device:@"fixture" uptime:12]);
  NSArray *manifest=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[dir URLByAppendingPathComponent:@"OtaFileInfo.json"]] options:0 error:nil];assert([legacy allows:Frame(6,manifest,nil) device:@"fixture" uptime:13]);
  NSData *ap=[NSData dataWithContentsOfURL:[dir URLByAppendingPathComponent:@"nuttx_ap.bin"]];assert([legacy allows:Frame(7,@{@"Name":@"nuttx_ap.bin",@"Start":@0,@"Size":@32},[ap subdataWithRange:NSMakeRange(0,32)]) device:@"fixture" uptime:14]);
  assert(![legacy cancel]);assert(!TIOExperimentalOTAAcquireProfile(@"TWK1",&e));legacy=nil;
 }assert(TIOExperimentalOTAAcquireProfile(@"TWK1",&e));TIOExperimentalOTAReleaseProfile(@"TWK1");}
 NSURL *twk=[NSURL fileURLWithPath:[fixture stringByAppendingPathComponent:@"TWK1"] isDirectory:YES];assert([gate prepareDirectory:twk profile:@"TWK1" device:@"fixture" uptime:10 error:&e]);assert(!TIOExperimentalOTAAcquireProfile(@"TFP1",&e));assert(![feed armArchive:archives[@"TFP1"] profile:@"TFP1" lifetime:60 error:&e]);
 assert(![gate allows:Frame(4,@{@"Mode":@2},nil) device:@"fixture" uptime:910]);assert([[gate status][@"failure"] containsString:@"15 分钟"]);assert([gate cancel]);assert(TIOExperimentalOTAAcquireProfile(@"TFP1",&e));TIOExperimentalOTAReleaseProfile(@"TFP1");
 assert(![gate prepareDirectory:twk profile:@"TFP1" device:@"fixture" uptime:10 error:&e]);
 assert([gate prepareDirectory:twk profile:@"TWK1" device:@"fixture" uptime:10 error:&e]);
 assert([gate allows:Frame(4,@{@"Mode":@2},nil) device:@"fixture" uptime:11]);assert(![gate cancel]);
 assert([gate allows:Frame(5,@{@"OtaVersion":@"Strix OS 1.0.4.12"},nil) device:@"fixture" uptime:12]);
 NSArray *manifest=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[twk URLByAppendingPathComponent:@"OtaFileInfo.json"]] options:0 error:nil];assert([gate allows:Frame(6,manifest,nil) device:@"fixture" uptime:13]);
 NSData *ap=[NSData dataWithContentsOfURL:[twk URLByAppendingPathComponent:@"nuttx_ap.bin"]];NSData *slice=[ap subdataWithRange:NSMakeRange(0,32)];NSDictionary *meta=@{@"Name":@"nuttx_ap.bin",@"Start":@0,@"Size":@32};assert([gate allows:Frame(7,meta,slice) device:@"fixture" uptime:14]);
 NSMutableData *bad=[slice mutableCopy];((uint8_t *)bad.mutableBytes)[0]^=1;assert(![gate allows:Frame(7,meta,bad) device:@"fixture" uptime:15]);assert([gate.status[@"stage"] integerValue]==3);assert([gate.status[@"validatedSlices"] integerValue]==1);assert(!TIOExperimentalOTAAcquireProfile(@"TFP1",&e));
 gate=nil;
 @autoreleasepool{TIOOTAFlashGate *complete=[TIOOTAFlashGate new];assert([complete prepareDirectory:twk profile:@"TWK1" device:@"fixture" uptime:20 error:&e]);
  assert([complete allows:Frame(4,@{@"Mode":@2},nil) device:@"fixture" uptime:21]);assert([complete allows:Frame(5,@{@"OtaVersion":@"Strix OS 1.0.4.12"},nil) device:@"fixture" uptime:22]);assert([complete allows:Frame(6,manifest,nil) device:@"fixture" uptime:23]);
  NSDictionary *files=TIOCopyExperimentalOTAPayloadsForProfile(twk,@"TWK1",&e);NSUInteger bytes=0,slices=0;
  for(NSString *name in files){if([name isEqual:@"OtaFileInfo.json"])continue;NSData *file=files[name];for(NSUInteger start=0;start<file.length;start+=51200){NSUInteger length=MIN(51200,file.length-start);assert([complete allows:Frame(7,@{@"Name":name,@"Start":@(start),@"Size":@(length)},[file subdataWithRange:NSMakeRange(start,length)]) device:@"fixture" uptime:24]);bytes+=length;slices++;}}
  assert([complete.status[@"validatedSliceBytes"] unsignedIntegerValue]==bytes);assert([complete.status[@"validatedSlices"] unsignedIntegerValue]==slices);NSLog(@"PASS: complete TWK1 payload replay: %lu bytes in %lu slices (mock device, no Bluetooth)",(unsigned long)bytes,(unsigned long)slices);
 }
 [feed stop];
 NSLog(@"PASS: three separate routes and packages; exact 15-file checks; cross-profile rejection; loopback downloads; no flash during local experiments; profile lock through authorization/transfer; modified slice rejected.");
}return 0;}

#import "TodoMirrorLedger.h"
#import "TodoProtocol.h"
#include <assert.h>
static NSDictionary *Apple(NSString *identifier,NSString *title,NSInteger status){return @{@"identifier":identifier,@"externalIdentifier":[@"external-" stringByAppendingString:identifier],@"calendarIdentifier":@"todo",@"title":title,@"status":@(status),@"createdAt":@1000};}
static NSDictionary *Wire(NSString *wire,NSString *title,NSInteger status){return @{@"wireId":wire,@"title":title,@"status":@(status),@"createTime":@"1000",@"lastModifiedTime":@"1000",@"isImportant":@NO};}
static NSData *Packet(NSDictionary *body){NSData *json=[NSJSONSerialization dataWithJSONObject:body options:0 error:nil];NSMutableData *out=[NSMutableData dataWithBytes:"\x08\x01\x10\x06\x1a" length:5];NSUInteger n=json.length;while(n>=128){uint8_t b=(n&127)|128;[out appendBytes:&b length:1];n>>=7;}uint8_t b=n;[out appendBytes:&b length:1];[out appendData:json];return out;}
int main(void){@autoreleasepool{
    NSString *suite=[@"io.turboio.mirror-test." stringByAppendingString:NSUUID.UUID.UUIDString];NSUserDefaults *defaults=[[NSUserDefaults alloc]initWithSuiteName:suite];
    TIOTodoMirrorLedger *l=[[TIOTodoMirrorLedger alloc]initWithDefaults:defaults];
    NSDictionary *a=Apple(@"one",@"Same title",0),*b=Apple(@"two",@"Same title",0),*done=Apple(@"history",@"Old history",1);
    [l reconcileApple:@[a,b,done] officialRows:@[] device:@"d1" now:2000];NSArray *r=[l recordsForDevice:@"d1"];assert(r.count==2);
    NSString *source=r[0][@"source"],*wire=r[0][@"wireId"],*identifier=r[0][@"apple"][@"identifier"];
    assert(![wire isEqual:r[1][@"wireId"]]&&wire.longLongValue<9007199254740991LL);
    [l reconcileApple:@[a,b,done] officialRows:@[] device:@"d1" now:2100];assert([l recordsForDevice:@"d1"].count==2);
    l=[[TIOTodoMirrorLedger alloc]initWithDefaults:defaults];assert([l ownsWire:wire device:@"d1"]&&![l ownsWire:wire device:@"d2"]);
    assert([[l recordForSource:source][@"wireId"] isEqual:wire]);
    NSDictionary *renamed=Apple(identifier,@"Renamed on Apple",0);NSDictionary *other=[identifier isEqual:@"one"]?b:a;
    [l reconcileApple:@[renamed,other] officialRows:@[] device:@"d1" now:2200];
    assert([[l recordForSource:source][@"row"][@"title"] isEqual:@"Renamed on Apple"]);
    [l observeStatus:1 wire:wire device:@"d1"];NSDictionary *pending=[l recordForSource:source][@"pendingApple"];
    assert([pending[@"fields"][@"status"] isEqual:@1]&&[pending[@"expected"][@"status"] isEqual:@0]);
    l=[[TIOTodoMirrorLedger alloc]initWithDefaults:defaults];assert([l recordForSource:source][@"pendingApple"]);
    [l finishAppleWrite:source pending:pending result:@{@"status":@"failed"}];assert([l recordForSource:source][@"pendingApple"]);
    NSDictionary *completed=Apple(identifier,@"Renamed on Apple",1);
    [l finishAppleWrite:source pending:pending result:@{@"status":@"updated",@"item":completed}];assert(![l recordForSource:source][@"pendingApple"]);
    [l observeStatus:1 wire:wire device:@"d1"];assert(![l recordForSource:source][@"pendingApple"]); // echo
    [l observeStatus:0 wire:wire device:@"d1"];assert([[l recordForSource:source][@"pendingApple"][@"fields"][@"status"] isEqual:@0]);
    NSDictionary *newer=[l recordForSource:source][@"pendingApple"];
    [l finishAppleWrite:source pending:pending result:@{@"status":@"updated",@"item":completed}];assert([[l recordForSource:source][@"pendingApple"] isEqual:newer]);
    [l finishAppleWrite:source pending:newer result:@{@"status":@"conflict",@"item":completed}];assert(![l recordForSource:source][@"pendingApple"]&&[l recordForSource:source][@"lastConflict"]);
    // Missing rows mean paused scope, not deletion or recreating another item.
    [l reconcileApple:@[other] officialRows:@[] device:@"d1" now:2300];assert(![l handlesSource:source]&&[l ownsWire:wire device:@"d1"]);
    [l reconcileApple:@[completed,other] officialRows:@[] device:@"d1" now:2400];assert([l handlesSource:source]);
    NSMutableDictionary *migrated=[completed mutableCopy];migrated[@"identifier"]=@"new-local-id";
    [l reconcileApple:@[migrated,other] officialRows:@[] device:@"d1" now:2500];assert([l recordsForDevice:@"d1"].count==2&&[[l recordForSource:source][@"apple"][@"identifier"] isEqual:@"new-local-id"]);
    // A future official collision is preserved rather than overwritten.
    [l reconcileApple:@[migrated,other] officialRows:@[Wire(wire,@"Official collision",0)] device:@"d1" now:2600];assert(![l handlesSource:source]);
    // Existing official links retain their ID and never import completed history.
    NSMutableDictionary *linked=[Apple(@"linked",@"Existing",0) mutableCopy];linked[@"sourceID"]=@"d1:77";linked[@"hasLink"]=@YES;
    NSMutableDictionary *unavailable=[Apple(@"unavailable",@"Same title",0) mutableCopy];unavailable[@"hasLink"]=@YES;
    [l reconcileApple:@[linked,unavailable] officialRows:@[Wire(@"77",@"Existing",0)] device:@"d1" now:2700];assert([l recordForSource:@"d1:77"]&&![l ownsWire:@"77" device:@"d1"]&&[l recordsForDevice:@"d1"].count==3);
    [l observeOfficialRows:@[Wire(@"77",@"Edited official",1)] device:@"d1"];
    NSDictionary *p=[l recordForSource:@"d1:77"][@"pendingApple"];assert([p[@"fields"][@"title"] isEqual:@"Edited official"]&&[p[@"fields"][@"status"] isEqual:@1]);
    [l finishAppleWrite:@"d1:77" pending:p result:@{@"status":@"updated",@"item":Apple(@"linked",@"Edited official",1)}];
    [l observeOfficialRows:@[Wire(@"77",@"Edited official",1)] device:@"d1"];assert(![l recordForSource:@"d1:77"][@"pendingApple"]);
    // Reconnect keeps a newer Apple change if the glasses still report their
    // old baseline; an actual offline toggle relative to baseline is applied.
    NSMutableDictionary *reopened=[Apple(@"linked",@"Edited official",0) mutableCopy];reopened[@"sourceID"]=@"d1:77";
    [l observeBatchStatus:1 wire:@"77" device:@"d1"];
    [l reconcileApple:@[reopened] officialRows:@[Wire(@"77",@"Edited official",1)] device:@"d1" now:2800];
    [l observeBatchStatus:1 wire:@"77" device:@"d1"];assert(![l recordForSource:@"d1:77"][@"pendingApple"]);
    assert(![l observeStatus:7 wire:@"77" device:@"d1"]&&![l observeStatus:1 wire:@"77" device:@"d2"]);
    NSDictionary *foreign=@{@"eventType":@1,@"eventID":@77,@"title":@"Old title",@"status":@1,@"createTime":@1000,@"isImportant":@YES,@"unknown":@"preserve"};
    NSDictionary *schedule=@{@"eventType":@2,@"eventID":@99,@"scheduleData":@{@"start":@111,@"futureKey":@YES}};
    NSDictionary *own=@{@"source":@"d1:500",@"revision":@"r1",@"owned":@YES,@"active":@YES,@"bound":@YES,@"row":Wire(@"500",@"Apple imported",0)};
    NSDictionary *existing=@{@"source":@"d1:77",@"revision":@"r2",@"owned":@NO,@"active":@YES,@"bound":@YES,@"row":Wire(@"77",@"Apple edited",0)};
    NSData *full=Packet(@{@"total":@2,@"isLastBatch":@YES,@"eventList":@[foreign,schedule],@"futureHeader":@"keep"});
    NSDictionary *overlay=TIOTodoOverlaySnapshot(full,@[own,existing],3000);NSDictionary *body=TIOTodoEnvelope(overlay[@"payload"])[@"json"];
    assert([body[@"total"] isEqual:@3]&&[body[@"eventList"][1] isEqual:schedule]&&[body[@"futureHeader"] isEqual:@"keep"]);
    assert([body[@"eventList"][0][@"title"] isEqual:@"Apple edited"]&&[body[@"eventList"][0][@"status"] isEqual:@0]&&[body[@"eventList"][0][@"unknown"] isEqual:@"preserve"]&&[body[@"eventList"][0][@"isImportant"] isEqual:@YES]);
    assert([body[@"eventList"][2][@"eventID"] isEqual:@500]&&[overlay[@"receipts"] count]==2);
    assert(!TIOTodoOverlaySnapshot(Packet(@{@"total":@3,@"isLastBatch":@NO,@"eventList":@[foreign]}),@[own],3000));
    NSMutableDictionary *collision=[own mutableCopy];collision[@"row"]=Wire(@"99",@"Never replace schedule",0);assert(!TIOTodoOverlaySnapshot(full,@[collision],3000));
    [defaults removePersistentDomainForName:suite];puts("PASS: stable identities, two-way fields, restart/retry/dedup, reconnect, conflicts and full snapshot overlay preserving foreign tasks, schedules and metadata.");
}return 0;}

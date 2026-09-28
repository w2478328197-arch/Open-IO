#import "AppleCalendarSync.h"
#import <EventKit/EventKit.h>
#import <objc/runtime.h>
#include <assert.h>
@interface MirrorCalendar:NSObject
@property(nonatomic,copy) NSString *title,*calendarIdentifier;
@property(nonatomic) BOOL allowsContentModifications;
@end
@implementation MirrorCalendar @end
@interface MirrorReminder:NSObject
@property(nonatomic,copy) NSString *title,*calendarItemIdentifier,*calendarItemExternalIdentifier,*notes;
@property(nonatomic,strong) MirrorCalendar *calendar;
@property(nonatomic,strong) NSDate *creationDate,*lastModifiedDate,*completionDate;
@property(nonatomic,strong) NSDateComponents *dueDateComponents;
@property(nonatomic) NSInteger priority;
@property(nonatomic,getter=isCompleted) BOOL completed;
@end
@implementation MirrorReminder
- (BOOL)isKindOfClass:(Class)c{return c==EKReminder.class||[super isKindOfClass:c];}
@end
@interface MirrorStore:NSObject
@property(nonatomic,strong) NSArray *lists,*items;
@property(nonatomic) NSUInteger saves;
@property(nonatomic) BOOL failSave,missingReadback;
@end
@implementation MirrorStore
- (NSArray *)calendarsForEntityType:(EKEntityType)t{assert(t==EKEntityTypeReminder);return self.lists;}
- (NSPredicate *)predicateForRemindersInCalendars:(NSArray *)lists{assert(lists.count==1&&[lists[0] calendarIdentifier]);return [NSPredicate predicateWithValue:YES];}
- (id)fetchRemindersMatchingPredicate:(NSPredicate *)p completion:(void (^)(NSArray *))c{c(self.items);return nil;}
- (id)calendarItemWithIdentifier:(NSString *)identifier{if(self.missingReadback&&self.saves)return nil;for(MirrorReminder *r in self.items)if([r.calendarItemIdentifier isEqual:identifier])return r;return nil;}
- (NSArray *)calendarItemsWithExternalIdentifier:(NSString *)identifier{if(self.missingReadback&&self.saves)return @[];NSMutableArray *out=[NSMutableArray array];for(MirrorReminder *r in self.items)if([r.calendarItemExternalIdentifier isEqual:identifier])[out addObject:r];return out;}
- (BOOL)saveReminder:(MirrorReminder *)r commit:(BOOL)c error:(NSError **)e{assert(c);self.saves++;return !self.failSave;}
@end
static MirrorStore *Store;static NSUserDefaults *Defaults;static EKAuthorizationStatus Auth=EKAuthorizationStatusFullAccess;
static id NewStore(id cls,SEL cmd) __attribute__((ns_returns_retained));static id NewStore(id cls,SEL cmd){return Store;}
static id Def(id cls,SEL cmd){return Defaults;}static EKAuthorizationStatus Access(id cls,SEL cmd,EKEntityType t){return Auth;}
static NSDictionary *Await(void(^start)(void(^)(NSDictionary *))){__block NSDictionary *result=nil;start(^(NSDictionary *r){result=r;});NSDate *end=[NSDate dateWithTimeIntervalSinceNow:2];while(!result&&end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];assert(result);return result;}
static NSDictionary *Read(void){return Await(^(void(^done)(NSDictionary *)){TIOAppleReadTodoList(done);});}
static NSDictionary *Apply(NSDictionary *expected,NSDictionary *fields){return Await(^(void(^done)(NSDictionary *)){TIOAppleApplyTodoFields(@"synthetic:55",expected,fields,done);});}
int main(void){@autoreleasepool{
    NSString *suite=[@"io.turboio.apple-mirror-test." stringByAppendingString:NSUUID.UUID.UUIDString];Defaults=[[NSUserDefaults alloc]initWithSuiteName:suite];Store=[MirrorStore new];
    class_replaceMethod(object_getClass(NSUserDefaults.class),@selector(standardUserDefaults),(IMP)Def,"@@:");class_replaceMethod(object_getClass(EKEventStore.class),@selector(new),(IMP)NewStore,"@@:");
    Method a=class_getClassMethod(EKEventStore.class,@selector(authorizationStatusForEntityType:));class_replaceMethod(object_getClass(EKEventStore.class),@selector(authorizationStatusForEntityType:),(IMP)Access,method_getTypeEncoding(a));
    MirrorCalendar *list=[MirrorCalendar new];list.title=@"待办";list.calendarIdentifier=@"todo";list.allowsContentModifications=YES;Store.lists=@[list];
    MirrorReminder *r=[MirrorReminder new];r.title=@"Synthetic";r.calendarItemIdentifier=@"local-one";r.calendarItemExternalIdentifier=@"external-one";r.calendar=list;r.notes=@"keep notes";r.dueDateComponents=[NSDateComponents new];r.dueDateComponents.year=2027;r.priority=3;Store.items=@[r];
    NSDictionary *read=Read();assert([read[@"status"] isEqual:@"ok"]&&[read[@"items"] count]==1&&Store.saves==0);NSDictionary *identity=read[@"items"][0];
    NSDictionary *bind=Await(^(void(^done)(NSDictionary *)){TIOAppleBindTodoIdentity(@"synthetic:55",identity,done);});assert([bind[@"status"] isEqual:@"linked"]&&Store.saves==0);
    assert([Read()[@"items"][0][@"hasLink"] boolValue]);
    NSDictionary *update=Apply(@{@"status":@0},@{@"status":@1});assert([update[@"status"] isEqual:@"updated"]&&r.isCompleted&&r.completionDate&&Store.saves==1);
    assert([Apply(@{@"status":@0},@{@"status":@1})[@"status"] isEqual:@"unchanged"]&&Store.saves==1);
    assert([Apply(@{@"status":@1},@{@"status":@0})[@"status"] isEqual:@"updated"]&&!r.isCompleted&&!r.completionDate);
    assert([Apply(@{@"title":@"Synthetic"},@{@"title":@"Renamed"})[@"status"] isEqual:@"updated"]);
    assert([r.notes isEqual:@"keep notes"]&&r.dueDateComponents.year==2027&&r.priority==3);
    NSUInteger saves=Store.saves;assert([Apply(@{@"title":@"Synthetic"},@{@"title":@"Conflict"})[@"status"] isEqual:@"conflict"]&&Store.saves==saves&&[r.title isEqual:@"Renamed"]);
    assert([Apply(@{},@{@"notes":@"unexpected"})[@"status"] isEqual:@"invalid"]&&Store.saves==saves);
    // Local ID recovery is by exact external identity inside the chosen list.
    r.calendarItemIdentifier=@"local-two";assert([Apply(@{@"title":@"Renamed"},@{@"title":@"Recovered"})[@"status"] isEqual:@"updated"]);
    assert([TIOAppleTodoLinkIdentity(@"synthetic:55")[@"identifier"] isEqual:@"local-two"]);
    list.allowsContentModifications=NO;saves=Store.saves;assert([Apply(@{@"status":@0},@{@"status":@1})[@"status"] isEqual:@"target_list_read_only"]&&Store.saves==saves);list.allowsContentModifications=YES;
    MirrorCalendar *other=[MirrorCalendar new];other.title=@"Work";other.calendarIdentifier=@"work";other.allowsContentModifications=YES;r.calendar=other;
    assert([Apply(@{@"status":@0},@{@"status":@1})[@"status"] isEqual:@"outside_list"]&&Store.saves==saves);r.calendar=list;
    Auth=EKAuthorizationStatusDenied;assert([Read()[@"status"] isEqual:@"permission_denied"]);assert([Apply(@{@"status":@0},@{@"status":@1})[@"status"] isEqual:@"permission_denied"]);Auth=EKAuthorizationStatusFullAccess;
    Store.items=nil;assert([Read()[@"status"] isEqual:@"fetch_failed"]);Store.items=@[r];Store.missingReadback=YES;Store.saves=0;
    assert([Apply(@{@"status":@0},@{@"status":@1})[@"status"] isEqual:@"verification_failed"]);
    [Defaults removePersistentDomainForName:suite];puts("PASS: scoped EventKit read, exact binding, complete/reopen, rename, metadata preservation, no-op, conflict, identifier recovery, readonly/outside-list/permission failures and fresh readback required.");
}return 0;}

#import "AppleCalendarSync.h"
#import <EventKit/EventKit.h>
#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>
#include <assert.h>

// Production creation code with isolated preferences and an in-memory EventKit
// boundary. This test never accesses personal calendars or saves Apple data.
@interface TIOTodoListTestCalendar:NSObject
@property(nonatomic,copy) NSString *title,*calendarIdentifier;
@property(nonatomic) BOOL allowsContentModifications;
@end
@implementation TIOTodoListTestCalendar @end

@interface TIOTodoListTestReminder:NSObject
@property(nonatomic,copy) NSString *title,*calendarItemIdentifier,*calendarItemExternalIdentifier;
@property(nonatomic,strong) TIOTodoListTestCalendar *calendar;
@end
@implementation TIOTodoListTestReminder @end

@interface TIOTodoListTestStore:NSObject
@property(nonatomic,strong) NSArray *lists;
@property(nonatomic,strong) TIOTodoListTestCalendar *defaultCalendarForNewReminders;
@property(nonatomic,strong) TIOTodoListTestReminder *lastSaved;
@property(nonatomic) NSUInteger saves;
@end
@implementation TIOTodoListTestStore
- (NSArray *)calendarsForEntityType:(EKEntityType)type{assert(type==EKEntityTypeReminder);return self.lists;}
- (BOOL)saveReminder:(TIOTodoListTestReminder *)item commit:(BOOL)commit error:(NSError **)error{
    assert(commit);self.saves++;self.lastSaved=item;item.calendarItemIdentifier=NSUUID.UUID.UUIDString;item.calendarItemExternalIdentifier=NSUUID.UUID.UUIDString;return YES;
}
@end

static TIOTodoListTestStore *Store;
static NSUserDefaults *Defaults;
static id NewStore(id cls,SEL cmd) __attribute__((ns_returns_retained));
static id NewStore(id cls,SEL cmd){return Store;}
static id StandardDefaults(id cls,SEL cmd){return Defaults;}
static EKAuthorizationStatus Access(id cls,SEL cmd,EKEntityType type){return EKAuthorizationStatusFullAccess;}
static id NewReminder(id cls,SEL cmd,id store){assert(store==Store);return [TIOTodoListTestReminder new];}
static TIOTodoListTestCalendar *List(NSString *name,NSString *identifier,BOOL writable){
    TIOTodoListTestCalendar *list=[TIOTodoListTestCalendar new];list.title=name;list.calendarIdentifier=identifier;list.allowsContentModifications=writable;return list;
}
static NSDictionary *Create(NSString *source){
    __block NSDictionary *result=nil;TIOAppleCreateReminder(@"合成待办",source,^(NSDictionary *value){result=value;});assert(result);return result;
}
static NSString *RelinkKey(NSString *source){
    NSData *data=[source dataUsingEncoding:NSUTF8StringEncoding];unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes,(CC_LONG)data.length,hash);
    NSMutableString *key=[@"io.turboio.apple.todo." mutableCopy];
    for(int i=0;i<CC_SHA256_DIGEST_LENGTH;i++)[key appendFormat:@"%02x",hash[i]];
    return [key stringByAppendingString:@".needsRelink"];
}

int main(void){@autoreleasepool{
    NSString *suite=[@"io.turboio.todo-list-tests." stringByAppendingString:NSUUID.UUID.UUIDString];
    Defaults=[[NSUserDefaults alloc]initWithSuiteName:suite];Store=[TIOTodoListTestStore new];
    class_replaceMethod(object_getClass(NSUserDefaults.class),@selector(standardUserDefaults),(IMP)StandardDefaults,"@@:");
    class_replaceMethod(object_getClass(EKEventStore.class),@selector(new),(IMP)NewStore,"@@:");
    Method access=class_getClassMethod(EKEventStore.class,@selector(authorizationStatusForEntityType:));
    class_replaceMethod(object_getClass(EKEventStore.class),@selector(authorizationStatusForEntityType:),(IMP)Access,method_getTypeEncoding(access));
    Method factory=class_getClassMethod(EKReminder.class,@selector(reminderWithEventStore:));
    class_replaceMethod(object_getClass(EKReminder.class),@selector(reminderWithEventStore:),(IMP)NewReminder,method_getTypeEncoding(factory));

    TIOTodoListTestCalendar *work=List(@"💼工作",@"work",YES),*todo=List(@"待办",@"todo",YES);
    Store.defaultCalendarForNewReminders=work;Store.lists=@[work,todo];
    assert([Create(@"test-device:1")[@"status"] isEqual:@"created"]);
    assert(Store.saves==1&&Store.lastSaved.calendar==todo&&Store.defaultCalendarForNewReminders==work);
    assert([Create(@"test-device:1")[@"deduplicated"] boolValue]&&Store.saves==1);

    // A rename keeps the selected identity; a deleted list never falls back to Work.
    todo.title=@"新名称";assert([Create(@"test-device:2")[@"status"] isEqual:@"created"]);
    assert(Store.saves==2&&Store.lastSaved.calendar==todo);
    Store.lists=@[work];assert([Create(@"test-device:3")[@"status"] isEqual:@"target_list_missing"]);assert(Store.saves==2);

    // After an identifier change, rebind only a unique, writable named list.
    TIOTodoListTestCalendar *replacement=List(@"待办",@"todo-new",YES);Store.lists=@[work,replacement];
    assert([Create(@"test-device:3")[@"status"] isEqual:@"created"]&&Store.saves==3&&Store.lastSaved.calendar==replacement);
    [Defaults removeObjectForKey:@"io.turboio.apple.todo.destinationCalendar.v1"];
    Store.lists=@[work,replacement,List(@"待办",@"duplicate",YES)];
    assert([Create(@"test-device:4")[@"status"] isEqual:@"target_list_ambiguous"]&&Store.saves==3);
    Store.lists=@[work,replacement];replacement.allowsContentModifications=NO;
    assert([Create(@"test-device:4")[@"status"] isEqual:@"target_list_read_only"]&&Store.saves==3);
    [Defaults setBool:YES forKey:RelinkKey(@"test-device:relink")];
    assert(TIOAppleNeedsRelink(@"test-device:relink"));
    assert([Create(@"test-device:relink")[@"status"] isEqual:@"needs_relink"]&&Store.saves==3);
    [Defaults removePersistentDomainForName:suite];
    puts("PASS: dedicated todo list, unchanged system default, exact ID retention, no fallback, ambiguity/read-only guards and dedup.");
}return 0;}

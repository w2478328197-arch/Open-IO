#import "TodoCompletionLedger.h"
#include <assert.h>

int main(int argc,const char *argv[]) {@autoreleasepool {
    assert(argc==3);
    NSString *mode=[NSString stringWithUTF8String:argv[1]],*suite=[NSString stringWithUTF8String:argv[2]];
    assert([suite hasPrefix:@"io.turboio.todo.ledger-tests."]);
    NSUserDefaults *defaults=[[NSUserDefaults alloc]initWithSuiteName:suite];
    if([mode isEqual:@"cleanup"]){[defaults removePersistentDomainForName:suite];return 0;}
    if([mode isEqual:@"write"]){
        [defaults removePersistentDomainForName:suite];
        TIOTodoCompletionLedger *ledger=[[TIOTodoCompletionLedger alloc]initWithDefaults:defaults];
        assert(ledger.pendingCount==0);
        [ledger markPending:@"synthetic-device:7" title:@"合成待办七"];
        [ledger markPending:@"synthetic-device:7"];
        [ledger markPending:@""];
        [ledger markPending:@"synthetic-device:8"];
        assert(ledger.pendingCount==2);
        [ledger markConfirmationPresented:@"synthetic-device:7"];
        assert(![ledger shouldPresentConfirmation:@"synthetic-device:7"]);
        [ledger markPending:@"synthetic-device:automatic" title:@"自动完成验收"];
        assert(![ledger authorizeAutomaticCompletion:@"synthetic-device:automatic" hasExactLink:NO]);
        assert(![ledger authorizeAutomaticCompletion:@"synthetic-device:8" hasExactLink:YES]); // No title yet.
        [ledger markConfirmationPresented:@"synthetic-device:automatic"];
        assert([ledger authorizeAutomaticCompletion:@"synthetic-device:automatic" hasExactLink:YES]);
        assert(![ledger shouldPresentConfirmation:@"synthetic-device:automatic"]);
        assert([ledger authorizeAutomaticCompletion:@"synthetic-device:automatic" hasExactLink:YES]); // Idempotent authorization.
        TIOTodoCompletionLedger *automaticRestored=[[TIOTodoCompletionLedger alloc]initWithDefaults:defaults];
        assert([automaticRestored isCompletionAuthorized:@"synthetic-device:automatic"]);
        [ledger markSynchronized:@"synthetic-device:automatic"];
        [ledger markPending:@"synthetic-device:automatic" title:@"重复完成"];
        assert(![ledger authorizeAutomaticCompletion:@"synthetic-device:automatic" hasExactLink:YES]);
        [ledger clearPending:@"synthetic-device:automatic"];
        // Reproduce a v1 installation whose alert was shown but never acted on.
        [defaults setObject:@[@"synthetic-device:7"] forKey:@"io.turboio.todo.presentedAppleCompletionConfirmations.v1"];
        [defaults synchronize];
        puts("PASS: pending Apple completion IDs saved without duplicates.");
    }else if([mode isEqual:@"read"]){
        TIOTodoCompletionLedger *ledger=[[TIOTodoCompletionLedger alloc]initWithDefaults:defaults];
        assert(ledger.pendingCount==2&&[ledger isPending:@"synthetic-device:7"]&&[ledger isPending:@"synthetic-device:8"]);
        assert([ledger shouldPresentConfirmation:@"synthetic-device:7"]);
        assert([[ledger titleForSource:@"synthetic-device:7"] isEqual:@"合成待办七"]);
        [ledger markConfirmationPresented:@"synthetic-device:7"];
        assert(![ledger shouldPresentConfirmation:@"synthetic-device:7"]);
        [ledger resetConfirmationPresentation:@"synthetic-device:7"];
        assert([ledger shouldPresentConfirmation:@"synthetic-device:7"]);
        [ledger authorizeCompletion:@"synthetic-device:7"];
        TIOTodoCompletionLedger *restored=[[TIOTodoCompletionLedger alloc]initWithDefaults:defaults];
        assert([restored isCompletionAuthorized:@"synthetic-device:7"]);
        [ledger markPending:@"synthetic-device:7" title:@"后来改过的标题"];
        assert([[ledger titleForSource:@"synthetic-device:7"] isEqual:@"合成待办七"]);
        [ledger markSynchronized:@"synthetic-device:7"];
        [ledger markPending:@"synthetic-device:7" title:@"重复回传"];
        assert(![ledger isPending:@"synthetic-device:7"]);
        [ledger deferConfirmation:@"synthetic-device:8"];
        assert(ledger.pendingCount==1);
        puts("PASS: a fresh process restores pending completion and clears only the confirmed ID.");
    }else if([mode isEqual:@"verify"]){
        TIOTodoCompletionLedger *ledger=[[TIOTodoCompletionLedger alloc]initWithDefaults:defaults];
        assert(ledger.pendingCount==1&&![ledger isPending:@"synthetic-device:7"]&&[ledger isPending:@"synthetic-device:8"]);
        assert(![ledger shouldPresentConfirmation:@"synthetic-device:8"]);
        assert(![ledger isCompletionAuthorized:@"synthetic-device:8"]);
        [ledger markPending:@"synthetic-device:8" title:@"旧版明确暂缓"];
        assert(![ledger authorizeAutomaticCompletion:@"synthetic-device:8" hasExactLink:YES]);
        [ledger markPending:@"synthetic-device:9" title:@"后一条待办"];
        assert([ledger shouldPresentConfirmation:@"synthetic-device:9"]);
        assert([ledger.pendingSources containsObject:@"synthetic-device:9"]);
        [ledger resetConfirmationPresentation:@"synthetic-device:8"];
        assert([ledger shouldPresentConfirmation:@"synthetic-device:8"]);
        assert([ledger authorizeAutomaticCompletion:@"synthetic-device:8" hasExactLink:YES]);
        [ledger markPending:@"synthetic-device:7"];
        assert(![ledger isPending:@"synthetic-device:7"]);
        [ledger clearPending:@"synthetic-device:7"]; // A real reopen permits a future completion.
        [ledger markPending:@"synthetic-device:7"];
        assert([ledger isPending:@"synthetic-device:7"]);
        [ledger clearPending:@"synthetic-device:7"];
        [ledger clearPending:@"synthetic-device:9"];
        [ledger clearPending:@"synthetic-device:8"];
        assert(ledger.pendingCount==0);
        puts("PASS: a later process reads the confirmed state and clears the final pending ID.");
    }else assert(0);
}return 0;}

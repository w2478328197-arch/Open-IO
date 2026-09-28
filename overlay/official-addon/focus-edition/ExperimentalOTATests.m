#import "ExperimentalOTA.h"
#import <Foundation/Foundation.h>
#include <stdio.h>

static BOOL Check(BOOL condition,NSString *name){
    if(!condition)fprintf(stderr,"FAIL: %s\n",name.UTF8String);
    return condition;
}

int main(int argc,const char *argv[]){
    @autoreleasepool {
        if(argc!=3&&argc!=4){fprintf(stderr,"usage: test candidate.zip extracted-directory [previous-candidate.zip]\n");return 2;}
        NSURL *archiveURL=[NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
        NSURL *directory=[NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[2]] isDirectory:YES];
        NSError *error=nil;BOOL ok=YES;
        NSData *archive=[NSData dataWithContentsOfURL:archiveURL];
        NSDictionary *result=archive?TIOCheckExperimentalOTA(archive,&error):nil;
        ok&=Check(TIOCueCardsOTABuild(),@"TCC1 build marker");
        ok&=Check([TIOExperimentalOTAProfileCode() isEqual:TIOWorkoutOTABuild()?@"TWK1":@"TCC1"],@"exact profile code");
        ok&=Check(TIOExperimentalOTAArchiveBytes()==(TIOWorkoutOTABuild()?archive.length:9301557u),@"archive byte pin");
        ok&=Check(TIOExperimentalOTAPayloadPins().count==15,@"15 payload pins");
        ok&=Check([result[@"archiveSHA256"] isEqual:TIOExperimentalOTASHA()]&&[result[@"integrityPassed"] boolValue],@"exact archive identity");
        if(archive.length){
            NSMutableData *changed=[archive mutableCopy];((uint8_t *)changed.mutableBytes)[100]^=1;error=nil;
            ok&=Check(TIOCheckExperimentalOTA(changed,&error)==nil,@"modified archive rejected");
        }else ok=NO;
        if(argc==4){NSData *previous=[NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[3]]];error=nil;ok&=Check(previous&&TIOCheckExperimentalOTA(previous,&error)==nil,@"previous candidate cannot pass the new exact identity");}
        error=nil;NSDictionary *directoryResult=TIOCheckExperimentalOTADirectory(directory,&error);
        ok&=Check([directoryResult[@"checkedMembers"] unsignedIntegerValue]==15&&[directoryResult[@"sent"] boolValue]==NO,@"all 15 extracted files match and remain unsent");
        error=nil;NSDictionary *copies=TIOCopyExperimentalOTAPayloads(directory,&error);
        ok&=Check(copies.count==15,@"verified payload snapshot");
        NSURL *apURL=[directory URLByAppendingPathComponent:@"nuttx_ap.bin"];
        NSMutableData *ap=[[NSData dataWithContentsOfURL:apURL] mutableCopy];
        if(ap.length){((uint8_t *)ap.mutableBytes)[0]^=1;ok&=Check([ap writeToURL:apURL options:NSDataWritingAtomic error:&error],@"write only test-copy corruption");}
        else ok=NO;
        error=nil;ok&=Check(TIOCheckExperimentalOTADirectory(directory,&error)==nil,@"changed payload rejected");
        if(ok)puts("TCC1 exact archive and 15-file pin tests passed; flash remains unauthorized.");
        return ok?0:1;
    }
}

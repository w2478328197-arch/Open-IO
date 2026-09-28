#import "ExperimentalOTA.h"
#import <CommonCrypto/CommonDigest.h>
#import <TargetConditionals.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <errno.h>

#import "WorkoutOTAPins.h"
#ifndef TIO_WORKOUT_OTA
#define TIO_WORKOUT_OTA 0
#endif
BOOL TIOWorkoutOTABuild(void){return TIO_WORKOUT_OTA==1;}

#ifndef TIO_CUE_CARDS_OTA
#define TIO_CUE_CARDS_OTA 0
#endif
BOOL TIOCueCardsOTABuild(void){
#if TIO_CUE_CARDS_OTA
    return YES;
#else
    return NO;
#endif
}
static NSString *SelectedProfile;
static NSUInteger ProfileUsers;
static NSString *DefaultProfile(void){return TIOWorkoutOTABuild()?@"TWK1":TIOCueCardsOTABuild()?@"TCC1":@"TFP1";}
NSArray<NSString *> *TIOExperimentalOTAProfiles(void){return @[@"TFP1",@"TCC1",@"TWK1"];}
NSString *TIOExperimentalOTAProfileCode(void){@synchronized(NSProcessInfo.processInfo){return SelectedProfile?:DefaultProfile();}}
static NSDictionary *PinsForProfile(NSString *code){
    if([code isEqual:@"TWK1"])return TWKPayloadPins();
    if([code isEqual:@"TCC1"])return @{
        @"OtaFileInfo.json":@[@2515,@"ce06b6926e16efaaf7abcfb4bfa50f66103b5b49daca16e0d6ea11c4d40b92b3"],
        @"cb_fw_venus.bin":@[@114592,@"8799f12071bdac082218e3601c24ab0989275fc2f7db74e37b8314a225c2cf7d"],
        @"fac_test_img.bin":@[@1821552,@"18eb0901c3e0daeae48dd5f015252b6931ea7368f0160c2c985c4e74296d17eb"],
        @"images.bin":@[@324283,@"192fefaa70545856884c89a9186e3f86d8f99a0738b201e116a11bc63011c158"],
        @"lotties.bin":@[@651481,@"ad66d83a3394034f825a12769aad292fc03e59fa865fe06bc43536b918a0b32b"],
        @"nuttx_ap.bin":@[@9560904,@"99f5a059668ab6ed5c8c9dbc4bc18d32f1c652533ec3ee7da246e11d8b6b76e3"],
        @"nuttx_apc1.bin":@[@1420248,@"97d56ffc6dd575ad3d8bf7739d49e491ad7e4a959db8770b653f5302e171fb5c"],
        @"nuttx_audio.bin":@[@1461920,@"549a72c032595e3829da7d63b7e1fd13cceda1a55dfefa7a7cad02db5a9b42ab"],
        @"nuttx_bth.bin":@[@1160160,@"a8f4594868bffbd3bc08a38d1f3899571608e2d57869d147de3d06f3e4f7a12a"],
        @"ota_installer_progress.bin":@[@5616,@"6fd65d296a667e1a7d94ec129adfd26458a4008ef403b331f855192c36eb3e3f"],
        @"pil_algo_up_demo_nand.dll":@[@504388,@"e266726fe055ac6ec6f785a9440e8da7421402f2b4d3d7889039ad9b94e119c2"],
        @"pil_algo_vad_demo.dll":@[@433432,@"7ac5b5191202adea20c62642987fa0049024dde9c386ba6cd08a1f29ddd5c92c"],
        @"pil_algo_wakeup_dll_nand.dll":@[@287560,@"d1594cb8658b228e52c2606d02f1eab696d35a11ed42ddcb725e76a745f5550f"],
        @"rives.bin":@[@689431,@"836bc019f7152890b94cafafe2edaa024f317526318349f7833319e41158b104"],
        @"smf.json":@[@23510,@"2713dc3a302a65c101fa981500cd8b217766c526b6045bf02db5e9e6763d076d"]};
    return @{
        @"OtaFileInfo.json":@[@2515,@"21bd0f08234dfdefcad9cea63b8f2ef12cea542a9acc47de1bd832abfc910c24"],
        @"cb_fw_venus.bin":@[@114592,@"8799f12071bdac082218e3601c24ab0989275fc2f7db74e37b8314a225c2cf7d"],
        @"fac_test_img.bin":@[@1821552,@"18eb0901c3e0daeae48dd5f015252b6931ea7368f0160c2c985c4e74296d17eb"],
        @"images.bin":@[@324283,@"192fefaa70545856884c89a9186e3f86d8f99a0738b201e116a11bc63011c158"],
        @"lotties.bin":@[@651481,@"ad66d83a3394034f825a12769aad292fc03e59fa865fe06bc43536b918a0b32b"],
        @"nuttx_ap.bin":@[@9558216,@"40b08299d66b08a909c9167400f2f660b17904d6b20026477ac470e860942a24"],
        @"nuttx_apc1.bin":@[@1420248,@"97d56ffc6dd575ad3d8bf7739d49e491ad7e4a959db8770b653f5302e171fb5c"],
        @"nuttx_audio.bin":@[@1461920,@"549a72c032595e3829da7d63b7e1fd13cceda1a55dfefa7a7cad02db5a9b42ab"],
        @"nuttx_bth.bin":@[@1160160,@"a8f4594868bffbd3bc08a38d1f3899571608e2d57869d147de3d06f3e4f7a12a"],
        @"ota_installer_progress.bin":@[@5616,@"6fd65d296a667e1a7d94ec129adfd26458a4008ef403b331f855192c36eb3e3f"],
        @"pil_algo_up_demo_nand.dll":@[@504388,@"e266726fe055ac6ec6f785a9440e8da7421402f2b4d3d7889039ad9b94e119c2"],
        @"pil_algo_vad_demo.dll":@[@433432,@"7ac5b5191202adea20c62642987fa0049024dde9c386ba6cd08a1f29ddd5c92c"],
        @"pil_algo_wakeup_dll_nand.dll":@[@287560,@"d1594cb8658b228e52c2606d02f1eab696d35a11ed42ddcb725e76a745f5550f"],
        @"rives.bin":@[@689431,@"836bc019f7152890b94cafafe2edaa024f317526318349f7833319e41158b104"],
        @"smf.json":@[@23510,@"2713dc3a302a65c101fa981500cd8b217766c526b6045bf02db5e9e6763d076d"]};
}
NSDictionary *TIOExperimentalOTAProfile(NSString *code){
    if(![code isKindOfClass:NSString.class]||![TIOExperimentalOTAProfiles() containsObject:code])return nil;
    BOOL workout=[code isEqual:@"TWK1"],cards=[code isEqual:@"TCC1"];
    return @{@"code":code,@"name":workout?@"Turbo IO 运动看板 · 首页菜单版 TWK1":cards?@"Turbo IO 提词卡 TCC1":@"Turbo IO FOCUS-04 TFP1",
      @"title":workout?@"眼镜运动看板固件 · TWK1":cards?@"眼镜提词卡固件 · TCC1":@"眼镜导航固件 · FOCUS-04",
      @"resource":workout?@"TurboWorkoutCandidate":cards?@"TurboCueCardsCandidate":@"TurboWeReadCandidate",
      @"bytes":@(workout?TIO_WORKOUT_ARCHIVE_BYTES:cards?9301557u:9300112u),
      @"sha256":workout?TIO_WORKOUT_ARCHIVE_SHA:cards?@"2b1d618b5727fc859bb135f9b689253dbd85bfca0e163fce57f4a23f3040ef82":@"ad5054e3d7bda90e94d293bea882bd8dd5a125bcc8f42c13a59b2e149313c9e3",
      @"pins":PinsForProfile(code)};
}
NSURL *TIOExperimentalOTAStoreDirectory(NSString *code){
    NSString *safe=TIOExperimentalOTAProfile(code)?code:@"INVALID";
    return [NSURL fileURLWithPath:[[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/TurboIOPrivateAddon/ExperimentalOTA"] stringByAppendingPathComponent:safe] isDirectory:YES];
}
BOOL TIOExperimentalOTAAcquireProfile(NSString *code,NSError **error){
    @synchronized(NSProcessInfo.processInfo){
        if(!TIOExperimentalOTAProfile(code)||(ProfileUsers&&![TIOExperimentalOTAProfileCode() isEqual:code])){
            if(error)*error=[NSError errorWithDomain:@"TurboIO.ExperimentalOTA" code:3 userInfo:@{NSLocalizedDescriptionKey:@"另一份固件正在下载或已获授权。请先关闭其下载、撤销未开始的授权；安装开始后请等它完成。"}];return NO;
        }
        SelectedProfile=[code copy];ProfileUsers++;return YES;
    }
}
void TIOExperimentalOTAReleaseProfile(NSString *code){@synchronized(NSProcessInfo.processInfo){if(ProfileUsers&&[SelectedProfile isEqual:code])ProfileUsers--;}}
NSString *TIOExperimentalOTAProfileName(void){return TIOExperimentalOTAProfile(TIOExperimentalOTAProfileCode())[@"name"];}
NSUInteger TIOExperimentalOTAArchiveBytes(void){return [TIOExperimentalOTAProfile(TIOExperimentalOTAProfileCode())[@"bytes"] unsignedIntegerValue];}
NSString *TIOExperimentalOTASHA(void){return TIOExperimentalOTAProfile(TIOExperimentalOTAProfileCode())[@"sha256"];}
NSDictionary *TIOExperimentalOTAPayloadPins(void){return TIOExperimentalOTAProfile(TIOExperimentalOTAProfileCode())[@"pins"];}
static id Fail(NSError **error,NSString *message){if(error)*error=[NSError errorWithDomain:@"TurboIO.ExperimentalOTA" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];return nil;}
NSDictionary *TIOCheckExperimentalOTAForProfile(NSData *data,NSString *code,NSError **error){
    NSDictionary *profile=TIOExperimentalOTAProfile(code);if(!profile)return Fail(error,@"未知固件类型，未发送。");
    if(data.length!=[profile[@"bytes"] unsignedIntegerValue])return Fail(error,[NSString stringWithFormat:@"文件大小不符。只接受本次 %@ 实验 ZIP，未保存、未发送。",code]);
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,digest);
    NSMutableString *hex=[NSMutableString new];for(NSUInteger i=0;i<sizeof(digest);i++)[hex appendFormat:@"%02x",digest[i]];
    if(![hex isEqual:profile[@"sha256"]])return Fail(error,@"SHA-256 不匹配。拒绝未知、旧版或已修改的包，未发送。");
    // The exact archive has independently passed full ZIP/manifest/AP auditing
    // on Mac. This is exact-byte identity, not a generic ZIP manifest parser.
    return @{@"schema":@1,@"candidate":profile[@"name"],@"profile":code,@"baseFirmware":@"1.0.4.12",
             @"archiveSHA256":hex,@"archiveBytes":@(data.length),@"changedPayloads":@[@"nuttx_ap.bin"],
             @"unchangedPayloadCount":@13,@"integrityPassed":@YES,@"sent":@NO,
             @"runtimeValidated":@NO,@"officialDispatchConnected":@NO};
}
static NSData *Read(NSURL *source,NSString *code,NSError **error){
    NSDictionary *profile=TIOExperimentalOTAProfile(code);if(!profile)return Fail(error,@"未知固件类型，未读取。");
    if(!source.isFileURL)return Fail(error,@"只接受本地文件。");
    NSInputStream *stream=[NSInputStream inputStreamWithURL:source];[stream open];
    NSMutableData *data=[NSMutableData new];uint8_t buffer[65536];NSInteger n;
    while((n=[stream read:buffer maxLength:sizeof(buffer)])>0){
        if(data.length+(NSUInteger)n>[profile[@"bytes"] unsignedIntegerValue]){[stream close];return Fail(error,@"文件过大；未保存、未发送。");}
        [data appendBytes:buffer length:(NSUInteger)n];
    }
    NSError *readError=stream.streamError;[stream close];
    if(n<0||readError){if(error)*error=readError?:[NSError errorWithDomain:@"TurboIO.ExperimentalOTA" code:2 userInfo:@{NSLocalizedDescriptionKey:@"无法读取文件"}];return nil;}
    return TIOCheckExperimentalOTAForProfile(data,code,error)?data:nil;
}
NSDictionary *TIOReadExperimentalOTAForProfile(NSURL *file,NSString *code,NSError **error){NSData *data=Read(file,code,error);return data?TIOCheckExperimentalOTAForProfile(data,code,error):nil;}
NSDictionary *TIOImportExperimentalOTAForProfile(NSURL *source,NSURL *directory,NSString *code,NSError **error){
    NSDictionary *profile=TIOExperimentalOTAProfile(code);if(!profile)return Fail(error,@"未知固件类型，未保存。");
    if(!directory.isFileURL)return Fail(error,@"只接受本地目录。");
    NSData *data=Read(source,code,error);if(!data)return nil;
    NSDictionary *result=TIOCheckExperimentalOTAForProfile(data,code,error);
    NSFileManager *fm=NSFileManager.defaultManager;
    if(![fm createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:error])return nil;
    if(![directory setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:error])return nil;
    NSURL *destination=[directory URLByAppendingPathComponent:[profile[@"sha256"] stringByAppendingString:@".zip"]];
    if([fm fileExistsAtPath:destination.path]){
        if(!TIOReadExperimentalOTAForProfile(destination,code,error))return nil;
    }else{
        // Exclusive creation; no official cache or existing imported file replaced.
        if(![data writeToURL:destination options:NSDataWritingWithoutOverwriting error:error])return nil;
    }
    if(![fm setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:destination.path error:error])return nil;
#if TARGET_OS_IPHONE
    if(![fm setAttributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} ofItemAtPath:destination.path error:error])return nil;
#endif
    return result;
}

static BOOL SameStat(struct stat a,struct stat b){return a.st_dev==b.st_dev&&a.st_ino==b.st_ino&&a.st_size==b.st_size&&a.st_mode==b.st_mode&&a.st_nlink==b.st_nlink&&a.st_mtimespec.tv_sec==b.st_mtimespec.tv_sec&&a.st_mtimespec.tv_nsec==b.st_mtimespec.tv_nsec&&a.st_ctimespec.tv_sec==b.st_ctimespec.tv_sec&&a.st_ctimespec.tv_nsec==b.st_ctimespec.tv_nsec;}
NSDictionary<NSString *,NSData *> *TIOCopyExperimentalOTAPayloadsForProfile(NSURL *directory,NSString *code,NSError **error){
    NSDictionary *profile=TIOExperimentalOTAProfile(code);if(!profile)return Fail(error,@"未知固件类型，未授权。");
    if(!TIOCheckExperimentalOTADirectoryForProfile(directory,code,error))return nil;
    NSMutableDictionary *copy=[NSMutableDictionary new];NSDictionary *pins=profile[@"pins"];
    for(NSString *name in pins){
        NSData *data=[NSData dataWithContentsOfURL:[directory URLByAppendingPathComponent:name] options:0 error:error];
        if(!data||data.length!=[pins[name][0] unsignedIntegerValue])return Fail(error,@"待传文件在冻结时改变；未授权发送。");
        uint8_t digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,digest);
        NSMutableString *hex=[NSMutableString new];for(NSUInteger i=0;i<sizeof(digest);i++)[hex appendFormat:@"%02x",digest[i]];
        if(![hex isEqual:pins[name][1]])return Fail(error,@"待传文件在冻结时摘要不符；未授权发送。");
        copy[name]=data;
    }
    return TIOCheckExperimentalOTADirectoryForProfile(directory,code,error)?[copy copy]:nil;
}
NSDictionary *TIOCheckExperimentalOTADirectoryForProfile(NSURL *directory,NSString *code,NSError **error){
    NSDictionary *profile=TIOExperimentalOTAProfile(code);if(!profile)return Fail(error,@"未知固件类型，未核对。");
    if(!directory.isFileURL)return Fail(error,@"只接受本地待传目录。");
    // Open a directory handle and use openat/O_NOFOLLOW for every member. Never
    // follow a member symlink, FIFO or device. Do not modify old OTA caches.
    int root=open(directory.path.fileSystemRepresentation,O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC);
    if(root<0)return Fail(error,@"待传目录不存在、不可读或为符号链接；未发送。");
    struct stat before,after;BOOL ok=fstat(root,&before)==0;NSDictionary *pins=profile[@"pins"];NSMutableSet *names=[NSMutableSet new];
    int copy=dup(root);DIR *stream=copy>=0?fdopendir(copy):NULL;if(!stream){if(copy>=0)close(copy);ok=NO;}
    if(stream){struct dirent *item;errno=0;while((item=readdir(stream))){if(!strcmp(item->d_name,".")||!strcmp(item->d_name,".."))continue;NSString *name=[NSString stringWithUTF8String:item->d_name];if(!name||names.count>=15||!pins[name]){ok=NO;break;}[names addObject:name];errno=0;}if(errno)ok=NO;closedir(stream);}
    if(names.count!=pins.count)ok=NO;
    NSMutableDictionary *identities=[NSMutableDictionary new];NSString *problem=[NSString stringWithFormat:@"文件集合与 %@ 不符，可能是旧缓存或残缺目录；未发送。",code];
    for(NSString *name in [pins.allKeys sortedArrayUsingSelector:@selector(compare:)]){
        if(!ok)break;
        int fd=openat(root,name.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW|O_NONBLOCK|O_CLOEXEC);
        if(fd<0){ok=NO;break;}struct stat first,last;
        NSUInteger expected=[pins[name][0] unsignedIntegerValue];
        ok=fstat(fd,&first)==0&&S_ISREG(first.st_mode)&&first.st_nlink==1&&first.st_size==(off_t)expected;
        if(ok){CC_SHA256_CTX context;CC_SHA256_Init(&context);uint8_t buffer[65536],digest[CC_SHA256_DIGEST_LENGTH];NSUInteger total=0;ssize_t n=0;
            while(total<expected){n=read(fd,buffer,MIN(sizeof(buffer),expected-total));if(n<0&&errno==EINTR)continue;if(n<=0){ok=NO;break;}CC_SHA256_Update(&context,buffer,(CC_LONG)n);total+=(NSUInteger)n;}
            if(ok){n=read(fd,buffer,1);ok=n==0;}CC_SHA256_Final(digest,&context);
            NSMutableString *hash=[NSMutableString new];for(NSUInteger i=0;i<sizeof(digest);i++)[hash appendFormat:@"%02x",digest[i]];
            ok=ok&&[hash isEqual:pins[name][1]]&&fstat(fd,&last)==0&&SameStat(first,last);
            if(ok)identities[name]=[NSData dataWithBytes:&last length:sizeof(last)];
        }
        close(fd);if(!ok)problem=[NSString stringWithFormat:@"%@ 与固定 %@ 不一致或读取期间改变；未发送。",name,code];
    }
    // A second pass catches names/inodes replaced after an earlier file was read.
    for(NSString *name in identities){struct stat prior,current;[identities[name] getBytes:&prior length:sizeof(prior)];if(fstatat(root,name.fileSystemRepresentation,&current,AT_SYMLINK_NOFOLLOW)||!SameStat(prior,current))ok=NO;}
    ok=ok&&fstat(root,&after)==0&&SameStat(before,after);
    struct stat currentPath;if(lstat(directory.path.fileSystemRepresentation,&currentPath)||!SameStat(before,currentPath))ok=NO;
    close(root);if(!ok)return Fail(error,problem);
    return @{@"candidate":profile[@"name"],@"profile":code,@"checkedMembers":@15,@"integrityPassed":@YES,@"snapshotOnly":@YES,@"transferSessionBound":@NO,@"sent":@NO,@"flashAuthorized":@NO};
}

NSDictionary *TIOCheckExperimentalOTA(NSData *data,NSError **error){return TIOCheckExperimentalOTAForProfile(data,TIOExperimentalOTAProfileCode(),error);}
NSDictionary *TIOReadExperimentalOTA(NSURL *file,NSError **error){return TIOReadExperimentalOTAForProfile(file,TIOExperimentalOTAProfileCode(),error);}
NSDictionary *TIOImportExperimentalOTA(NSURL *source,NSURL *dir,NSError **error){return TIOImportExperimentalOTAForProfile(source,dir,TIOExperimentalOTAProfileCode(),error);}
NSDictionary *TIOCheckExperimentalOTADirectory(NSURL *dir,NSError **error){return TIOCheckExperimentalOTADirectoryForProfile(dir,TIOExperimentalOTAProfileCode(),error);}
NSDictionary *TIOCopyExperimentalOTAPayloads(NSURL *dir,NSError **error){return TIOCopyExperimentalOTAPayloadsForProfile(dir,TIOExperimentalOTAProfileCode(),error);}

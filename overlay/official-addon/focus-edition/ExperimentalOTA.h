#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// Profile-specific verification never changes the current upgrade selection.
FOUNDATION_EXPORT NSArray<NSString *> *TIOExperimentalOTAProfiles(void);
FOUNDATION_EXPORT NSDictionary * _Nullable TIOExperimentalOTAProfile(NSString *code);
FOUNDATION_EXPORT NSURL *TIOExperimentalOTAStoreDirectory(NSString *code);
FOUNDATION_EXPORT BOOL TIOExperimentalOTAAcquireProfile(NSString *code,NSError **error);
FOUNDATION_EXPORT void TIOExperimentalOTAReleaseProfile(NSString *code);
FOUNDATION_EXPORT NSDictionary * _Nullable TIOCheckExperimentalOTAForProfile(NSData *data,NSString *code,NSError **error);
FOUNDATION_EXPORT NSDictionary * _Nullable TIOReadExperimentalOTAForProfile(NSURL *file,NSString *code,NSError **error);
FOUNDATION_EXPORT NSDictionary * _Nullable TIOImportExperimentalOTAForProfile(NSURL *source,NSURL *directory,NSString *code,NSError **error);
FOUNDATION_EXPORT NSDictionary * _Nullable TIOCheckExperimentalOTADirectoryForProfile(NSURL *directory,NSString *code,NSError **error);
FOUNDATION_EXPORT NSDictionary<NSString *,NSData *> * _Nullable TIOCopyExperimentalOTAPayloadsForProfile(NSURL *directory,NSString *code,NSError **error);
// Immutable verified payloads for a single explicitly authorized transfer.
NSDictionary<NSString *,NSData *> * _Nullable TIOCopyExperimentalOTAPayloads(NSURL *directory,NSError **error);
// Exact-byte profiles. Integrity approval never means authorization to flash.
FOUNDATION_EXPORT BOOL TIOCueCardsOTABuild(void);
FOUNDATION_EXPORT BOOL TIOWorkoutOTABuild(void);
FOUNDATION_EXPORT NSString *TIOExperimentalOTAProfileCode(void);
FOUNDATION_EXPORT NSString *TIOExperimentalOTAProfileName(void);
FOUNDATION_EXPORT NSUInteger TIOExperimentalOTAArchiveBytes(void);
FOUNDATION_EXPORT NSString *TIOExperimentalOTASHA(void);
FOUNDATION_EXPORT NSDictionary<NSString *,NSArray *> *TIOExperimentalOTAPayloadPins(void);
FOUNDATION_EXPORT NSDictionary * _Nullable TIOCheckExperimentalOTA(NSData *data, NSError **error);
FOUNDATION_EXPORT NSDictionary * _Nullable TIOReadExperimentalOTA(NSURL *file, NSError **error);
FOUNDATION_EXPORT NSDictionary * _Nullable TIOImportExperimentalOTA(NSURL *source, NSURL *directory, NSError **error);
// Point-in-time read-only snapshot, NOT a frozen transfer session or flash approval.
FOUNDATION_EXPORT NSDictionary * _Nullable TIOCheckExperimentalOTADirectory(NSURL *directory, NSError **error);
NS_ASSUME_NONNULL_END

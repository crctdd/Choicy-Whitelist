#import <Foundation/Foundation.h>
@class CHPTweakInfo;
enum { CHWLProcessCacheSchemaVersion = 4 };
enum { CHWLProcessBundleIdentifierVersion = 1 };
NSArray<NSDictionary *> *CHWLSortedRows(NSArray<NSDictionary *> *rows);
NSArray<NSDictionary *> *CHWLValidatedRecords(id cache, NSDictionary *context);
NSArray<NSDictionary *> *CHWLRecordsByResolvingBundleIdentifiers(NSArray<NSDictionary *> *records,
    NSString *(^resolve)(NSString *path));
NSString *CHWLConfigurationSummary(BOOL injectionEnabled, BOOL privilegeEligible, NSDictionary *processPreferences);
BOOL CHWLPrivilegesDisabled(BOOL injectionEnabled, BOOL privilegeEligible, NSDictionary *processPreferences);
NSDictionary *CHWLProcessPreferencesBySetting(NSDictionary *settings, NSString *key, id value);
NSArray<NSString *> *CHWLPrivilegedTweakNames(NSDictionary *preferences);
BOOL CHWLIsPrivilegedTweak(NSDictionary *preferences, NSString *name, BOOL isUIKit);
NSArray *CHWLPrivilegeCandidates(NSArray *tweaks);
NSArray *CHWLConfigurationCandidates(NSArray *tweaks, NSDictionary *preferences,
    BOOL privilegeEligible, BOOL privilegedPage);
BOOL CHWLCustomConfigurationAvailable(BOOL privilegedPage, BOOL injectionEnabled,
    BOOL privilegeEligible, NSDictionary *settings);
BOOL CHWLCustomConfigurationActive(BOOL privilegedPage, BOOL injectionEnabled,
    BOOL privilegeEligible, NSDictionary *settings);
NSDictionary *CHWLInitializePrivilegedConfiguration(NSDictionary *settings, NSArray<NSString *> *names);
NSArray *CHWLMatchingConfigurationTweaks(NSArray *tweaks, NSString *identifier,
    NSString *executableName, NSSet *frameworks);
NSArray<NSString *> *CHWLMatchReasons(CHPTweakInfo *tweak, NSString *identifier,
    NSString *executableName, NSSet *frameworks);
NSDictionary *CHWLCustomCandidateGroups(NSArray *tweaks, NSArray *matches, NSDictionary *preferences,
    BOOL privilegeEligible, NSDictionary *settings);

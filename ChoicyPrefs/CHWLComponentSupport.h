#import <Foundation/Foundation.h>

NSDictionary *CHWLComponentRecord(NSString *bundlePath);
NSArray<NSDictionary *> *CHWLMergeExtensionRecords(NSArray<NSDictionary *> *preferred,
    NSArray<NSDictionary *> *additional);
NSArray<NSDictionary *> *CHWLValidatedExtensionRecords(id records);
NSArray<NSDictionary *> *CHWLValidatedApplicationExtensionRecords(id records);
NSDictionary *CHWLApplicationExtensionCacheEntry(NSArray *records, NSDictionary *context);
NSArray<NSDictionary *> *CHWLRestoreApplicationExtensions(id entry, NSDictionary *context);
NSDictionary *CHWLScanSystemComponents(NSArray<NSString *> *directories);
NSArray<NSString *> *CHWLSystemComponentDirectories(void);

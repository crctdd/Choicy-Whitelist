#import "CHWLComponentSupport.h"

NSDictionary *CHWLComponentRecord(NSString *bundlePath)
{
    if (!bundlePath.isAbsolutePath || ![@[@"appex", @"xpc"] containsObject:bundlePath.pathExtension]) return nil;
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[bundlePath stringByAppendingPathComponent:@"Info.plist"]];
    id identifier = info[@"CFBundleIdentifier"], executable = info[@"CFBundleExecutable"];
    if (![identifier isKindOfClass:NSString.class] || ![identifier length] ||
        ![executable isKindOfClass:NSString.class] || ![executable length] ||
        ![executable isEqual:[executable lastPathComponent]] || [executable isEqual:@".."] ||
        [executable isEqual:@"."]) return nil;
    NSString *path = [bundlePath stringByAppendingPathComponent:executable];
    BOOL isDirectory = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] || isDirectory ||
        ![NSFileManager.defaultManager isExecutableFileAtPath:path]) return nil;
    id name = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"];
    if (![name isKindOfClass:NSString.class] || ![name length]) name = executable;
    return @{@"bundleIdentifier": identifier, @"executablePath": path,
        @"name": name, @"kind": bundlePath.pathExtension};
}

static NSArray<NSDictionary *> *CHWLValidateExtensionRecords(id records, BOOL allowRegistered)
{
    if (![records isKindOfClass:NSArray.class] || [records count] > 20000) return nil;
    NSMutableSet *identifiers = [NSMutableSet new], *paths = [NSMutableSet new];
    for (id record in records) {
        if (![record isKindOfClass:NSDictionary.class]) return nil;
        id identifier = record[@"bundleIdentifier"], path = record[@"executablePath"], name = record[@"name"];
        if (![identifier isKindOfClass:NSString.class] || ![identifier length] || [identifier length] > 1024 ||
            ![path isKindOfClass:NSString.class] || ![path isAbsolutePath] || [path length] > 4096 ||
            ![name isKindOfClass:NSString.class] || ![name length] || [name length] > 1024 ||
            [identifiers containsObject:identifier] || [paths containsObject:path]) return nil;
        BOOL appex = [record[@"kind"] isEqual:@"appex"] &&
            [[path stringByDeletingLastPathComponent].pathExtension isEqual:@"appex"];
        if (!appex && !(allowRegistered && [record[@"kind"] isEqual:@"registered"])) return nil;
        [identifiers addObject:identifier]; [paths addObject:path];
    }
    return records;
}

NSArray<NSDictionary *> *CHWLValidatedExtensionRecords(id records)
{
    return CHWLValidateExtensionRecords(records, NO);
}

NSArray<NSDictionary *> *CHWLValidatedApplicationExtensionRecords(id records)
{
    return CHWLValidateExtensionRecords(records, YES);
}

NSDictionary *CHWLApplicationExtensionCacheEntry(NSArray *records, NSDictionary *context)
{
    if (![context isKindOfClass:NSDictionary.class] || !context.count ||
        !CHWLValidatedApplicationExtensionRecords(records)) return nil;
    return @{@"version": @1, @"context": context.copy, @"records": records.copy};
}

NSArray<NSDictionary *> *CHWLRestoreApplicationExtensions(id entry, NSDictionary *context)
{
    if (![entry isKindOfClass:NSDictionary.class] || ![entry[@"version"] isEqual:@1] ||
        ![context isKindOfClass:NSDictionary.class] || !context.count || ![entry[@"context"] isEqual:context]) return nil;
    return CHWLValidatedApplicationExtensionRecords(entry[@"records"]);
}

NSArray<NSDictionary *> *CHWLMergeExtensionRecords(NSArray<NSDictionary *> *preferred, NSArray<NSDictionary *> *additional)
{
    NSMutableArray *result = [NSMutableArray new];
    NSMutableSet *identifiers = [NSMutableSet new], *paths = [NSMutableSet new];
    for (NSArray *source in @[preferred ?: @[], additional ?: @[]]) {
        for (NSDictionary *record in source) {
            if (!CHWLValidatedApplicationExtensionRecords(@[record])) continue;
            NSString *identifier = record[@"bundleIdentifier"];
            NSString *path = [record[@"executablePath"] stringByResolvingSymlinksInPath];
            if ([identifiers containsObject:identifier] || [paths containsObject:path]) continue;
            [identifiers addObject:identifier]; [paths addObject:path]; [result addObject:record];
        }
    }
    return result.copy;
}

NSArray<NSString *> *CHWLSystemComponentDirectories(void)
{
    return @[@"/System/Library/Frameworks", @"/System/Library/PrivateFrameworks",
        @"/private/preboot/Cryptexes/OS/System/Library/Frameworks",
        @"/private/preboot/Cryptexes/OS/System/Library/PrivateFrameworks"];
}

NSDictionary *CHWLScanSystemComponents(NSArray<NSString *> *directories)
{
    NSMutableArray *extensions = [NSMutableArray new], *services = [NSMutableArray new];
    NSMutableSet *visited = [NSMutableSet new];
    __block BOOL complete = YES;
    BOOL foundDirectory = NO;
    for (NSString *directory in directories) {
        BOOL isDirectory = NO;
        if (![NSFileManager.defaultManager fileExistsAtPath:directory isDirectory:&isDirectory] || !isDirectory) continue;
        foundDirectory = YES;
        NSDirectoryEnumerator *enumerator = [NSFileManager.defaultManager enumeratorAtURL:
            [NSURL fileURLWithPath:directory isDirectory:YES] includingPropertiesForKeys:nil
            options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^BOOL(NSURL *url, NSError *error) {
                (void)url; (void)error; complete = NO; return YES;
            }];
        if (!enumerator) complete = NO;
        for (NSURL *url in enumerator) {
            if (![@[@"appex", @"xpc"] containsObject:url.pathExtension]) continue;
            NSString *canonical = url.URLByResolvingSymlinksInPath.path;
            if ([visited containsObject:canonical]) continue;
            [visited addObject:canonical];
            NSDictionary *record = CHWLComponentRecord(url.path);
            if (record) [( [url.pathExtension isEqual:@"appex"] ? extensions : services) addObject:record];
        }
    }
    return @{@"extensions": CHWLMergeExtensionRecords(extensions, @[]), @"services": services.copy,
        @"complete": @(complete && foundDirectory)};
}

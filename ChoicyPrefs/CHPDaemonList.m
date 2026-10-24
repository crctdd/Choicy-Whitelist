// Copyright (c) 2019-2021 Lars Fröder

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#import "CHPDaemonList.h"
#import "CHPDaemonInfo.h"
#import "CHPTweakList.h"
#import "../Shared.h"
#import "../HBLogWeak.h"
#import <roothide.h>

#import <dirent.h>
#import "CHWLData.h"
#import "CHWLFrameworkSupport.h"
#import "CHWLExecutableInfo.h"
#import "CHWLComponentSupport.h"
#import "CHWLExtensionRegistry.h"
#import "CHWLListSupport.h"
#import "CHWLProcessOrigin.h"
#import <MobileCoreServices/LSApplicationWorkspace.h>

NSString *const CHWLApplicationExtensionsChanged = @"CHWLApplicationExtensionsChanged";

@interface LSApplicationWorkspace (CHWLExtensionChanges)
- (void)addObserver:(id)observer;
@end
#import <sys/sysctl.h>

@interface CHPDaemonList ()
@property (nonatomic) NSRecursiveLock *scanLock;
@property (atomic, readwrite) BOOL loaded;
@property (atomic, readwrite) BOOL loading;
@property (atomic, readwrite) NSArray *daemonList;
@property (atomic, readwrite) NSArray<NSDictionary *> *extensionList;
@property (atomic, readwrite) NSArray<NSDictionary *> *applicationExtensions;
@property (nonatomic) NSDictionary *applicationExtensionEntry;
@property (nonatomic) BOOL applicationExtensionsInvalidated;
- (NSDictionary *)applicationExtensionContext;
@property (nonatomic) NSDictionary *loadedContext;
@property (nonatomic) BOOL componentCatalogComplete;
@property (nonatomic) BOOL catalogScanAttempted;
- (void)mergeComponentScan:(NSDictionary *)components intoDaemons:(NSMutableArray *)daemons;
@property (nonatomic) NSMutableDictionary *frameworkMatches;
@property (nonatomic) BOOL bundleIdentifiersComplete;
- (void)completeBundleIdentifiers;
@property (nonatomic) BOOL processOriginsComplete;
- (NSArray<NSString *> *)launchDaemonDirectories;
- (NSString *)executablePathForLaunchDaemon:(NSDictionary *)dictionary source:(NSString *)source;
- (void)completeProcessOrigins;
@end

@implementation CHPDaemonList

+ (instancetype)sharedInstance
{
	static CHPDaemonList *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^ {
		                     
		sharedInstance = [[CHPDaemonList alloc] init];
	});
	return sharedInstance;
}

- (instancetype)init
{
	self = [super init];

	_observers = [NSHashTable weakObjectsHashTable];
    _scanLock = [NSRecursiveLock new];
    _frameworkMatches = [NSMutableDictionary new];
    _extensionList = @[];
    [[LSApplicationWorkspace defaultWorkspace] addObserver:self];

	return self;
}

- (BOOL)daemonList:(NSArray *)daemonList containsExecutableName:(NSString *)executableName
{
	for (CHPDaemonInfo *info in daemonList) {
		if ([info.executableName isEqualToString:executableName]) {
			return YES;
		}
	}

	return NO;
}

- (NSDictionary *)cacheContext
{
    char build[128] = {0};
    size_t size = sizeof(build);
    if (sysctlbyname("kern.osversion", build, &size, NULL, 0) != 0) return nil;
    NSString *cachePath = kChoicyProcessCachePath;
    if (!cachePath) return nil;
    NSMutableDictionary *sources = [NSMutableDictionary new];
    NSMutableArray *directories = [CHWLSystemComponentDirectories() mutableCopy];
    [directories addObjectsFromArray:[self launchDaemonDirectories]];
    for (NSString *directory in directories) {
        NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:directory error:nil];
        if (attributes) sources[directory] = @[attributes[NSFileModificationDate] ?: NSDate.distantPast];
        if (![directory.lastPathComponent hasSuffix:@"LaunchDaemons"]) continue;
        for (NSString *file in [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil]) {
            if (![file.pathExtension isEqual:@"plist"]) continue;
            NSString *source = [directory stringByAppendingPathComponent:file];
            NSDictionary *attrs = [NSFileManager.defaultManager attributesOfItemAtPath:source error:nil];
            if (attrs) sources[source] = @[attrs[NSFileSize] ?: @0, attrs[NSFileModificationDate] ?: NSDate.distantPast];
        }
    }
    return @{@"osBuild": [NSString stringWithUTF8String:build], @"componentCatalogVersion": @1,
        @"sources": sources.copy, @"preferencesDirectory": cachePath.stringByDeletingLastPathComponent};
}
- (BOOL)restoreCache
{
    NSDictionary *context = [self cacheContext];
    NSString *path = kChoicyProcessCachePath;
    if (!context || !path) return NO;
    NSNumber *size = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil][NSFileSize];
    if (!size || size.unsignedLongLongValue > 8 * 1024 * 1024) return NO;
    NSData *data = [NSData dataWithContentsOfFile:path];
    id cache = data ? [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:nil] : nil;
    if (![cache isKindOfClass:NSDictionary.class]) return NO;
    NSArray *records = CHWLValidatedRecords(cache, context);
    NSArray *extensions = CHWLValidatedExtensionRecords([cache objectForKey:@"extensions"]);
    if (!records || !extensions) return NO;
    id frameworkMatches = [cache objectForKey:@"frameworkMatches"];
    self.frameworkMatches = [frameworkMatches isKindOfClass:NSDictionary.class] ? [frameworkMatches mutableCopy] : [NSMutableDictionary new];
    NSMutableArray *list = [NSMutableArray new];
    for (NSDictionary *record in records) {
        CHPDaemonInfo *info = [CHPDaemonInfo new];
        info.executablePath = record[@"executablePath"];
        info.plistIdentifier = record[@"plistIdentifier"];
        info.bundleIdentifier = record[@"bundleIdentifier"];
        info.launchDaemonPath = record[@"launchDaemonPath"];
        info.thirdPartyProcess = [record[@"thirdPartyProcess"] boolValue];
        [list addObject:info];
    }
    self.daemonList = list.copy;
    self.extensionList = extensions;
    self.loadedContext = context;
    self.applicationExtensionEntry = [cache[@"applicationExtensionPage"] isKindOfClass:NSDictionary.class] ? cache[@"applicationExtensionPage"] : nil;
    NSArray *page = CHWLRestoreApplicationExtensions(self.applicationExtensionEntry, [self applicationExtensionContext]);
    if (page) self.applicationExtensions = page;
    self.componentCatalogComplete = [cache[@"componentCatalogComplete"] boolValue];
    self.catalogScanAttempted = NO;
    self.bundleIdentifiersComplete = [cache[@"bundleIdentifierVersion"] isEqual:@(CHWLProcessBundleIdentifierVersion)];
    self.processOriginsComplete = CHWLProcessOriginsAreCurrent(cache);
    self.loaded = YES;
    self.loading = NO;
    return YES;
}
- (void)saveCache
{
    NSDictionary *context = self.loadedContext ?: [self cacheContext];
    NSString *path = kChoicyProcessCachePath;
    if (!context || !path || !_loaded || _loading || !_daemonList.count) return;
    NSMutableArray *records = [NSMutableArray new];
    for (CHPDaemonInfo *info in _daemonList) {
        NSMutableDictionary *record = [@{@"executablePath": info.executablePath} mutableCopy];
        if (info.plistIdentifier.length) record[@"plistIdentifier"] = info.plistIdentifier;
        if (info.bundleIdentifier.length) record[@"bundleIdentifier"] = info.bundleIdentifier;
        if (info.launchDaemonPath.length) record[@"launchDaemonPath"] = info.launchDaemonPath;
        record[@"thirdPartyProcess"] = @(info.thirdPartyProcess);
        [records addObject:record];
    }
    NSMutableDictionary *cache = [@{@"schemaVersion": @(CHWLProcessCacheSchemaVersion), @"scanComplete": @YES, @"context": context,
        @"processes": records, @"extensions": self.extensionList ?: @[], @"frameworkMatches": self.frameworkMatches.copy,
        @"componentCatalogComplete": @(self.componentCatalogComplete),
        @"bundleIdentifierVersion": @(self.bundleIdentifiersComplete ? CHWLProcessBundleIdentifierVersion : 0),
        @"processOriginVersion": @(self.processOriginsComplete ? CHWLProcessOriginVersion : 0)} mutableCopy];
    if (self.applicationExtensionEntry) cache[@"applicationExtensionPage"] = self.applicationExtensionEntry;
    if (!CHWLValidatedRecords(cache, context)) return;
    [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:cache format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    while (data.length > 8 * 1024 * 1024 && self.frameworkMatches.count) {
        NSArray *oldest = [self.frameworkMatches.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
            id first = self.frameworkMatches[a][@"cachedAt"], second = self.frameworkMatches[b][@"cachedAt"];
            NSDate *left = [first isKindOfClass:NSDate.class] ? first : NSDate.distantPast;
            NSDate *right = [second isKindOfClass:NSDate.class] ? second : NSDate.distantPast;
            NSComparisonResult order = [left compare:right];
            return order == NSOrderedSame ? [a compare:b] : order;
        }];
        [self.frameworkMatches removeObjectsForKeys:[oldest subarrayWithRange:NSMakeRange(0, MAX(1, oldest.count / 2))]];
        cache[@"frameworkMatches"] = self.frameworkMatches.copy;
        data = [NSPropertyListSerialization dataWithPropertyList:cache format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    }
    if (data.length <= 8 * 1024 * 1024) [data writeToFile:path options:NSDataWritingAtomic error:nil];
}
- (NSDictionary *)applicationExtensionContext
{
    NSMutableDictionary *sources = [NSMutableDictionary new];
    NSMutableArray *directories = [@[@"/var/containers/Bundle/Application", @"/Applications", @"/System/Applications",
        @"/System/Library/CoreServices"] mutableCopy];
    NSString *jailbreakApplications = jbroot(@"/Applications");
    if (jailbreakApplications.length) [directories addObject:jailbreakApplications];
    for (NSString *directory in directories) {
        NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:directory error:nil];
        sources[directory] = attributes ? @[attributes[NSFileModificationDate] ?: NSDate.distantPast,
            attributes[NSFileSystemFileNumber] ?: @0] : @[];
    }
    return @{@"osBuild": self.loadedContext[@"osBuild"] ?: @"", @"sources": sources.copy,
        @"languages": NSLocale.preferredLanguages, @"locale": NSLocale.currentLocale.localeIdentifier,
        @"preferencesDirectory": kChoicyProcessCachePath.stringByDeletingLastPathComponent ?: @"",
        @"systemExtensions": self.extensionList ?: @[]};
}

- (void)applicationsDidInstall:(id)info
{
    (void)info;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [self.scanLock lock];
        @try {
            self.applicationExtensionEntry = nil;
            self.applicationExtensionsInvalidated = YES;
            self.processOriginsComplete = NO;
        }
        @finally { [self.scanLock unlock]; }
        [CHPTweakList.sharedInstance invalidateAllCandidateAnalyses];
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:CHWLMatchesChanged object:nil];
        });
        [self prepareApplicationExtensionsIfNeeded];
    });
}
- (void)applicationsDidUninstall:(id)info { [self applicationsDidInstall:info]; }

- (void)prepareApplicationExtensionsIfNeeded
{
    [self.scanLock lock];
    @try {
        if (!_loaded && !_loading) [self restoreCache];
        if (self.applicationExtensionsInvalidated) self.applicationExtensionEntry = nil;
        NSDictionary *context = [self applicationExtensionContext];
        NSArray *cached = CHWLRestoreApplicationExtensions(self.applicationExtensionEntry, context);
        if (cached) { self.applicationExtensions = cached; return; }
        [self updateDaemonListIfNeeded];
        context = [self applicationExtensionContext];
        NSArray *registered = CHWLRegisteredExtensionRecords(nil);
        if (!registered) return;
        NSArray *snapshot = CHWLMergeExtensionRecords(registered, self.extensionList);
        BOOL changed = ![self.applicationExtensions isEqual:snapshot];
        self.applicationExtensions = snapshot;
        self.applicationExtensionEntry = [context isEqual:[self applicationExtensionContext]] ?
            CHWLApplicationExtensionCacheEntry(snapshot, context) : nil;
        self.applicationExtensionsInvalidated = self.applicationExtensionEntry == nil;
        [self saveCache];
        if (changed) dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:CHWLApplicationExtensionsChanged object:self];
        });
    } @finally { [self.scanLock unlock]; }
}

- (BOOL)loadCachedDaemonListIfNeeded
{
    if (![self.scanLock tryLock]) return NO;
    BOOL result = NO;
    @try { result = _loaded || (!_loading && [self restoreCache]); }
    @finally { [self.scanLock unlock]; }
    return result;
}
- (NSSet *)cachedFrameworkIdentifiersForPath:(NSString *)path signature:(NSDictionary *)signature
{
                                                                                               
    [self.scanLock lock];
    @try {
        if (!_loaded && !_loading) [self restoreCache];
        NSArray *identifiers = CHWLValidatedFrameworkEntry(self.frameworkMatches[path], signature);
        return identifiers ? [NSSet setWithArray:identifiers] : nil;
    } @finally { [self.scanLock unlock]; }
}
- (void)cacheFrameworkAnalysis:(NSDictionary *)analysis forPath:(NSString *)path signature:(NSDictionary *)signature
{
    NSSet *identifiers = analysis[@"identifiers"];
    if (!path.length || !identifiers || !signature || ![analysis[@"complete"] boolValue] ||
        !CHWLInputSignaturesAreCurrent(analysis[@"inputs"])) return;
    [self.scanLock lock];
    @try {
        self.frameworkMatches[path] = @{@"version": @(CHWLFrameworkCacheEntryVersion), @"signature": signature,
            @"identifiers": [identifiers.allObjects sortedArrayUsingSelector:@selector(compare:)], @"inputs": analysis[@"inputs"],
            @"cachedAt": NSDate.date};
        [self saveCache];
    } @finally { [self.scanLock unlock]; }
}
- (void)invalidateFrameworkIdentifiersForPath:(NSString *)path
{
    if (!path.length) return;
    [self.scanLock lock];
    @try {
        [self.frameworkMatches removeObjectForKey:path];
        [self saveCache];
    } @finally { [self.scanLock unlock]; }
}
- (void)updateDaemonListIfNeeded
{
    [self.scanLock lock];
    @try {
        if (_loading) return;
        BOOL wasLoaded = _loaded;
        if (_loaded && ![self.loadedContext isEqual:[self cacheContext]]) {
            self.loaded = NO;
            [self.frameworkMatches removeAllObjects];
        }
        if (_loaded || [self restoreCache]) {
            BOOL upgraded = !self.bundleIdentifiersComplete;
            if (upgraded) {
                [self completeBundleIdentifiers];
                [self saveCache];
            }
            BOOL retried = !self.componentCatalogComplete && !self.catalogScanAttempted;
            if (retried) {
                NSMutableArray *daemons = self.daemonList.mutableCopy;
                [self mergeComponentScan:CHWLScanSystemComponents(CHWLSystemComponentDirectories()) intoDaemons:daemons];
                self.daemonList = [daemons sortedArrayUsingComparator:^NSComparisonResult(CHPDaemonInfo *a, CHPDaemonInfo *b) {
                    return [a.executableName localizedCaseInsensitiveCompare:b.executableName];
                }];
                [self saveCache];
            }
            BOOL originsUpgraded = !self.processOriginsComplete || retried;
            if (originsUpgraded) {
                [self completeProcessOrigins];
                [self saveCache];
            }
            if (!wasLoaded || upgraded || retried || originsUpgraded) [self sendReloadToObservers];
            return;
        }
        [self scanDaemonList];
        [self saveCache];
    } @finally { [self.scanLock unlock]; }
}

- (void)completeBundleIdentifiers
{
                                                                                            
    NSMutableArray *records = [NSMutableArray new];
    for (CHPDaemonInfo *info in self.daemonList) {
        NSMutableDictionary *record = [@{@"executablePath": info.executablePath} mutableCopy];
        if (info.plistIdentifier) record[@"plistIdentifier"] = info.plistIdentifier;
        if (info.bundleIdentifier) record[@"bundleIdentifier"] = info.bundleIdentifier;
        if (info.launchDaemonPath) record[@"launchDaemonPath"] = info.launchDaemonPath;
        record[@"thirdPartyProcess"] = @(info.thirdPartyProcess);
        [records addObject:record];
    }
    NSArray *resolved = CHWLRecordsByResolvingBundleIdentifiers(records, ^NSString *(NSString *path) {
        return CHWLBundleIdentifierForExecutable(path);
    });
    NSMutableArray *updated = [NSMutableArray new];
    for (NSDictionary *record in resolved) {
        CHPDaemonInfo *info = [CHPDaemonInfo new];
        info.executablePath = record[@"executablePath"];
        info.plistIdentifier = record[@"plistIdentifier"];
        info.bundleIdentifier = record[@"bundleIdentifier"];
        info.launchDaemonPath = record[@"launchDaemonPath"];
        info.thirdPartyProcess = [record[@"thirdPartyProcess"] boolValue];
        [updated addObject:info];
    }
                                                                                
    self.daemonList = updated.copy;
    self.bundleIdentifiersComplete = YES;
}

- (NSArray<NSString *> *)launchDaemonDirectories
{
    NSMutableArray *directories = [@[@"/System/Library/LaunchDaemons",
        @"/System/Library/NanoLaunchDaemons", @"/Library/LaunchDaemons"] mutableCopy];
    NSString *jailbreakDirectory = jbroot(@"/Library/LaunchDaemons");
    if (jailbreakDirectory.length && ![directories containsObject:jailbreakDirectory]) [directories addObject:jailbreakDirectory];
    return directories.copy;
}

- (NSString *)executablePathForLaunchDaemon:(NSDictionary *)dictionary source:(NSString *)source
{
    if (![dictionary isKindOfClass:NSDictionary.class]) return nil;
    id path = dictionary[@"Program"];
    if (![path isKindOfClass:NSString.class] || ![path length]) {
        id arguments = dictionary[@"ProgramArguments"];
        path = [arguments isKindOfClass:NSArray.class] && [arguments count] ? [arguments firstObject] : nil;
    }
    if (![path isKindOfClass:NSString.class] || ![path isAbsolutePath]) return nil;
    NSString *jailbreakRoot = jbroot(@"/");
    if (CHWLPathIsInsideDirectory(source, jbroot(@"/Library/LaunchDaemons")) &&
        !CHWLPathIsInsideDirectory(path, jailbreakRoot)) {
        NSString *candidate = jbroot((NSString *)path);
        if (candidate.length && [NSFileManager.defaultManager fileExistsAtPath:candidate]) return candidate;
    }
    return path;
}

- (void)completeProcessOrigins
{
    NSMutableDictionary *sources = [NSMutableDictionary new];
    BOOL needsSources = NO;
    for (CHPDaemonInfo *info in self.daemonList) {
        if (!info.launchDaemonPath.length) { needsSources = YES; break; }
    }
    if (needsSources) {
        for (NSString *directory in [self launchDaemonDirectories]) {
            for (NSString *file in [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil]) {
                if (![file.pathExtension isEqualToString:@"plist"]) continue;
                NSString *source = [directory stringByAppendingPathComponent:file];
                NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:source];
                NSString *path = [self executablePathForLaunchDaemon:dictionary source:source].stringByResolvingSymlinksInPath;
                if (path.length && !sources[path]) sources[path] = source;
            }
        }
    }
    NSString *jailbreakRoot = [jbroot(@"/") stringByResolvingSymlinksInPath];
    NSMutableArray *updated = [NSMutableArray new];
    for (CHPDaemonInfo *info in self.daemonList) {
        CHPDaemonInfo *copy = [CHPDaemonInfo new];
        copy.executablePath = info.executablePath;
        copy.plistIdentifier = info.plistIdentifier;
        copy.bundleIdentifier = info.bundleIdentifier;
        NSString *path = info.executablePath.stringByResolvingSymlinksInPath;
        copy.launchDaemonPath = info.launchDaemonPath ?: (path.length ? sources[path] : nil);
        NSString *application = CHWLOwningApplicationPath(path);
        NSDictionary *appInfo = application.length ? [NSDictionary dictionaryWithContentsOfFile:
            [application stringByAppendingPathComponent:@"Info.plist"]] : nil;
        copy.thirdPartyProcess = CHWLIsThirdPartyProcess(path,
            copy.launchDaemonPath.stringByResolvingSymlinksInPath, jailbreakRoot, appInfo[@"CFBundleIdentifier"]);
        [updated addObject:copy];
    }
    self.daemonList = updated.copy;
    self.processOriginsComplete = YES;
}

- (void)mergeComponentScan:(NSDictionary *)components intoDaemons:(NSMutableArray *)daemons
{
    self.catalogScanAttempted = YES;
    self.componentCatalogComplete = [components[@"complete"] boolValue];
    self.extensionList = self.componentCatalogComplete ? components[@"extensions"] :
        CHWLMergeExtensionRecords(components[@"extensions"], self.extensionList);
    for (NSDictionary *record in components[@"services"]) {
        CHPDaemonInfo *info = [CHPDaemonInfo new];
        info.executablePath = record[@"executablePath"];
        info.bundleIdentifier = record[@"bundleIdentifier"];
        if (![self daemonList:daemons containsExecutableName:info.executableName]) [daemons addObject:info];
    }
}

- (void)scanDaemonList
{
	HBLogDebugWeak(@"updateDaemonListIfNeeded");

	if (_loaded || _loading) {
		return;
	}

	self.loading = YES;

                                                                                       
    NSMutableArray<NSURL *> *daemonPlists = [NSMutableArray new];
    NSArray<NSString *> *directories = [self launchDaemonDirectories];
    for (NSString *directory in directories) {
        NSArray *entries = [NSFileManager.defaultManager contentsOfDirectoryAtURL:[NSURL fileURLWithPath:directory]
            includingPropertiesForKeys:nil options:0 error:nil];
        if (entries) [daemonPlists addObjectsFromArray:entries];
    }

	for (NSURL *daemonPlistURL in [daemonPlists reverseObjectEnumerator]) {
		if (![daemonPlistURL.pathExtension isEqualToString:@"plist"]) {
			[daemonPlists removeObject:daemonPlistURL];
		}
	}

	NSMutableArray *daemonListM = [NSMutableArray new];

	for (NSURL *daemonPlistURL in daemonPlists) {
		NSDictionary *daemonDictionary = [NSDictionary dictionaryWithContentsOfURL:daemonPlistURL];
		
		CHPDaemonInfo *info = [[CHPDaemonInfo alloc] init];

        info.executablePath = [self executablePathForLaunchDaemon:daemonDictionary source:daemonPlistURL.path];
        info.launchDaemonPath = daemonPlistURL.path;
        id label = daemonDictionary[@"Label"];
        info.plistIdentifier = [label isKindOfClass:NSString.class] && [label length] ? label :
            daemonPlistURL.lastPathComponent.stringByDeletingPathExtension;

		                                  
		if (info.executablePath && [[NSFileManager defaultManager] fileExistsAtPath:info.executablePath] && ![info.plistIdentifier hasSuffix:@"Jetsam"] && ![info.plistIdentifier hasSuffix:@"SimulateCrash"] && ![info.plistIdentifier hasSuffix:@"_v2"] && ![info.plistIdentifier isEqualToString:kSpringboardBundleID]) {
			if (![self daemonList:daemonListM containsExecutableName:info.executableName]) {
				[daemonListM addObject:info];
			}
		}
	}

    [self mergeComponentScan:CHWLScanSystemComponents(CHWLSystemComponentDirectories()) intoDaemons:daemonListM];

	NSMutableArray *additionalPotentialDaemons = [NSMutableArray new];

	                                                                                                                     
	                                                          
	                                                                                                                        
	                                                                     
	DIR *dir;
    struct dirent *dp;
    dir = opendir("/usr/libexec");
    while (dir && (dp=readdir(dir)) != NULL) {
        if (!(!strcmp(dp->d_name, ".") || !strcmp(dp->d_name, "..")))
        {
            NSString *filename = [NSString stringWithCString:dp->d_name encoding:NSUTF8StringEncoding];
            if (filename) {
				NSURL *URL = [NSURL fileURLWithPath:[@"/usr/libexec" stringByAppendingPathComponent:filename]];
				[additionalPotentialDaemons addObject:URL];
			}
        }
    }
    if (dir) closedir(dir);

    for (NSString *directory in @[@"/usr/bin", @"/usr/sbin"]) {
        NSArray *entries = [NSFileManager.defaultManager contentsOfDirectoryAtURL:[NSURL fileURLWithPath:directory isDirectory:YES]
            includingPropertiesForKeys:nil options:0 error:nil];
        if (entries) [additionalPotentialDaemons addObjectsFromArray:entries];
    }

	for (NSURL *URL in additionalPotentialDaemons) {
		if ([URL.lastPathComponent hasSuffix:@"d"]) {
			CHPDaemonInfo *info = [[CHPDaemonInfo alloc] init];
			info.executablePath = [URL path];

			if (![self daemonList:daemonListM containsExecutableName:info.executableName]) {
				[daemonListM addObject:info];
			}
		}
	}

	[daemonListM sortUsingComparator:^NSComparisonResult(CHPDaemonInfo *a, CHPDaemonInfo *b) {                       
		return [[a executableName] localizedCaseInsensitiveCompare:[b executableName]];
	}];

	HBLogDebugWeak(@"updateDaemonListIfNeeded loaded files");



	for (CHPDaemonInfo *daemonInfo in [daemonListM reverseObjectEnumerator]) {
		if (![[NSFileManager defaultManager] isExecutableFileAtPath:daemonInfo.executablePath]) {
			[daemonListM removeObject:daemonInfo];
		}
	}

	self.daemonList = [daemonListM copy];
    self.loadedContext = [self cacheContext];
    [self completeBundleIdentifiers];
	self.loading = NO;
    [self completeProcessOrigins];
	self.loaded = _daemonList.count > 0;

	HBLogDebugWeak(@"updateDaemonListIfNeeded end");

	[self sendReloadToObservers];
}

- (void)addObserver:(id<CHPDaemonListObserver>)observer
{
    @synchronized (_observers) { [_observers addObject:observer]; }
}
- (void)removeObserver:(id<CHPDaemonListObserver>)observer
{
    @synchronized (_observers) { [_observers removeObject:observer]; }
}
- (void)sendReloadToObservers
{
    NSArray *observers;
    @synchronized (_observers) { observers = _observers.allObjects; }
    dispatch_async(dispatch_get_main_queue(), ^{
        for (id<CHPDaemonListObserver> observer in observers) [observer daemonListDidUpdate:self];
    });
}

- (NSString *)executablePathForDaemonName:(NSString *)daemonName
{
	__block NSString *executablePath = nil;

	[self.daemonList enumerateObjectsUsingBlock:^(CHPDaemonInfo *daemonInfo, NSUInteger idx, BOOL *stop) {
		if ([daemonInfo.executablePath.lastPathComponent isEqualToString:daemonName]) {
			executablePath = daemonInfo.executablePath;
			*stop = YES;
		}
	}];

	return executablePath;
}

@end

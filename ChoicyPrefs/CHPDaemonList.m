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
#import <sys/sysctl.h>

@interface CHPDaemonList ()
@property (nonatomic) NSRecursiveLock *scanLock;
@property (atomic, readwrite) BOOL loaded;
@property (atomic, readwrite) BOOL loading;
@property (atomic, readwrite) NSArray *daemonList;
@property (nonatomic) NSMutableDictionary *frameworkMatches;
@property (nonatomic) BOOL bundleIdentifiersComplete;
- (void)completeBundleIdentifiers;
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
    return @{@"osBuild": [NSString stringWithUTF8String:build],
        @"preferencesDirectory": cachePath.stringByDeletingLastPathComponent};
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
    NSArray *records = CHWLValidatedRecords(cache, context);
    if (!records) return NO;
    id frameworkMatches = [cache objectForKey:@"frameworkMatches"];
    self.frameworkMatches = [frameworkMatches isKindOfClass:NSDictionary.class] ? [frameworkMatches mutableCopy] : [NSMutableDictionary new];
    NSMutableArray *list = [NSMutableArray new];
    for (NSDictionary *record in records) {
        CHPDaemonInfo *info = [CHPDaemonInfo new];
        info.executablePath = record[@"executablePath"];
        info.plistIdentifier = record[@"plistIdentifier"];
        info.bundleIdentifier = record[@"bundleIdentifier"];
        [list addObject:info];
    }
    self.daemonList = list.copy;
    self.bundleIdentifiersComplete = [cache[@"bundleIdentifierVersion"] isEqual:@(CHWLProcessBundleIdentifierVersion)];
    self.loaded = YES;
    self.loading = NO;
    return YES;
}
- (void)saveCache
{
    NSDictionary *context = [self cacheContext];
    NSString *path = kChoicyProcessCachePath;
    if (!context || !path || !_loaded || _loading || !_daemonList.count) return;
    NSMutableArray *records = [NSMutableArray new];
    for (CHPDaemonInfo *info in _daemonList) {
        NSMutableDictionary *record = [@{@"executablePath": info.executablePath} mutableCopy];
        if (info.plistIdentifier.length) record[@"plistIdentifier"] = info.plistIdentifier;
        if (info.bundleIdentifier.length) record[@"bundleIdentifier"] = info.bundleIdentifier;
        [records addObject:record];
    }
    NSDictionary *cache = @{@"schemaVersion": @(CHWLProcessCacheSchemaVersion), @"scanComplete": @YES, @"context": context,
        @"processes": records, @"frameworkMatches": self.frameworkMatches.copy,
        @"bundleIdentifierVersion": @(self.bundleIdentifiersComplete ? CHWLProcessBundleIdentifierVersion : 0)};
    if (!CHWLValidatedRecords(cache, context)) return;
    [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:cache format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    if (data.length <= 8 * 1024 * 1024) [data writeToFile:path options:NSDataWritingAtomic error:nil];
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
- (void)cacheFrameworkIdentifiers:(NSSet *)identifiers forPath:(NSString *)path signature:(NSDictionary *)signature
{
    if (!path.length || !identifiers || !signature) return;
    [self.scanLock lock];
    @try {
        self.frameworkMatches[path] = @{@"version": @(CHWLFrameworkCacheEntryVersion), @"signature": signature,
            @"identifiers": [identifiers.allObjects sortedArrayUsingSelector:@selector(compare:)]};
        [self saveCache];
    } @finally { [self.scanLock unlock]; }
}
- (void)updateDaemonListIfNeeded
{
    [self.scanLock lock];
    @try {
        if (_loading) return;
        BOOL wasLoaded = _loaded;
        if (_loaded || [self restoreCache]) {
            BOOL upgraded = !self.bundleIdentifiersComplete;
            if (upgraded) {
                [self completeBundleIdentifiers];
                [self saveCache];
            }
            if (!wasLoaded || upgraded) [self sendReloadToObservers];
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
        [updated addObject:info];
    }

    self.daemonList = updated.copy;
    self.bundleIdentifiersComplete = YES;
}

- (void)scanDaemonList
{
	HBLogDebugWeak(@"updateDaemonListIfNeeded");

	if (_loaded || _loading) {
		return;
	}

	self.loading = YES;

    NSMutableArray<NSURL *> *daemonPlists = [NSMutableArray new];
    NSMutableArray<NSString *> *directories = [@[@"/System/Library/LaunchDaemons",
        @"/System/Library/NanoLaunchDaemons", @"/Library/LaunchDaemons"] mutableCopy];
    NSString *jailbreakDirectory = jbroot(@"/Library/LaunchDaemons");
    if (jailbreakDirectory.length && ![directories containsObject:jailbreakDirectory]) [directories addObject:jailbreakDirectory];
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

		info.executablePath = [daemonDictionary objectForKey:@"Program"];

		if (!info.executablePath) {
			NSArray *programArguments = [daemonDictionary objectForKey:@"ProgramArguments"];
			if (programArguments.count > 0) {
				info.executablePath = programArguments.firstObject;
			}
		}

        if (info.executablePath.length) {
            NSString *jailbreakRoot = jbroot(@"/");
            BOOL jailbreakDaemon = jailbreakDirectory.length && [daemonPlistURL.path hasPrefix:[jailbreakDirectory stringByAppendingString:@"/"]];
            if (jailbreakDaemon && jailbreakRoot.length && ![jailbreakRoot isEqualToString:@"/"] &&
                ![info.executablePath hasPrefix:jailbreakRoot]) info.executablePath = jbroot(info.executablePath);
        }
		info.plistIdentifier = [daemonDictionary objectForKey:@"Label"] ?: [daemonPlistURL lastPathComponent].stringByDeletingPathExtension;

		if (info.executablePath && [[NSFileManager defaultManager] fileExistsAtPath:info.executablePath] && ![info.plistIdentifier hasSuffix:@"Jetsam"] && ![info.plistIdentifier hasSuffix:@"SimulateCrash"] && ![info.plistIdentifier hasSuffix:@"_v2"] && ![info.plistIdentifier isEqualToString:kSpringboardBundleID]) {
			if (![self daemonList:daemonListM containsExecutableName:info.executableName]) {
				[daemonListM addObject:info];
			}
		}
	}

	NSDirectoryEnumerator *systemLibraryFrameworksEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:@"/System/Library/Frameworks" isDirectory:YES] includingPropertiesForKeys:nil options:0 errorHandler:^(NSURL *url, NSError *error) {
		return YES;
	}];

	NSDirectoryEnumerator *cryptexSystemLibraryFrameworksEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:@"/private/preboot/Cryptexes/OS/System/Library/Frameworks" isDirectory:YES] includingPropertiesForKeys:nil options:0 errorHandler:^(NSURL *url, NSError *error) {
		return YES;
	}];

	NSDirectoryEnumerator *systemLibraryPrivateFrameworksEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:@"/System/Library/PrivateFrameworks" isDirectory:YES] includingPropertiesForKeys:nil options:0 errorHandler:^(NSURL *url, NSError *error) {
		return YES;
	}];

	NSDirectoryEnumerator *cryptexSystemLibraryPrivateFrameworksEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:@"/private/preboot/Cryptexes/OS/System/Library/PrivateFrameworks" isDirectory:YES] includingPropertiesForKeys:nil options:0 errorHandler:^(NSURL *url, NSError *error) {
		return YES;
	}];

	NSMutableArray *XPCUrls = [NSMutableArray new];

	for (NSURL *fileURL in systemLibraryFrameworksEnumerator) {
		if ([fileURL.path hasSuffix:@".xpc"]) {
			[XPCUrls addObject:fileURL];
		}
	}

	for (NSURL *fileURL in cryptexSystemLibraryFrameworksEnumerator) {
		if ([fileURL.path hasSuffix:@".xpc"]) {
			[XPCUrls addObject:fileURL];
		}
	}

	for (NSURL *fileURL in systemLibraryPrivateFrameworksEnumerator) {
		if ([fileURL.path hasSuffix:@".xpc"]) {
			[XPCUrls addObject:fileURL];
		}
	}

	for (NSURL *fileURL in cryptexSystemLibraryPrivateFrameworksEnumerator) {
		if ([fileURL.path hasSuffix:@".xpc"]) {
			[XPCUrls addObject:fileURL];
		}
	}

	for (NSURL *XPCUrl in XPCUrls) {
		NSString *XPCPath = XPCUrl.path;

		NSString *XPCName = [XPCUrl.lastPathComponent stringByReplacingOccurrencesOfString:@".xpc" withString:@""];

		NSString *XPCExecutablePath = [XPCPath stringByAppendingPathComponent:XPCName];

		if ([[NSFileManager defaultManager] fileExistsAtPath:XPCExecutablePath]) {
			CHPDaemonInfo *info = [[CHPDaemonInfo alloc] init];
			info.executablePath = XPCExecutablePath;

			if (![self daemonList:daemonListM containsExecutableName:info.executableName]) {
				[daemonListM addObject:info];
			}
		}
	}

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
    [self completeBundleIdentifiers];
	self.loading = NO;
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

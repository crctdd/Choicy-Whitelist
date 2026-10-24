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

#import "CHPTweakList.h"
#import "CHPTweakInfo.h"
#import "CHPDaemonInfo.h"
#import "CHPMachoParser.h"
#import "../Shared.h"
#import "../HBLogWeak.h"
#import <roothide.h>
#import "CHWLTargetIndex.h"
#import "CHWLExecutableInfo.h"
#import "CHWLData.h"
#import "CHWLCandidateAnalysisCache.h"

@interface CHPTweakList ()
@property (nonatomic) NSDictionary *targetIndex;
@property (nonatomic) NSDictionary *tweaksByName;
@property (nonatomic) NSDictionary *fileFingerprint;
@property (nonatomic) NSRecursiveLock *updateLock;
@property (atomic, readwrite) NSUInteger targetGeneration;
@property (nonatomic) CHWLCandidateAnalysisCache *candidateAnalysisCache;
@end

@implementation CHPTweakList

+ (instancetype)sharedInstance
{
	static CHPTweakList *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^ {
		                     
		sharedInstance = [[CHPTweakList alloc] init];
	});
	return sharedInstance;
}

+ (NSArray *)possibleInjectionLibrariesPaths
{
	if (![jbroot(@"/") isEqualToString:@"/"]) {
		return @[jbroot([@"/" stringByAppendingString:@"Library/MobileSubstrate/DynamicLibraries"]), jbroot([@"/" stringByAppendingString:@"usr/lib/TweakInject"])];
	}

	                                                                                                      
	return @[[@"/" stringByAppendingString:@"Library/MobileSubstrate/DynamicLibraries"], [@"/" stringByAppendingString:@"usr/lib/TweakInject"], @"/var/jb/Library/MobileSubstrate/DynamicLibraries", @"/var/jb/usr/lib/TweakInject"];
}

+ (NSString *)injectionLibrariesPath
{
	for (NSString *possibleInjectionLibrariesPath in [self possibleInjectionLibrariesPaths]) {
		if ([[NSFileManager defaultManager] fileExistsAtPath:possibleInjectionLibrariesPath]) {
			return possibleInjectionLibrariesPath;
		}
	}

	@throw [[NSException alloc] initWithName:@"TweakDirectoryException" reason:[NSString stringWithFormat:@"Unable to locate tweak installation directory"] userInfo:nil];
}

+ (BOOL)isTweakLibraryPath:(NSString *)path
{
	if (![path.pathExtension isEqualToString:@"dylib"]) return NO;

	for (NSString *possibleInjectionLibrariesPath in [self possibleInjectionLibrariesPaths]) {
		if ([path hasPrefix:possibleInjectionLibrariesPath]) return YES;
	}

	return NO;
}

+ (NSURL *)injectionLibrariesURL
{
	return [NSURL fileURLWithPath:[self injectionLibrariesPath]].URLByResolvingSymlinksInPath;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		_updateLock = [NSRecursiveLock new];
        _candidateAnalysisCache = [CHWLCandidateAnalysisCache new];
		[self updateTweakList];
	}
	return self;
}

- (void)updateTweakList
{
    [self.updateLock lock];
    @try {
	NSMutableArray *tweakListM = [NSMutableArray new];
	NSArray *dynamicLibraries = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[CHPTweakList injectionLibrariesURL] includingPropertiesForKeys:nil options:0 error:nil];

	for (NSURL *URL in dynamicLibraries) {
		if ([[URL pathExtension] isEqualToString:@"plist"]) {
			NSURL *dylibURL = [[URL URLByDeletingPathExtension] URLByAppendingPathExtension:@"dylib"];
			if ([dylibURL checkResourceIsReachableAndReturnError:nil]) {
				CHPTweakInfo *tweakInfo = [[CHPTweakInfo alloc] initWithDylibPath:dylibURL.path plistPath:URL.path];
				[tweakListM addObject:tweakInfo];
			}
		}
	}

	[tweakListM sortUsingSelector:@selector(caseInsensitiveCompare:)];

    NSMutableArray *rules = [NSMutableArray new];
    NSMutableDictionary *byName = [NSMutableDictionary new];
    for (CHPTweakInfo *tweak in tweakListM) {
        if ([self isTweakHiddenForAnyProcess:tweak]) continue;
        byName[tweak.dylibName] = tweak;
        [rules addObject:@{@"name": tweak.dylibName, @"bundles": tweak.explicitFilterBundles ?: @[],
            @"executables": tweak.filterExecutables ?: @[]}];
    }
    NSDictionary *index = CHWLBuildTargetIndex(rules);
    @synchronized (self) {
        self.tweakList = tweakListM.copy;
        self.targetIndex = index;
        self.tweaksByName = byName.copy;
        self.targetGeneration++;
        [self.candidateAnalysisCache invalidateAll];
    }
    self.fileFingerprint = [self currentFileFingerprint];
    } @finally { [self.updateLock unlock]; }
}

- (NSDictionary *)currentFileFingerprint
{
    NSMutableDictionary *files = [NSMutableDictionary new];
    for (NSString *directory in [self.class possibleInjectionLibrariesPaths]) {
        for (NSString *file in [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil]) {
            if (![@[@"plist", @"dylib"] containsObject:file.pathExtension]) continue;
            NSString *path = [directory stringByAppendingPathComponent:file];
            NSDictionary *attrs = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
            files[path] = @[attrs[NSFileSize] ?: @0, attrs[NSFileModificationDate] ?: NSDate.distantPast];
        }
    }
    return files.copy;
}

- (BOOL)refreshTweakListIfNeeded
{
    [self.updateLock lock];
    @try {
        if ([self.fileFingerprint isEqual:[self currentFileFingerprint]]) return NO;
        [self updateTweakList];
        return YES;
    } @finally { [self.updateLock unlock]; }
}

- (NSArray *)explicitTweaksForBundleIdentifier:(NSString *)identifier executableName:(NSString *)name
{
    return [self tweaksForBundleIdentifier:identifier executableName:name frameworkIdentifiers:nil];
}
- (NSArray *)tweaksForBundleIdentifier:(NSString *)identifier executableName:(NSString *)name frameworkIdentifiers:(NSSet *)frameworks
{
    @synchronized (self) {
        NSMutableArray *result = [NSMutableArray new];
        for (NSString *dylib in CHWLTargetNamesIncludingFrameworks(self.targetIndex, identifier, name, frameworks)) {
            CHPTweakInfo *tweak = self.tweaksByName[dylib];
            if (tweak) [result addObject:tweak];
        }
        return result.copy;
    }
}

- (NSDictionary *)candidateAnalysisForExecutableAtPath:(NSString *)executablePath
{
    executablePath = executablePath.stringByStandardizingPath;
    NSDictionary *cached = [self cachedCandidateAnalysisForExecutableAtPath:executablePath];
    if (cached) return cached;
    NSUInteger revision;
    NSArray *snapshot;
    @synchronized (self) {
        revision = self.candidateAnalysisCache.revision;
        snapshot = self.tweakList;
    }
    NSDictionary *analysis = [[CHPMachoParser sharedInstance] frameworkAnalysisForMachoAtPath:executablePath];
    NSString *bundleID = CHWLBundleIdentifierForExecutable(executablePath);
    NSArray *matches = CHWLMatchingConfigurationTweaks(snapshot, bundleID, executablePath.lastPathComponent,
        analysis[@"identifiers"]);
    NSMutableDictionary *reasons = [NSMutableDictionary new];
    for (CHPTweakInfo *tweak in matches) reasons[tweak.dylibName] = CHWLMatchReasons(tweak,
        bundleID, executablePath.lastPathComponent, analysis[@"identifiers"]);
    NSDictionary *result = @{@"matches": matches, @"reasons": reasons.copy, @"identifiers": analysis[@"identifiers"],
        @"inputs": analysis[@"inputs"] ?: @{}, @"complete": analysis[@"complete"], @"failures": analysis[@"failures"]};
    [self.candidateAnalysisCache storeAnalysis:result forPath:executablePath revision:revision];
    return result;
}

- (NSDictionary *)cachedCandidateAnalysisForExecutableAtPath:(NSString *)executablePath
{
    return [self.candidateAnalysisCache cachedAnalysisForPath:executablePath];
}
- (void)invalidateCandidateAnalysisForExecutableAtPath:(NSString *)executablePath
{
    [self.candidateAnalysisCache invalidatePath:executablePath];
}
- (void)invalidateAllCandidateAnalyses { [self.candidateAnalysisCache invalidateAll]; }

- (BOOL)isTweak:(CHPTweakInfo *)tweak hiddenForApplicationWithIdentifier:(NSString *)applicationID
{
	if ([applicationID isEqualToString:kSpringboardBundleID]) {
		if ([kAlwaysInjectSpringboard containsObject:tweak.dylibName]) {
			return YES;
		}
	}

	if ([applicationID isEqualToString:kPreferencesBundleID]) {
		if ([kAlwaysInjectPreferences containsObject:tweak.dylibName]) {
			return YES;
		}
	}

	return [kAlwaysInjectGlobal containsObject:tweak.dylibName];
}

- (BOOL)isTweakHiddenForAnyProcess:(CHPTweakInfo *)tweak
{
	if ([self isTweak:tweak hiddenForApplicationWithIdentifier:kSpringboardBundleID]) {
		return YES;
	}

	if ([self isTweak:tweak hiddenForApplicationWithIdentifier:kPreferencesBundleID]) {
		return YES;
	}

	return NO;
}

@end

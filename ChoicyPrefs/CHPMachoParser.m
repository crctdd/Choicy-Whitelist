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

#import "CHPMachoParser.h"
#import "CHWLFrameworkSupport.h"
#import "CHWLExecutableInfo.h"
#import <mach-o/loader.h>

#import <litehook.h>

#import <Host.h>
#import <Fat.h>
#import <MachO.h>

#import <mach-o/dyld_images.h>
#import <mach-o/dyld.h>
#import <version.h>

MachO *choicy_fat_find_preferred_slice(Fat *fat)
{
	cpu_type_t cputype;
	cpu_subtype_t cpusubtype;
	if (host_get_cpu_information(&cputype, &cpusubtype) != 0) { return NULL; }

	MachO *candidateSlice = NULL;

	if (cputype == CPU_TYPE_ARM64) {
		if (!candidateSlice && cpusubtype == CPU_SUBTYPE_ARM64E) {

			if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_14_0) {
				candidateSlice = fat_find_slice(fat, cputype, CPU_SUBTYPE_ARM64E | CPU_SUBTYPE_ARM64E_ABI_V2);
				if (!candidateSlice && kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_15_0) {

					candidateSlice = fat_find_slice(fat, cputype, CPU_SUBTYPE_ARM64E);
				}
			}

			else {
				candidateSlice = fat_find_slice(fat, cputype, CPU_SUBTYPE_ARM64E);
			}
		}

		if (!candidateSlice) {
			if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_15_0) {

				candidateSlice = fat_find_slice(fat, cputype, CPU_SUBTYPE_ARM64_V8);
			}
			if (!candidateSlice) {
				candidateSlice = fat_find_slice(fat, cputype, CPU_SUBTYPE_ARM64_ALL);
			}
		}
	}
	else if (cputype == CPU_TYPE_ARM) {
		candidateSlice = fat_find_slice(fat, cputype, cpusubtype);
		if (!candidateSlice && cpusubtype == CPU_SUBTYPE_ARM_V7S) {
			candidateSlice = fat_find_slice(fat, cputype, CPU_SUBTYPE_ARM_V7);
		}
	}

	return candidateSlice;
}

@implementation CHPMachoParser

+ (instancetype)sharedInstance
{
	static CHPMachoParser *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^ {

		sharedInstance = [[CHPMachoParser alloc] init];
	});
	return sharedInstance;
}

+ (BOOL)isMachoAtPath:(NSString *)path
{
	return NO;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		_bundleIdentifierCache = [NSMutableDictionary new];
		_dependencyPathCache = [NSMutableDictionary new];
        _imageMetadataCache = [NSMutableDictionary new];
        _frameworkIdentifierCache = [NSMutableDictionary new];

		task_dyld_info_data_t dyldInfo = {0};
		uint32_t count = TASK_DYLD_INFO_COUNT;
		kern_return_t status = task_info(mach_task_self_, TASK_DYLD_INFO, (task_info_t)&dyldInfo, &count);
		struct dyld_all_image_infos *allImageInfos = (void *)dyldInfo.all_image_info_addr;

		const char *cachePath = litehook_locate_dsc();
        if (status == KERN_SUCCESS && allImageInfos && cachePath && *cachePath) {
            _sharedCache = dsc_init_from_path_premapped(cachePath, allImageInfos->sharedCacheSlide);
        }
	}
	return self;
}

- (BOOL)readMachoAtPath:(NSString *)path block:(void (^)(MachO *macho))block
{
    Fat *fat = NULL;
    MachO *macho = _sharedCache ? dsc_lookup_macho_by_path(_sharedCache, path.fileSystemRepresentation, NULL) : NULL;
    if (!macho) {
        fat = fat_init_from_path(path.fileSystemRepresentation);
        if (fat) macho = choicy_fat_find_preferred_slice(fat);
    }
    BOOL found = macho != NULL;
    if (macho) block(macho);
    if (fat) fat_free(fat);
    return found;
}

- (NSDictionary *)metadataForMachoAtPath:(NSString *)path
{
    if (_imageMetadataCache[path]) return _imageMetadataCache[path];
    NSMutableArray *dependencies = [NSMutableArray new];
    NSMutableArray *runpaths = [NSMutableArray new];
    NSMutableArray *weakDependencies = [NSMutableArray new];
    BOOL found = [self readMachoAtPath:path block:^(MachO *macho) {
        macho_enumerate_dependencies(macho, ^(const char *value, uint32_t cmd, struct dylib *dylib, bool *stop) {
            if (value) {
                NSString *raw = [NSString stringWithUTF8String:value];
                if (raw) {
                    [dependencies addObject:raw];
                    if (cmd == LC_LOAD_WEAK_DYLIB) [weakDependencies addObject:raw];
                }
            }
        });
        macho_enumerate_rpaths(macho, ^(const char *value, bool *stop) {
            if (value) {
                NSString *raw = [NSString stringWithUTF8String:value];
                if (raw) [runpaths addObject:raw];
            }
        });
    }];
    if (!found) return nil;
    NSDictionary *metadata = @{@"dependencies": dependencies.copy, @"runpaths": runpaths.copy, @"weakDependencies": weakDependencies.copy};
    _imageMetadataCache[path] = metadata;
    return metadata;
}

- (NSDictionary *)dependencyAnalysisForMachoAtPath:(NSString *)path
{
    @synchronized (self) {
        if (!path.length) return @{@"paths": [NSSet set], @"failures": [NSSet setWithObject:@"目标路径不可用"]};
        NSString *root = path.stringByStandardizingPath;
        if (_dependencyPathCache[root]) return @{@"paths": _dependencyPathCache[root], @"failures": [NSSet set]};
        NSMutableSet *unresolved = [NSMutableSet new];
        NSSet *unreadable = nil;
        NSMutableDictionary *loaderChains = [NSMutableDictionary dictionaryWithObject:@[] forKey:root];
        NSSet *result = CHWLCollectDependencies(root, ^NSArray *(NSString *image) {
            NSDictionary *metadata = [self metadataForMachoAtPath:image];
            if (!metadata) return nil;
            NSArray *sources = [@[image] arrayByAddingObjectsFromArray:loaderChains[image] ?: @[]];
            NSMutableOrderedSet *runpaths = [NSMutableOrderedSet new];
            for (NSString *source in sources) {
                for (NSString *raw in [self metadataForMachoAtPath:source][@"runpaths"]) {
                    NSString *expanded = CHWLResolveDependencyPath(raw, source, root, runpaths.array, nil);
                    if (expanded) [runpaths addObject:expanded];
                }
            }
            NSMutableArray *children = [NSMutableArray new];
            for (NSString *raw in metadata[@"dependencies"]) {
                NSString *resolved = CHWLResolveDependencyPath(raw, image, root, runpaths.array, ^BOOL(NSString *candidate) {
                    return _imageMetadataCache[candidate] || [NSFileManager.defaultManager fileExistsAtPath:candidate] ||
                        (_sharedCache && dsc_lookup_macho_by_path(_sharedCache, candidate.fileSystemRepresentation, NULL));
                });
                if (!resolved) {
                    if (![metadata[@"weakDependencies"] containsObject:raw]) {
                        [unresolved addObject:[NSString stringWithFormat:@"%@ → %@", image, raw]];
                    }
                    continue;
                }
                [children addObject:resolved];
                if (!loaderChains[resolved]) loaderChains[resolved] = sources;
            }
            return children.copy;
        }, &unreadable);
        [unresolved unionSet:unreadable ?: [NSSet set]];
        if (result && !unresolved.count) _dependencyPathCache[root] = result;
        return @{@"paths": result ?: [NSSet set], @"failures": unresolved.copy};
    }
}

- (NSSet *)dependencyPathsForMachoAtPath:(NSString *)path
{
    NSDictionary *analysis = [self dependencyAnalysisForMachoAtPath:path];
    return [analysis[@"failures"] count] ? nil : analysis[@"paths"];
}

- (NSSet *)frameworkBundleIdentifiersForMachoAtPath:(NSString *)path
{
    NSDictionary *analysis = [self frameworkAnalysisForMachoAtPath:path];
    return [analysis[@"complete"] boolValue] ? analysis[@"identifiers"] : nil;
}

- (void)invalidateAnalysisCaches
{
    @synchronized (self) {
        [_bundleIdentifierCache removeAllObjects];
        [_dependencyPathCache removeAllObjects];
        [_imageMetadataCache removeAllObjects];
        [_frameworkIdentifierCache removeAllObjects];
    }
}

- (NSDictionary *)frameworkAnalysisForMachoAtPath:(NSString *)path
{
    @synchronized (self) {
        if (!path.length) return @{@"identifiers": [NSSet set], @"complete": @NO,
            @"failures": [NSSet setWithObject:@"目标路径不可用"]};
        NSString *root = path.stringByStandardizingPath;
        if (_bundleIdentifierCache[root]) return @{@"identifiers": _bundleIdentifierCache[root], @"complete": @YES, @"failures": [NSSet set]};
        NSDictionary *analysis = [self dependencyAnalysisForMachoAtPath:root];
        NSSet *dependencies = analysis[@"paths"];
        NSMutableSet *failures = [analysis[@"failures"] mutableCopy];
        NSMutableSet *identifiers = [NSMutableSet new];
        NSMutableSet *images = dependencies.mutableCopy;
        [images addObject:root];
        for (NSString *image in images) {
            NSString *bundle = CHWLFrameworkBundlePath(image);
            if (!bundle) continue;
            id cachedIdentifier = _frameworkIdentifierCache[bundle];
            if (cachedIdentifier) {
                if ([cachedIdentifier isKindOfClass:NSString.class]) [identifiers addObject:cachedIdentifier];
                continue;
            }
            NSString *parent = image.stringByDeletingLastPathComponent;
            NSArray *candidates = @[[bundle stringByAppendingPathComponent:@"Info.plist"],
                [bundle stringByAppendingPathComponent:@"Resources/Info.plist"],
                [parent stringByAppendingPathComponent:@"Info.plist"],
                [parent stringByAppendingPathComponent:@"Resources/Info.plist"],
                [bundle stringByAppendingPathComponent:@"Versions/Current/Resources/Info.plist"]];
            for (NSString *candidate in candidates) {
                id identifier = [NSDictionary dictionaryWithContentsOfFile:candidate][@"CFBundleIdentifier"];
                if ([identifier isKindOfClass:NSString.class] && [identifier length]) {
                    _frameworkIdentifierCache[bundle] = identifier;
                    [identifiers addObject:identifier];
                    break;
                }
            }
            if (!_frameworkIdentifierCache[bundle]) {
                NSString *identifier = CHWLBundleIdentifierForExecutable(image) ?: [NSBundle bundleWithPath:bundle].bundleIdentifier;
                if (identifier.length) {
                    _frameworkIdentifierCache[bundle] = identifier;
                    [identifiers addObject:identifier];
                }
            }
            if (!_frameworkIdentifierCache[bundle]) [failures addObject:bundle];
        }
        BOOL complete = failures.count == 0;
        if (complete) _bundleIdentifierCache[root] = identifiers.copy;
        return @{@"identifiers": identifiers.copy, @"complete": @(complete), @"failures": failures.copy};
    }
}

@end

#import "CHWLData.h"
#import "CHPTweakInfo.h"
#import "../CHWhitelistPolicy.h"

static NSArray<NSString *> *CHWLNamesInArray(id values)
{
    if (![values isKindOfClass:NSArray.class]) return @[];
    NSMutableOrderedSet *names = [NSMutableOrderedSet new];
    for (id name in values) {
        if ([name isKindOfClass:NSString.class] && [name length]) [names addObject:name];
    }
    return names.array;
}

NSArray<NSString *> *CHWLPrivilegedTweakNames(NSDictionary *preferences)
{
    return CHWLNamesInArray(preferences[@CH_PRIVILEGED_TWEAKS_KEY]);
}

NSArray<NSString *> *CHWLManualPrivilegedTweakNames(NSDictionary *preferences)
{
    return CHWLNamesInArray(preferences[@CH_MANUAL_PRIVILEGED_TWEAKS_KEY]);
}

BOOL CHWLPrivilegeCandidate(NSDictionary *preferences, NSString *name, BOOL isUIKit)
{
    return name.length && (isUIKit || [CHWLManualPrivilegedTweakNames(preferences) containsObject:name]);
}

BOOL CHWLIsPrivilegedTweak(NSDictionary *preferences, NSString *name, BOOL isUIKit)
{
    return CHPrivilegeApplies(isUIKit, name.length && [CHWLManualPrivilegedTweakNames(preferences) containsObject:name],
        name.length && [CHWLPrivilegedTweakNames(preferences) containsObject:name]);
}

NSDictionary *CHWLPreferencesBySettingManualPrivileges(NSDictionary *preferences, NSArray<NSString *> *names)
{
    NSSet *previous = [NSSet setWithArray:CHWLManualPrivilegedTweakNames(preferences)];
    NSSet *selected = [NSSet setWithArray:CHWLNamesInArray(names)];
    NSMutableSet *enabled = [NSMutableSet setWithArray:CHWLPrivilegedTweakNames(preferences)];
    for (NSString *name in previous) {
        if (![selected containsObject:name]) [enabled removeObject:name];
    }
    for (NSString *name in selected) {
        if (![previous containsObject:name]) [enabled removeObject:name];
    }
    NSMutableDictionary *updated = preferences.mutableCopy ?: [NSMutableDictionary new];
    updated[@CH_MANUAL_PRIVILEGED_TWEAKS_KEY] = [selected.allObjects sortedArrayUsingSelector:@selector(compare:)];
    updated[@CH_PRIVILEGED_TWEAKS_KEY] = [enabled.allObjects sortedArrayUsingSelector:@selector(compare:)];
    return updated.copy;
}

NSArray *CHWLPrivilegeCandidates(NSArray *tweaks)
{
    NSMutableArray *candidates = [NSMutableArray new];
    for (CHPTweakInfo *tweak in tweaks) {
        if (tweak.isUIKitTweak) [candidates addObject:tweak];
    }
    return [candidates sortedArrayUsingComparator:^NSComparisonResult(CHPTweakInfo *a, CHPTweakInfo *b) {
        NSComparisonResult result = [a.dylibName localizedCaseInsensitiveCompare:b.dylibName];
        return result == NSOrderedSame ? [a.dylibName compare:b.dylibName] : result;
    }];
}

NSString *CHWLConfigurationSummary(BOOL injectionEnabled, BOOL privilegeEligible, NSDictionary *processPreferences)
{
    if (CHWLPrivilegesDisabled(injectionEnabled, privilegeEligible, processPreferences)) return @"禁特权";
    return CHWLCustomConfigurationActive(NO, injectionEnabled, privilegeEligible, processPreferences) ||
        CHWLCustomConfigurationActive(YES, injectionEnabled, privilegeEligible, processPreferences) ? @"自定义" : @"";
}

NSArray *CHWLConfigurationCandidates(NSArray *tweaks, NSDictionary *preferences,
    BOOL privilegeEligible, BOOL privilegedPage)
{
    NSMutableArray *result = [NSMutableArray new];
    for (CHPTweakInfo *tweak in tweaks) {
        BOOL privileged = privilegeEligible && CHWLIsPrivilegedTweak(preferences, tweak.dylibName, tweak.isUIKitTweak);
        if (privileged == privilegedPage) [result addObject:tweak];
    }
    return [result sortedArrayUsingComparator:^NSComparisonResult(CHPTweakInfo *a, CHPTweakInfo *b) {
        NSComparisonResult order = [a.dylibName localizedCaseInsensitiveCompare:b.dylibName];
        return order == NSOrderedSame ? [a.dylibName compare:b.dylibName] : order;
    }];
}

NSArray<NSString *> *CHWLMatchReasons(CHPTweakInfo *tweak, NSString *identifier,
    NSString *executableName, NSSet *frameworks)
{
    NSMutableArray *reasons = [NSMutableArray new];
    if (identifier.length && [tweak.explicitFilterBundles containsObject:identifier])
        [reasons addObject:[@"指定 Bundle ID：" stringByAppendingString:identifier]];
    if (executableName.length && [tweak.filterExecutables containsObject:executableName])
        [reasons addObject:[@"指定可执行文件：" stringByAppendingString:executableName]];
    for (NSString *bundle in [frameworks.allObjects sortedArrayUsingSelector:@selector(compare:)]) {
        if ([tweak.explicitFilterBundles containsObject:bundle] && ![bundle isEqual:identifier])
            [reasons addObject:[@"框架依赖：" stringByAppendingString:bundle]];
    }
    return reasons.copy;
}

NSArray *CHWLMatchingConfigurationTweaks(NSArray *tweaks, NSString *identifier,
    NSString *executableName, NSSet *frameworks)
{
    NSMutableArray *result = [NSMutableArray new];
    for (CHPTweakInfo *tweak in tweaks) {
        if (CHWLMatchReasons(tweak, identifier, executableName, frameworks).count) [result addObject:tweak];
    }
    return result.copy;
}

NSDictionary *CHWLCustomCandidateGroups(NSArray *tweaks, NSArray *matches, NSDictionary *preferences,
    BOOL privilegeEligible, NSDictionary *settings)
{
    NSSet *matchedNames = [NSSet setWithArray:[matches valueForKey:@"dylibName"] ?: @[]];
    NSMutableSet *savedNames = [NSMutableSet new];
    for (NSString *key in @[@"allowedTweaks", @"deniedTweaks"]) {
        id names = settings[key];
        if ([names isKindOfClass:NSArray.class]) [savedNames addObjectsFromArray:names];
    }
    NSMutableArray *confirmed = [NSMutableArray new], *saved = [NSMutableArray new], *other = [NSMutableArray new];
    for (CHPTweakInfo *tweak in CHWLConfigurationCandidates(tweaks, preferences, privilegeEligible, NO)) {
        if ([matchedNames containsObject:tweak.dylibName]) [confirmed addObject:tweak];
        else if ([savedNames containsObject:tweak.dylibName]) [saved addObject:tweak];
        else [other addObject:tweak];
    }
    return @{@"matched": confirmed.copy, @"saved": saved.copy, @"other": other.copy};
}

BOOL CHWLCustomConfigurationAvailable(BOOL privilegedPage, BOOL injectionEnabled,
    BOOL privilegeEligible, NSDictionary *settings)
{
    return privilegedPage ? privilegeEligible && !CHWLPrivilegesDisabled(injectionEnabled, privilegeEligible, settings) : injectionEnabled;
}

BOOL CHWLCustomConfigurationActive(BOOL privilegedPage, BOOL injectionEnabled,
    BOOL privilegeEligible, NSDictionary *settings)
{
    id enabled = settings[privilegedPage ? @CH_CUSTOM_PRIVILEGE_ENABLED_KEY : @"customTweakConfigurationEnabled"];
    return CHWLCustomConfigurationAvailable(privilegedPage, injectionEnabled, privilegeEligible, settings) &&
        [enabled isKindOfClass:NSNumber.class] && [enabled boolValue];
}

NSDictionary *CHWLInitializePrivilegedConfiguration(NSDictionary *settings, NSArray<NSString *> *names)
{
    if ([settings[@CH_CUSTOM_PRIVILEGE_INITIALIZED_KEY] boolValue]) return settings;
    NSMutableDictionary *updated = settings.mutableCopy ?: [NSMutableDictionary new];
    updated[@CH_CUSTOM_PRIVILEGE_INITIALIZED_KEY] = @YES;
    updated[@CH_CUSTOM_PRIVILEGE_MODE_KEY] = @1;
    updated[@CH_CUSTOM_PRIVILEGE_ALLOWED_KEY] = names ?: @[];
    updated[@CH_CUSTOM_PRIVILEGE_DENIED_KEY] = @[];
    return updated.copy;
}

BOOL CHWLPrivilegesDisabled(BOOL injectionEnabled, BOOL privilegeEligible, NSDictionary *processPreferences)
{
    id value = processPreferences[@CH_DISABLE_PRIVILEGED_TWEAKS_KEY];
    return privilegeEligible && CHProcessDisablesPrivilege(injectionEnabled, [value isKindOfClass:NSNumber.class] && [value boolValue]);
}

NSDictionary *CHWLProcessPreferencesBySetting(NSDictionary *settings, NSString *key, id value)
{
    NSMutableDictionary *updated = [settings mutableCopy] ?: [NSMutableDictionary new];
    updated[key] = value;
    if ([key isEqual:@CH_DISABLE_PRIVILEGED_TWEAKS_KEY] && [value boolValue]) {
        updated[@"tweakInjectionEnabled"] = @NO;
        updated[@"customTweakConfigurationEnabled"] = @NO;
    } else if ([key isEqual:@"tweakInjectionEnabled"] && [value boolValue]) {
        updated[@CH_DISABLE_PRIVILEGED_TWEAKS_KEY] = @NO;
    }
    return updated.copy;
}

static NSInteger CHWLRowPriority(NSDictionary *row)
{
    if ([row[@"enabled"] boolValue]) return 0;
    BOOL matched = [row[@"matched"] boolValue];
    if ([row[@"privilegesDisabled"] boolValue]) return matched ? 2 : 3;
    if (matched) return 1;
    return [row[@"thirdPartyProcess"] boolValue] ? 4 : 5;
}

CGFloat CHWLProcessRowHeight(BOOL enabled, BOOL matched, BOOL thirdParty)
{
    if (enabled) return 56;
    if (matched && thirdParty) return 91;
    return matched || thirdParty ? 72 : 56;
}

NSArray<NSDictionary *> *CHWLSortedRows(NSArray<NSDictionary *> *rows)
{
    return [rows sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSInteger ar = CHWLRowPriority(a);
        NSInteger br = CHWLRowPriority(b);
        if (ar != br) return ar < br ? NSOrderedAscending : NSOrderedDescending;
        NSComparisonResult r = [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
        return r == NSOrderedSame ? [a[@"identifier"] compare:b[@"identifier"]] : r;
    }];
}

NSArray<NSDictionary *> *CHWLValidatedRecords(id cache, NSDictionary *context)
{
    if (![cache isKindOfClass:NSDictionary.class] || ![cache[@"schemaVersion"] isEqual:@(CHWLProcessCacheSchemaVersion)] ||
        ![cache[@"scanComplete"] isEqual:@YES] || ![cache[@"context"] isEqual:context]) return nil;
    id records = cache[@"processes"];
    if (![records isKindOfClass:NSArray.class] || ![records count] || [records count] > 20000) return nil;
    NSMutableSet *names = [NSMutableSet new];
    for (id record in records) {
        if (![record isKindOfClass:NSDictionary.class]) return nil;
        id path = record[@"executablePath"];
        if (![path isKindOfClass:NSString.class] || ![path isAbsolutePath] ||
            [path length] > 4096 || ![path lastPathComponent].length) return nil;
        NSString *name = [path lastPathComponent];
        if ([names containsObject:name]) return nil;
        [names addObject:name];
        id identifier = record[@"plistIdentifier"];
        if (identifier && (![identifier isKindOfClass:NSString.class] || ![identifier length])) return nil;
        id bundleID = record[@"bundleIdentifier"];
        if (bundleID && (![bundleID isKindOfClass:NSString.class] || ![bundleID length])) return nil;
        id source = record[@"launchDaemonPath"];
        if (source && (![source isKindOfClass:NSString.class] || ![source isAbsolutePath] || [source length] > 4096)) return nil;
        id thirdParty = record[@"thirdPartyProcess"];
        if (thirdParty && (![thirdParty isKindOfClass:NSNumber.class] ||
            (![thirdParty isEqual:@YES] && ![thirdParty isEqual:@NO]))) return nil;
    }
    return records;
}

NSArray<NSDictionary *> *CHWLRecordsByResolvingBundleIdentifiers(NSArray<NSDictionary *> *records,
    NSString *(^resolve)(NSString *path))
{
    NSMutableArray *result = [NSMutableArray new];
    for (NSDictionary *record in records) {
        if ([record[@"bundleIdentifier"] length]) {
            [result addObject:record];
            continue;
        }
        NSString *identifier = resolve ? resolve(record[@"executablePath"]) : nil;
        if ([identifier isKindOfClass:NSString.class] && identifier.length) {
            NSMutableDictionary *updated = record.mutableCopy;
            updated[@"bundleIdentifier"] = identifier;
            [result addObject:updated.copy];
        } else [result addObject:record];
    }
    return result.copy;
}

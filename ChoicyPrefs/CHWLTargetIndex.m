#import "CHWLTargetIndex.h"

NSDictionary *CHWLBuildTargetIndex(NSArray<NSDictionary *> *rules)
{
    NSMutableDictionary *bundles = [NSMutableDictionary new];
    NSMutableDictionary *executables = [NSMutableDictionary new];
    for (NSDictionary *rule in rules) {
        NSString *name = rule[@"name"];
        if (![name isKindOfClass:NSString.class] || !name.length) continue;
        for (NSString *kind in @[@"bundles", @"executables"]) {
            id targets = rule[kind];
            if (![targets isKindOfClass:NSArray.class]) continue;
            NSMutableDictionary *destination = [kind isEqualToString:@"bundles"] ? bundles : executables;
            for (id target in targets) {
                if (![target isKindOfClass:NSString.class] || ![target length]) continue;
                NSMutableOrderedSet *names = destination[target];
                if (!names) destination[target] = names = [NSMutableOrderedSet new];
                [names addObject:name];
            }
        }
    }
    NSMutableDictionary *result = [NSMutableDictionary new];
    for (NSString *kind in @[@"bundles", @"executables"]) {
        NSDictionary *source = [kind isEqualToString:@"bundles"] ? bundles : executables;
        NSMutableDictionary *entries = [NSMutableDictionary new];
        for (NSString *target in source) entries[target] = [source[target] array];
        result[kind] = entries.copy;
    }
    return result.copy;
}

NSArray<NSString *> *CHWLTargetNames(NSDictionary *index, NSString *bundleIdentifier, NSString *executableName)
{
    return CHWLTargetNamesIncludingFrameworks(index, bundleIdentifier, executableName, nil);
}

NSArray<NSString *> *CHWLTargetNamesIncludingFrameworks(NSDictionary *index, NSString *bundleIdentifier,
    NSString *executableName, NSSet<NSString *> *frameworkIdentifiers)
{
    NSMutableOrderedSet *result = [NSMutableOrderedSet new];
    if (bundleIdentifier.length) [result addObjectsFromArray:index[@"bundles"][bundleIdentifier] ?: @[]];
    if (executableName.length) [result addObjectsFromArray:index[@"executables"][executableName] ?: @[]];
    for (NSString *identifier in frameworkIdentifiers) {
        [result addObjectsFromArray:index[@"bundles"][identifier] ?: @[]];
    }
    return [result.array sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

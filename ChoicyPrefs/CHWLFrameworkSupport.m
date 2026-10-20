#import "CHWLFrameworkSupport.h"

const NSUInteger CHWLFrameworkCacheEntryVersion = 3;

NSSet<NSString *> *CHWLDependencyClosure(NSString *root, NSArray<NSString *> *(^dependencies)(NSString *image))
{
    NSSet *unreadable = nil;
    NSSet *paths = CHWLCollectDependencies(root, dependencies, &unreadable);
    return unreadable.count ? nil : paths;
}

NSSet<NSString *> *CHWLCollectDependencies(NSString *root, NSArray<NSString *> *(^dependencies)(NSString *image),
    NSSet<NSString *> **unreadable)
{
    if (unreadable) *unreadable = nil;
    if (!root.length || !dependencies) return nil;
    NSMutableSet *failures = [NSMutableSet new];
    NSMutableSet *visited = [NSMutableSet setWithObject:root];
    NSMutableArray *queue = [NSMutableArray arrayWithObject:root];
    for (NSUInteger i = 0; i < queue.count; i++) {
        NSString *image = queue[i];
        NSArray *children = dependencies(image);
        if (!children) { [failures addObject:image]; continue; }
        for (NSString *child in children) {
            if (!child.length || [visited containsObject:child]) continue;
            [visited addObject:child];
            [queue addObject:child];
        }
    }
    [visited removeObject:root];
    if (unreadable) *unreadable = failures.copy;
    return visited.copy;
}

NSString *CHWLResolveDependencyPath(NSString *path, NSString *loader, NSString *executable,
    NSArray<NSString *> *runpaths, BOOL (^exists)(NSString *candidate))
{
    if (!path.length) return nil;
    if ([path hasPrefix:@"@rpath/"]) {
        for (NSString *runpath in runpaths) {
            NSString *candidate = CHWLResolveDependencyPath([runpath stringByAppendingPathComponent:[path substringFromIndex:7]],
                loader, executable, @[], exists);
            if (candidate) return candidate;
        }
        return nil;
    }
    for (NSString *token in @[@"@loader_path", @"@executable_path"]) {
        if ([path isEqual:token] || [path hasPrefix:[token stringByAppendingString:@"/"]]) {
            NSString *base = ([token isEqual:@"@loader_path"] ? loader : executable).stringByDeletingLastPathComponent;
            if (!base.length) return nil;
            path = [base stringByAppendingString:[path substringFromIndex:token.length]];
            break;
        }
    }
    if (!path.isAbsolutePath) return nil;
    path = path.stringByStandardizingPath;
    return !exists || exists(path) ? path : nil;
}

NSString *CHWLFrameworkBundlePath(NSString *image)
{
    NSString *path = image.stringByDeletingLastPathComponent;
    while (path.length > 1) {
        if ([path.pathExtension isEqualToString:@"framework"]) return path;
        NSString *parent = path.stringByDeletingLastPathComponent;
        if ([parent isEqual:path]) break;
        path = parent;
    }
    return nil;
}

NSArray<NSString *> *CHWLValidatedFrameworkEntry(id entry, NSDictionary *signature)
{
    if (!signature || ![entry isKindOfClass:NSDictionary.class] ||
        ![entry[@"version"] isEqual:@(CHWLFrameworkCacheEntryVersion)] || ![entry[@"signature"] isEqual:signature]) return nil;
    id values = entry[@"identifiers"];
    if (![values isKindOfClass:NSArray.class] || [values count] > 4096) return nil;
    for (id identifier in values) {
        if (![identifier isKindOfClass:NSString.class] || ![identifier length] || [identifier length] > 1024) return nil;
    }
    return values;
}

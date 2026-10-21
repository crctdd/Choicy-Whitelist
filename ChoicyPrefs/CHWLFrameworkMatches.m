#import "CHWLFrameworkMatches.h"
#import "CHPDaemonList.h"
#import "CHPMachoParser.h"

NSString *const CHWLFrameworkMatchesChanged = @"CHWLFrameworkMatchesChanged";
static NSMutableDictionary *ready;
static NSMutableSet *pending;
static NSMutableSet *changedPaths;
static NSMutableDictionary *epochs;
static NSMutableDictionary *lastChecks;
static dispatch_queue_t analysisQueue;
static NSUInteger generation;
static BOOL notificationPending;

static void CHWLPrepareFrameworkState(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        ready = [NSMutableDictionary new];
        pending = [NSMutableSet new];
        changedPaths = [NSMutableSet new];
        epochs = [NSMutableDictionary new];
        lastChecks = [NSMutableDictionary new];
        analysisQueue = dispatch_queue_create("com.crctdd.choicy-whitelist.frameworks",
            dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0));
    });
}

static void CHWLNotifyFrameworkChange(NSString *path)
{
    [changedPaths addObject:path];
    generation++;
    if (notificationPending) return;
    notificationPending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        NSSet *paths = changedPaths.copy;
        [changedPaths removeAllObjects];
        notificationPending = NO;
        [NSNotificationCenter.defaultCenter postNotificationName:CHWLFrameworkMatchesChanged object:paths];
    });
}

static NSDictionary *CHWLFrameworkSignature(NSString *path)
{
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    return attributes[NSFileSize] && attributes[NSFileModificationDate] ?
        @{@"size": attributes[NSFileSize], @"modified": attributes[NSFileModificationDate]} : nil;
}

NSUInteger CHWLFrameworkGeneration(void) { return generation; }
NSSet *CHWLCachedFrameworkIdentifiers(NSString *path)
{
    CHWLPrepareFrameworkState();
    return path.length ? ready[path.stringByStandardizingPath][@"identifiers"] : nil;
}
BOOL CHWLFrameworkAnalysisFinished(NSString *path)
{
    CHWLPrepareFrameworkState();
    return path.length && ready[path.stringByStandardizingPath] != nil;
}
BOOL CHWLFrameworkAnalysisFailed(NSString *path)
{
    CHWLPrepareFrameworkState();
    NSDictionary *analysis = path.length ? ready[path.stringByStandardizingPath] : nil;
    return analysis && ![analysis[@"complete"] boolValue];
}
void CHWLRequestFrameworkIdentifiers(NSString *path)
{
    if (!path.length) return;
    CHWLPrepareFrameworkState();
    path = path.stringByStandardizingPath;
    if ([pending containsObject:path] || (ready[path] &&
        CFAbsoluteTimeGetCurrent() - [lastChecks[path] doubleValue] < 2)) return;
    lastChecks[path] = @(CFAbsoluteTimeGetCurrent());
    NSUInteger epoch = [epochs[path] unsignedIntegerValue];
    [pending addObject:path];
    dispatch_async(analysisQueue, ^{
        @autoreleasepool {
            NSDictionary *signature = CHWLFrameworkSignature(path);
            CHPDaemonList *list = CHPDaemonList.sharedInstance;
            NSSet *identifiers = [list cachedFrameworkIdentifiersForPath:path signature:signature];
            NSDictionary *analysis = identifiers ? @{@"identifiers": identifiers, @"complete": @YES} :
                [[CHPMachoParser sharedInstance] frameworkAnalysisForMachoAtPath:path];
            if (!identifiers && [analysis[@"complete"] boolValue])
                [list cacheFrameworkAnalysis:analysis forPath:path signature:signature];
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([epochs[path] unsignedIntegerValue] != epoch) return;
                NSDictionary *snapshot = @{@"identifiers": analysis[@"identifiers"] ?: [NSSet set],
                    @"complete": analysis[@"complete"] ?: @NO};
                [pending removeObject:path];
                if (![ready[path] isEqual:snapshot]) {
                    ready[path] = snapshot;
                    CHWLNotifyFrameworkChange(path);
                }
            });
        }
    });
}

void CHWLInvalidateFrameworkAnalysis(NSString *path)
{
    if (!path.length) return;
    CHWLPrepareFrameworkState();
    path = path.stringByStandardizingPath;
    epochs[path] = @([epochs[path] unsignedIntegerValue] + 1);
    [ready removeObjectForKey:path];
    [lastChecks removeObjectForKey:path];
    [pending removeObject:path];
    dispatch_async(analysisQueue, ^{
        [CHPDaemonList.sharedInstance invalidateFrameworkIdentifiersForPath:path];
    });
    CHWLNotifyFrameworkChange(path);
}

void CHWLPublishFrameworkAnalysis(NSString *path, NSDictionary *analysis)
{
    if (!path.length || ![analysis[@"identifiers"] isKindOfClass:NSSet.class]) return;
    CHWLPrepareFrameworkState();
    path = path.stringByStandardizingPath;
    epochs[path] = @([epochs[path] unsignedIntegerValue] + 1);
    [pending removeObject:path];
    lastChecks[path] = @(CFAbsoluteTimeGetCurrent());
    NSDictionary *published = @{@"identifiers": analysis[@"identifiers"], @"complete": analysis[@"complete"] ?: @NO};
    BOOL changed = ![ready[path] isEqual:published];
    ready[path] = published;
    NSDictionary *snapshot = analysis;
    dispatch_async(analysisQueue, ^{
        CHPDaemonList *list = CHPDaemonList.sharedInstance;
        if ([snapshot[@"complete"] boolValue])
            [list cacheFrameworkAnalysis:snapshot forPath:path signature:CHWLFrameworkSignature(path)];
        else [list invalidateFrameworkIdentifiersForPath:path];
    });
    if (changed) CHWLNotifyFrameworkChange(path);
}

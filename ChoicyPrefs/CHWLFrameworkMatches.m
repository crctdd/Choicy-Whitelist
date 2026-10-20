#import "CHWLFrameworkMatches.h"
#import "CHPDaemonList.h"
#import "CHPMachoParser.h"

NSString *const CHWLFrameworkMatchesChanged = @"CHWLFrameworkMatchesChanged";
static NSMutableDictionary *ready;
static NSMutableSet *pending;
static NSMutableSet *changedPaths;
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
        analysisQueue = dispatch_queue_create("com.crctdd.choicy-whitelist.frameworks",
            dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0));
    });
}

NSUInteger CHWLFrameworkGeneration(void) { return generation; }
NSSet *CHWLCachedFrameworkIdentifiers(NSString *path)
{
    CHWLPrepareFrameworkState();
    id value = path.length ? ready[path.stringByStandardizingPath] : nil;
    return [value isKindOfClass:NSSet.class] ? value : nil;
}
BOOL CHWLFrameworkAnalysisFinished(NSString *path)
{
    CHWLPrepareFrameworkState();
    return path.length && ready[path.stringByStandardizingPath] != nil;
}
BOOL CHWLFrameworkAnalysisFailed(NSString *path)
{
    CHWLPrepareFrameworkState();
    return path.length && ready[path.stringByStandardizingPath] == NSNull.null;
}
void CHWLRequestFrameworkIdentifiers(NSString *path)
{
    if (!path.length) return;
    CHWLPrepareFrameworkState();
    path = path.stringByStandardizingPath;
    if (ready[path] || [pending containsObject:path]) return;
    [pending addObject:path];
    dispatch_async(analysisQueue, ^{
        @autoreleasepool {
            NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
            NSDictionary *signature = attributes[NSFileSize] && attributes[NSFileModificationDate] ?
                @{@"size": attributes[NSFileSize], @"modified": attributes[NSFileModificationDate]} : nil;
            CHPDaemonList *list = CHPDaemonList.sharedInstance;
            NSSet *identifiers = [list cachedFrameworkIdentifiersForPath:path signature:signature];
            if (!identifiers) {
                identifiers = [[CHPMachoParser sharedInstance] frameworkBundleIdentifiersForMachoAtPath:path];
                if (identifiers) [list cacheFrameworkIdentifiers:identifiers forPath:path signature:signature];
            }
            NSSet *snapshot = identifiers.copy;
            dispatch_async(dispatch_get_main_queue(), ^{
                ready[path] = snapshot ?: NSNull.null;
                [pending removeObject:path];
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
            });
        }
    });
}

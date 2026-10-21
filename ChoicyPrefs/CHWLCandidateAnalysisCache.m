#import "CHWLCandidateAnalysisCache.h"

@implementation CHWLCandidateAnalysisCache {
    NSMutableDictionary *_analyses;
    NSUInteger _revision;
}
- (instancetype)init
{
    self = [super init];
    if (self) _analyses = [NSMutableDictionary new];
    return self;
}
- (NSUInteger)revision { @synchronized (self) { return _revision; } }
- (NSDictionary *)cachedAnalysisForPath:(NSString *)path
{
    if (!path.length) return nil;
    @synchronized (self) { return _analyses[path.stringByStandardizingPath]; }
}
- (void)storeAnalysis:(NSDictionary *)analysis forPath:(NSString *)path revision:(NSUInteger)revision
{
    if (!path.length || !analysis) return;
    @synchronized (self) {
        if (revision == _revision) _analyses[path.stringByStandardizingPath] = analysis.copy;
    }
}
- (void)invalidatePath:(NSString *)path
{
    if (!path.length) return;
    @synchronized (self) {
        _revision++;
        [_analyses removeObjectForKey:path.stringByStandardizingPath];
    }
}
- (void)invalidateAll
{
    @synchronized (self) { _revision++; [_analyses removeAllObjects]; }
}
@end

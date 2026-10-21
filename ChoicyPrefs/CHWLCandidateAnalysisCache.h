#import <Foundation/Foundation.h>

@interface CHWLCandidateAnalysisCache : NSObject
- (NSUInteger)revision;
- (NSDictionary *)cachedAnalysisForPath:(NSString *)path;
- (void)storeAnalysis:(NSDictionary *)analysis forPath:(NSString *)path revision:(NSUInteger)revision;
- (void)invalidatePath:(NSString *)path;
- (void)invalidateAll;
@end

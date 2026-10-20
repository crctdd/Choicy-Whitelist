#import <Foundation/Foundation.h>

extern NSString *const CHWLFrameworkMatchesChanged;
NSUInteger CHWLFrameworkGeneration(void);
NSSet *CHWLCachedFrameworkIdentifiers(NSString *path);
BOOL CHWLFrameworkAnalysisFinished(NSString *path);
BOOL CHWLFrameworkAnalysisFailed(NSString *path);
void CHWLRequestFrameworkIdentifiers(NSString *path);

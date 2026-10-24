#import <Foundation/Foundation.h>

FOUNDATION_EXPORT const NSUInteger CHWLFrameworkCacheEntryVersion;

                                                                                 
NSSet<NSString *> *CHWLDependencyClosure(NSString *root, NSArray<NSString *> *(^dependencies)(NSString *image));
                                                                              
NSSet<NSString *> *CHWLCollectDependencies(NSString *root, NSArray<NSString *> *(^dependencies)(NSString *image),
    NSSet<NSString *> **unreadable);
NSString *CHWLResolveDependencyPath(NSString *path, NSString *loader, NSString *executable,
    NSArray<NSString *> *runpaths, BOOL (^exists)(NSString *candidate));
NSString *CHWLFrameworkBundlePath(NSString *image);
NSArray<NSString *> *CHWLValidatedFrameworkEntry(id entry, NSDictionary *signature);
NSDictionary *CHWLInputSignatures(NSArray<NSString *> *paths);
BOOL CHWLInputSignaturesAreCurrent(id signatures);

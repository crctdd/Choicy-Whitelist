#import <Foundation/Foundation.h>

NSDictionary *CHWLBuildTargetIndex(NSArray<NSDictionary *> *rules);
NSArray<NSString *> *CHWLTargetNames(NSDictionary *index, NSString *bundleIdentifier, NSString *executableName);
NSArray<NSString *> *CHWLTargetNamesIncludingFrameworks(NSDictionary *index, NSString *bundleIdentifier,
    NSString *executableName, NSSet<NSString *> *frameworkIdentifiers);

#import <Foundation/Foundation.h>
#import "CHWhitelistPolicy.h"

NSDictionary *CHEnvironmentForLaunchMode(NSDictionary *environment, NSString *bundleIdentifier, CHLaunchMode mode);
NSDictionary *CHEnvironmentForPrivilegeScope(NSDictionary *environment, NSString *bundleIdentifier, BOOL visibleApplication);
CHLaunchMode CHConsumePendingLaunchMode(NSMutableDictionary *pending, NSString *bundleIdentifier);

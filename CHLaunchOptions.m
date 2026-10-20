#import "CHLaunchOptions.h"

NSDictionary *CHEnvironmentForPrivilegeScope(NSDictionary *environment, NSString *bundleIdentifier, BOOL visibleApplication)
{
    NSMutableDictionary *result = environment.mutableCopy ?: [NSMutableDictionary new];
    [result removeObjectForKey:@CH_PRIVILEGED_APP_ENV];
    if (visibleApplication && bundleIdentifier.length) result[@CH_PRIVILEGED_APP_ENV] = bundleIdentifier;
    return result.copy;
}

CHLaunchMode CHConsumePendingLaunchMode(NSMutableDictionary *pending, NSString *bundleIdentifier)
{
    if (!bundleIdentifier.length) return CHLaunchNormal;
    @synchronized (pending) {
        NSNumber *saved = pending[bundleIdentifier];
        if (!saved) return CHLaunchNormal;
        [pending removeObjectForKey:bundleIdentifier];
        return (CHLaunchMode)saved.unsignedIntegerValue;
    }
}

NSDictionary *CHEnvironmentForLaunchMode(NSDictionary *environment, NSString *bundleIdentifier, CHLaunchMode mode)
{
    if (mode == CHLaunchNormal || !bundleIdentifier.length) return environment;
    NSMutableDictionary *result = environment.mutableCopy ?: [NSMutableDictionary new];
    result[@CH_LAUNCH_MODE_ENV] = mode == CHLaunchWithAllTweaks ? @"with-all" : @"without-all";
    result[@CH_LAUNCH_TARGET_ENV] = bundleIdentifier;
    if (mode == CHLaunchWithAllTweaks) {
        [result removeObjectForKey:@"_MSSafeMode"];
        [result removeObjectForKey:@"_SafeMode"];
        [result removeObjectForKey:@"_ChoicyInjectionEnabledFromSpringBoard"];
    } else {
        result[@"_MSSafeMode"] = @"1";
        result[@"_SafeMode"] = @"1";
        [result removeObjectForKey:@"_ChoicyInjectionEnabledFromSpringBoard"];
    }
    return result.copy;
}

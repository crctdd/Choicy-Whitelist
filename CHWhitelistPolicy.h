#ifndef CH_WHITELIST_POLICY_H
#define CH_WHITELIST_POLICY_H
#include <stdbool.h>
#include <string.h>

#define CH_LAUNCH_MODE_ENV "_ChoicyWhitelistLaunchMode"
#define CH_LAUNCH_TARGET_ENV "_ChoicyWhitelistLaunchTarget"
#define CH_PRIVILEGED_TWEAKS_KEY "privilegedTweaks"
#define CH_DISABLE_PRIVILEGED_TWEAKS_KEY "disablePrivilegedTweaks"
#define CH_CUSTOM_PRIVILEGE_ENABLED_KEY "customPrivilegedConfigurationEnabled"
#define CH_CUSTOM_PRIVILEGE_MODE_KEY "privilegedAllowDenyMode"
#define CH_CUSTOM_PRIVILEGE_ALLOWED_KEY "allowedPrivilegedTweaks"
#define CH_CUSTOM_PRIVILEGE_DENIED_KEY "deniedPrivilegedTweaks"
#define CH_CUSTOM_PRIVILEGE_INITIALIZED_KEY "privilegedConfigurationInitialized"
#define CH_PRIVILEGED_APP_ENV "_ChoicyWhitelistPrivilegedApp"
typedef enum {
    CHLaunchNormal,
    CHLaunchWithoutAllTweaks,
    CHLaunchWithAllTweaks
} CHLaunchMode;

static inline CHLaunchMode CHShortcutMode(bool injectionEnabled, bool showWithout, bool showWith)
{
    return injectionEnabled ? (showWithout ? CHLaunchWithoutAllTweaks : CHLaunchNormal) :
        (showWith ? CHLaunchWithAllTweaks : CHLaunchNormal);
}

static inline CHLaunchMode CHLaunchModeForProcess(const char *mode, const char *target,
                                                 const char *bundle, bool isApplication)
{
    if (!isApplication || !mode || !target || !bundle || strcmp(target, bundle)) return CHLaunchNormal;
    if (!strcmp(mode, "without-all")) return CHLaunchWithoutAllTweaks;
    if (!strcmp(mode, "with-all")) return CHLaunchWithAllTweaks;
    return CHLaunchNormal;
}

static inline bool CHForcedInjection(const char *bundle, const char *executable)
{
    if (bundle && *bundle) {
        return !strcmp(bundle, "com.apple.Preferences") ||
               !strcmp(bundle, "com.apple.springboard") ||
               !strcmp(bundle, "com.apple.SafariViewService");
    }
    if (!executable) return false;
    const char *names[] = {"Preferences", "SpringBoard", "SafariViewService", "lsd",
                           "watchdogd", "cfprefsd", "useractivityd"};
    for (unsigned i = 0; i < sizeof(names) / sizeof(*names); i++) {
        if (!strcmp(executable, names[i])) return true;
    }
    return false;
}

static inline bool CHResolveInjection(bool forced, bool jailbreakApp,
                                     bool hasExplicitValue, bool explicitValue)
{
    return forced || (hasExplicitValue ? explicitValue : jailbreakApp);
}

static inline bool CHIsUIKitBundle(const char *identifier)
{
    return identifier && (!strcmp(identifier, "com.apple.UIKit") || !strcmp(identifier, "com.apple.UIKitCore"));
}

static inline bool CHPrivilegeApplies(bool isUIKit, bool listed)
{
    return isUIKit && listed;
}

static inline bool CHPrivilegeScopeAllows(bool isApplication, const char *bundle, const char *visibleApplication)
{

    return isApplication && bundle && *bundle && visibleApplication && !strcmp(bundle, visibleApplication);
}

static inline bool CHProcessDisablesPrivilege(bool injectionEnabled, bool savedValue)
{
    return !injectionEnabled && savedValue;
}

static inline bool CHDisablePrivilegeSwitchEditable(bool injectionEnabled, bool hasActivePrivileges)
{
    return !injectionEnabled && hasActivePrivileges;
}

static inline bool CHShouldLoadManagedTweak(bool injectionEnabled, bool privileged,
                                          bool globallyDenied, bool hasAllowList, bool allowed, bool denied)
{
    return !globallyDenied && (privileged || (injectionEnabled && (!hasAllowList || allowed) && !denied));
}

static inline bool CHShouldLoadManagedTweakForLaunch(CHLaunchMode mode, bool injectionEnabled,
    bool privileged, bool globallyDenied, bool hasAllowList, bool allowed, bool denied)
{
    if (mode == CHLaunchWithoutAllTweaks) return false;
    if (mode == CHLaunchWithAllTweaks) return true;
    return CHShouldLoadManagedTweak(injectionEnabled, privileged, globallyDenied, hasAllowList, allowed, denied);
}

static inline bool CHShouldLoadConfiguredTweak(CHLaunchMode mode, bool injectionEnabled,
    bool privilegedDomain, bool privilegesDisabled, bool customPrivilegeEnabled,
    bool privilegeDenyMode, bool privilegeAllowed, bool privilegeDenied,
    bool globallyDenied, bool hasAllowList, bool allowed, bool denied)
{
    if (mode == CHLaunchWithoutAllTweaks) return false;
    if (mode == CHLaunchWithAllTweaks) return true;
    if (privilegedDomain) {
        return !globallyDenied && !privilegesDisabled && (!customPrivilegeEnabled ||
            (privilegeDenyMode ? !privilegeDenied : privilegeAllowed));
    }
    return CHShouldLoadManagedTweak(injectionEnabled, false, globallyDenied, hasAllowList, allowed, denied);
}
#endif

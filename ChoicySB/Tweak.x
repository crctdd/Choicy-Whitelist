#import <Foundation/Foundation.h>
#import "../Shared.h"
#import "../ChoicyPrefsMigrator.h"
#import "ChoicyOverrideManager.h"
#import "ChoicySB.h"
#import "../CHLaunchOptions.h"

NSDictionary *preferences;
BOOL gIsSpringBoard = NO;

extern void choicy_initSpringBoard(void);
extern void choicy_initRunningBoardd(void);

extern char** *_NSGetArgv();
NSString *safe_getExecutablePath()
{
	char *executablePathC = **_NSGetArgv();
	return [NSString stringWithUTF8String:executablePathC];
}

void choicy_reloadPreferences(void)
{
	if (preferences) {
		NSDictionary *oldPreferences = [preferences copy];
		preferences = [NSDictionary dictionaryWithContentsOfFile:kChoicyPrefsPlistPath];

		if (gIsSpringBoard) {
			NSDictionary *appSettings = [preferences objectForKey:kChoicyPrefsKeyAppSettings];
			NSDictionary *oldAppSettings = [oldPreferences objectForKey:kChoicyPrefsKeyAppSettings];

			NSMutableSet *allApps = [NSMutableSet setWithArray:[appSettings allKeys]];
			[allApps unionSet:[NSMutableSet setWithArray:[oldAppSettings allKeys]]];

			NSMutableSet *changedApps = [NSMutableSet new];

			for (NSString *appKey in allApps) {
				if (![((NSDictionary *)[appSettings objectForKey:appKey]) isEqualToDictionary:((NSDictionary *)[oldAppSettings objectForKey:appKey])]) {
					[changedApps addObject:appKey];
				}
			}

			for (NSString *applicationID in changedApps) {
				if (![applicationID isEqualToString:kSpringboardBundleID] && ![applicationID isEqualToString:kPreferencesBundleID]) {
					BKSTerminateApplicationForReasonAndReportWithDescription(applicationID, 5, false, @"Choicy - prefs changed, killed");
				}
			}
		}
	}
	else {
		NSString *parentDir = [kChoicyPrefsPlistPath stringByDeletingLastPathComponent];
		if (![[NSFileManager defaultManager] fileExistsAtPath:parentDir]) {
			[[NSFileManager defaultManager] createDirectoryAtPath:parentDir withIntermediateDirectories:YES attributes:nil error:nil];
		}
		preferences = [NSDictionary dictionaryWithContentsOfFile:kChoicyPrefsPlistPath];
	}
}

BOOL choicy_shouldDisableTweakInjectionForApplication(NSString *applicationID)
{
    NSString *executablePath = CHExecutablePathForApplication(applicationID);
    if (CHInjectionIsForced(applicationID, executablePath)) return NO;
    BOOL overrideExists = NO;
    BOOL value = [[ChoicyOverrideManager sharedManager] disableTweakInjectionOverrideForApplication:applicationID overrideExists:&overrideExists];
    if (overrideExists) return value;
    return !CHInjectionEnabled(preferences, applicationID, executablePath);
}

NSDictionary *choicy_applyEnvironmentChanges(NSDictionary *originalEnvironment, NSString *bundleIdentifier)
{
    originalEnvironment = CHEnvironmentForPrivilegeScope(originalEnvironment, bundleIdentifier,
        CHApplicationSupportsPrivilege(bundleIdentifier));
     
    if (!bundleIdentifier.length) return originalEnvironment;
    CHLaunchMode launchMode = CHLaunchModeForProcess([originalEnvironment[@CH_LAUNCH_MODE_ENV] UTF8String],
        [originalEnvironment[@CH_LAUNCH_TARGET_ENV] UTF8String], bundleIdentifier.UTF8String, true);
    if (launchMode != CHLaunchNormal) return CHEnvironmentForLaunchMode(originalEnvironment, bundleIdentifier, launchMode);
	if (originalEnvironment[@"_MSSafeMode"] || originalEnvironment[@"_SafeMode"]) {
		 
		return originalEnvironment;
	}
	else if (originalEnvironment[@"_ChoicyInjectionEnabledFromSpringBoard"]) {
		 
		return originalEnvironment;
	}

	NSMutableDictionary *newEnvironment = originalEnvironment.mutableCopy ?: [NSMutableDictionary new];
    ChoicyOverrideManager *overrideManager = [ChoicyOverrideManager sharedManager];
    BOOL disableOverrideExists = NO;
    BOOL disableOverride = [overrideManager disableTweakInjectionOverrideForApplication:bundleIdentifier overrideExists:&disableOverrideExists];
     

	if (disableOverrideExists && disableOverride && !CHInjectionIsForced(bundleIdentifier, CHExecutablePathForApplication(bundleIdentifier))) {
		[newEnvironment setObject:@(1) forKey:@"_MSSafeMode"];
		[newEnvironment setObject:@(1) forKey:@"_SafeMode"];
	}
	else {
        if (disableOverrideExists && !disableOverride) newEnvironment[@"_ChoicyInjectionEnabledFromSpringBoard"] = @YES;
		BOOL overrideExists = NO;

		BOOL customTweakConfigurationEnabledOverride = [overrideManager customTweakConfigurationEnabledOverwriteForApplication:bundleIdentifier overrideExists:&overrideExists];
		if (overrideExists) {
			if (!customTweakConfigurationEnabledOverride) {
				 

				[newEnvironment setObject:@"" forKey:@kEnvDeniedTweaksOverride];
			}
			else {
				BOOL customTweakAllowDenyOverride = [overrideManager customTweakConfigurationAllowDenyModeOverrideForApplication:bundleIdentifier overrideExists:&overrideExists];
				NSArray *allowDenyList = [overrideManager customTweakConfigurationAllowOrDenyListOverrideForApplication:bundleIdentifier overrideExists:&overrideExists];

				if (overrideManager && allowDenyList) {
					NSString *allowDenyString = [allowDenyList componentsJoinedByString:@":"];

					NSString *envName;
					if (customTweakAllowDenyOverride) {  
						envName = @kEnvDeniedTweaksOverride;
					}
					else {  
						envName = @kEnvAllowedTweaksOverride;
					}

					 

					[newEnvironment setObject:allowDenyString forKey:envName];
				}
			}
		}

		BOOL overwriteGlobalConfigurationOverride = [overrideManager overwriteGlobalConfigurationOverrideForApplication:bundleIdentifier overrideExists:&overrideExists];
		 
		if (overrideExists) {
			NSString *envToSet;
			if (overwriteGlobalConfigurationOverride) {
				envToSet = @"1";
			}
			else {
				envToSet = @"0";
			}

			[newEnvironment setObject:envToSet forKey:@kEnvOverwriteGlobalConfigurationOverride];
		}
	}
	return newEnvironment;
}

void choicy_applyEnvironmentChangesToLaunchContext(RBSLaunchContext *launchContext)
{
	NSString *bundleIdentifier = nil;
	if ([launchContext respondsToSelector:@selector(bundleIdentifier)]) {
		bundleIdentifier = launchContext.bundleIdentifier;
	}
	if (!bundleIdentifier.length) {
		bundleIdentifier = launchContext.identity.embeddedApplicationIdentifier;
	}
	launchContext._additionalEnvironment = choicy_applyEnvironmentChanges(launchContext._additionalEnvironment, bundleIdentifier);
}

void choicy_applyEnvironmentChangesToExecutionContext(FBProcessExecutionContext *executionContext, NSString *bundleIdentifier)
{
	executionContext.environment = choicy_applyEnvironmentChanges(executionContext.environment, bundleIdentifier);
}

%ctor
{
	choicy_reloadPreferences();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)choicy_reloadPreferences, CFSTR("com.crctdd.choicy-whitelist/ReloadPrefs"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

	if (preferences && [ChoicyPrefsMigrator preferencesNeedMigration:preferences]) {
		NSMutableDictionary *preferencesM = preferences.mutableCopy;
		[ChoicyPrefsMigrator migratePreferences:preferencesM];
		[ChoicyPrefsMigrator updatePreferenceVersion:preferencesM];
		[preferencesM writeToFile:kChoicyPrefsPlistPath atomically:NO];
		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.crctdd.choicy-whitelist/ReloadPrefs"), NULL, NULL, YES);
	}

	NSString *executablePath = safe_getExecutablePath();
	if ([executablePath.lastPathComponent isEqualToString:@"SpringBoard"]) {
		gIsSpringBoard = YES;
		choicy_initSpringBoard();
	}
	else if ([executablePath.lastPathComponent isEqualToString:@"runningboardd"]) {
		choicy_initRunningBoardd();
	}
}
